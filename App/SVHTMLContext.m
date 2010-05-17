//
//  SVHTMLContext.m
//  Sandvox
//
//  Created by Mike on 19/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"

#import "KTHostProperties.h"
#import "KTPage.h"
#import "KTSite.h"
#import "BDAlias+QuickLook.h"
#import "SVMediaRecord.h"

#import "SVCalloutDOMController.h"  // don't like having to do this

#import "NSIndexPath+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"


@interface SVHTMLIterator : NSObject
{
    NSUInteger  _iteration;
    NSUInteger  _count;
}

- (id)initWithCount:(NSUInteger)count;
@property(nonatomic, readonly) NSUInteger count;

@property(nonatomic, readonly) NSUInteger iteration;
- (NSUInteger)nextIteration;

@end


@interface SVHTMLContext ()
- (SVHTMLIterator *)currentIterator;
@end


#pragma mark -


@implementation SVHTMLContext

#pragma mark Init & Dealloc

- (id)initWithStringWriter:(id <KSStringWriter>)writer; // designated initializer
{
    [super initWithStringWriter:writer];
    
    _stringWriter = [writer retain];
        
    _includeStyling = YES;
    _mainCSS = [[NSMutableString alloc] init];
    
    _liveDataFeeds = YES;
    [self setEncoding:NSUTF8StringEncoding];
    _docType = KTDocTypeAll;
    
    _headerLevel = 1;
    _headerMarkup = [[NSMutableString alloc] init];
    _endBodyMarkup = [[NSMutableString alloc] init];
    _iteratorsStack = [[NSMutableArray alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_language release];
    [_baseURL release];
    [_currentPage release];
    
    [_mainCSSURL release];
    [_mainCSS release];
    
    [_headerMarkup release];
    [_endBodyMarkup release];
    [_iteratorsStack release];
    [_stringWriter release];
    
    [super dealloc];
}

#pragma mark Properties

@synthesize baseURL = _baseURL;
@synthesize liveDataFeeds = _liveDataFeeds;
@synthesize encoding = _stringEncoding;
@synthesize language = _language;

@synthesize maxDocType = _docType;

- (void)limitToMaxDocType:(KTDocType)docType;
{
    if (docType < [self maxDocType]) [self setMaxDocType:docType];
}

- (KTHTMLGenerationPurpose)generationPurpose; { return kSVHTMLGenerationPurposeNormal; }

- (BOOL)isForEditing; { return [self generationPurpose] == kSVHTMLGenerationPurposeEditing; }

- (BOOL)isEditable { return [self isForEditing]; }
+ (NSSet *)keyPathsForValuesAffectingEditable
{
    return [NSSet setWithObject:@"generationPurpose"];
}

- (BOOL)isForQuickLookPreview;
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeQuickLookPreview;
    return result;
}

- (BOOL)isForPublishing
{
    BOOL result = [self generationPurpose] == kSVHTMLGenerationPurposeNormal;
    return result;
}

- (void)copyPropertiesFromContext:(SVHTMLContext *)context;
{
    // Copy across properties
    [self setIndentationLevel:[context indentationLevel]];
    [self setPage:[context page]];
    [self setBaseURL:[context baseURL]];
    [self setIncludeStyling:[context includeStyling]];
    [self setLiveDataFeeds:[context liveDataFeeds]];
    [self setXHTML:[context isXHTML]];
    [self setEncoding:[context encoding]];
}

#pragma mark CSS

@synthesize includeStyling = _includeStyling;

@synthesize mainCSS = _mainCSS;
@synthesize mainCSSURL = _mainCSSURL;

- (void)addCSSWithURL:(NSURL *)cssURL;
{
    [self writeLinkToStylesheet:[self relativeURLStringOfURL:cssURL]
                          title:nil
                          media:nil];
}

#pragma mark Header Tags

@synthesize currentHeaderLevel = _headerLevel;

- (NSString *)currentHeaderLevelTagName;
{
    NSString *result = [NSString stringWithFormat:@"h%u", [self currentHeaderLevel]];
    return result;
}

#pragma mark Callouts

- (void)beginCalloutWithAlignmentClassName:(NSString *)alignment;
{
    if ([alignment isEqualToString:_calloutAlignment])
    {
        // Suitable div is already open, so cancel the buffer and carry on writing
        [self discardBuffer];
    }
    else
    {
        // Write the opening tags
        [self writeStartTag:@"div"
                     idName:[(SVCalloutDOMController *)[self currentItem] HTMLElementIDName]
                  className:[@"callout-container " stringByAppendingString:alignment]];
        [self writeNewline];
        
        [self writeStartTag:@"div" idName:nil className:@"callout"];
        [self writeNewline];
        
        [self writeStartTag:@"div" idName:nil className:@"callout-content"];
        [self writeNewline];
        
        
        OBASSERT(!_calloutAlignment);
        _calloutAlignment = [alignment copy];
    }
}

- (void)endCallout;
{
    // Buffer this call so consecutive matching callouts can be blended into one
    [self beginBuffering];
    
    [self writeEndTag]; // callout-content
    [self writeNewline];
    
    [self writeEndTag]; // callout
    [self writeNewline];
    
    [self writeEndTag]; // callout-container
    [self writeNewline];
    
    [self flushOnNextWrite];
}

- (void)flush;
{
    [_calloutAlignment release]; _calloutAlignment = nil;
    
    [super flush];
}

#pragma mark URLs/Paths

- (NSString *)relativeURLStringOfURL:(NSURL *)URL;
{
    OBPRECONDITION(URL);
    
    NSString *result;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [URL absoluteString];
            break;
        default:
            result = [URL stringRelativeToURL:[self baseURL]];
            break;
    }
    
    return result;
}

- (NSString *)relativeURLStringOfSiteItem:(SVSiteItem *)page;
{
    OBPRECONDITION(page);
    
    NSString *result = nil;
    
    switch ([self generationPurpose])
    {
        case kSVHTMLGenerationPurposeEditing:
            result = [page previewPath];
            break;
        case kSVHTMLGenerationPurposeQuickLookPreview:
            result= @"javascript:void(0)";
            break;
        default:
        {
            NSURL *URL = [page URL];
            if (URL) result = [self relativeURLStringOfURL:URL];
            break;
        }
    }
    
    return result;
}

- (NSString *)relativeURLStringOfResourceFile:(NSURL *)resourceURL;
{
    NSString *result;
	switch ([self generationPurpose])
	{
		case kSVHTMLGenerationPurposeEditing:
			result = [resourceURL absoluteString];
			break;
            
		case kSVHTMLGenerationPurposeQuickLookPreview:
			result = [[BDAlias aliasWithPath:[resourceURL path]] quickLookPseudoTag];
			break;
			
		default:
		{
			KTHostProperties *hostProperties = [[[self page] site] hostProperties];
			NSURL *resourceFileURL = [hostProperties URLForResourceFile:[resourceURL lastPathComponent]];
			result = [resourceFileURL stringRelativeToURL:[self baseURL]];
			break;
		}
	}
    
	// TODO: Tell the delegate
	//[self didEncounterResourceFile:resourceURL];
    
	return result;
}

#pragma mark Media

// Up to subclasses to implement
- (NSURL *)addMedia:(id <SVMedia>)media;
{
    NSURL *result = [media fileURL];
    if (!result) result = [[(SVMediaRecord *)media URLResponse] URL];
    
    return result;
}

- (void)writeImageWithIdName:(NSString *)idName
                   className:(NSString *)className
                 sourceMedia:(SVMediaRecord *)media
                         alt:(NSString *)altText
                       width:(NSNumber *)width
                      height:(NSNumber *)height;
{
    NSURL *URL = [self addMedia:media];
    NSString *src = (URL ? [self relativeURLStringOfURL:URL] : @"");
    
    [self writeImageWithIdName:idName
                     className:className
                           src:src
                           alt:altText
                         width:[width description]
                        height:[height description]];
}

#pragma mark Resource Files

- (NSURL *)addResourceWithURL:(NSURL *)resourceURL;
{
    return resourceURL; // subclasses will correct for publishing
}

#pragma mark Iterations

- (NSUInteger)currentIteration; { return [[self currentIterator] iteration]; }

- (NSUInteger)currentIterationsCount; { return [[self currentIterator] count]; }

- (void)nextIteration;  // increments -currentIteration. Pops the iterators stack if this was the last one.
{
    if ([[self currentIterator] nextIteration] == NSNotFound)
    {
        [self popIterator];
    }
}

- (SVHTMLIterator *)currentIterator { return [_iteratorsStack lastObject]; }

- (void)beginIteratingWithCount:(NSUInteger)count;  // Pushes a new iterator on the stack
{
    OBPRECONDITION(count > 0);
    
    SVHTMLIterator *iterator = [[SVHTMLIterator alloc] initWithCount:count];
    [_iteratorsStack addObject:iterator];
    [iterator release];
}

- (void)popIterator;  // Pops the iterators stack early
{
    [_iteratorsStack removeLastObject];
}

#pragma mark Extra markup

- (NSMutableString *)extraHeaderMarkup; // can append to, query, as you like while parsing
{
    return _headerMarkup;
}

- (void)writeExtraHeaders;  // writes any code plug-ins etc. have requested should inside the <head> element
{
    // Start buffering into a temporary string writer
    NSMutableString *buffer = [[NSMutableString alloc] init];
    [_stringWriter release]; _stringWriter = buffer;
}

- (id <KSStringWriter>)stringWriter
{
    //  Override to force use of our own writer
    return _stringWriter;
}

- (NSMutableString *)endBodyMarkup; // can append to, query, as you like while parsing
{
    return _endBodyMarkup;
}

- (void)writeEndBodyString; // writes any code plug-ins etc. have requested should go at the end of the page, before </body>
{
    // Finish buffering extra header
    id <KSStringWriter> buffer = _stringWriter;
    _stringWriter = [[super stringWriter] retain];
    
    [self writeString:[self extraHeaderMarkup]];
    
    [self writeString:(NSString *)buffer];
    [buffer release];
    
    
    // Write the end body markup
    [self writeString:[self endBodyMarkup]];
}

#pragma mark Content

- (void)willBeginWritingGraphic:(SVGraphic *)object;
{
    _numberOfGraphics++;
}

- (void)didEndWritingGraphic; { }

- (NSUInteger)numberOfGraphicsOnPage; { return _numberOfGraphics; }

// Two methods do the same thing. Need to ditch -addDependencyOnObject:keyPath: at some point
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath { }
- (void)addDependencyForKeyPath:(NSString *)keyPath ofObject:(NSObject *)object;
{
    [self addDependencyOnObject:object keyPath:keyPath];
}

#pragma mark Raw Writing

- (void)writeAttributedHTMLString:(NSAttributedString *)attributedHTML;
{
    //  Pretty similar to -[SVRichText richText]. Perhaps we can merge the two eventually?
    
    
    NSRange range = NSMakeRange(0, [attributedHTML length]);
    NSUInteger location = 0;
    
    while (location < range.length)
    {
        NSRange effectiveRange;
        SVGraphic *attachment = [attributedHTML attribute:@"SVAttachment"
                                                  atIndex:location
                                    longestEffectiveRange:&effectiveRange
                                                  inRange:range];
        
        if (attachment)
        {
            // Write the graphic
            [attachment writeHTML:self];
        }
        else
        {
            NSString *html = [[attributedHTML string] substringWithRange:effectiveRange];
            [self writeHTMLString:html];
        }
        
        // Advance the search
        location = location + effectiveRange.length;
    }
}


#pragma mark Legacy

@synthesize page = _currentPage;
- (void)setPage:(KTPage *)page
{
    page = [page retain];
    [_currentPage release], _currentPage = page;
    
    [self setBaseURL:[page URL]];
}

#pragma mark SVPlugInContext

- (KSHTMLWriter *)HTMLWriter; { return self; }

@end


#pragma mark -



@implementation SVHTMLIterator

- (id)initWithCount:(NSUInteger)count;
{
    [self init];
    _count = count;
    return self;
}

@synthesize count = _count;

@synthesize iteration = _iteration;

- (NSUInteger)nextIteration;
{
    _iteration = [self iteration] + 1;
    if (_iteration == [self count]) _iteration = NSNotFound;
    return _iteration;
}

@end

