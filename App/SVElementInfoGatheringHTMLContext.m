//
//  SVElementInfoGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"

#import "SVDOMController.h"
#import "SVGraphic.h"


@implementation SVElementInfoGatheringHTMLContext

- (id)initWithOutputWriter:(id <KSWriter>)output;
{
    if (self = [super initWithOutputWriter:output])
    {
        _root = [[SVElementInfo alloc] init];   // start catching dependencies immediately
        _openElementInfos = [[NSMutableArray alloc] initWithObjects:_root, nil];
    }
    
    return self;
}

- (void)close;
{
    [super close];
    
    [_openElementInfos release]; _openElementInfos = nil;   // so more can't be added
}

- (void)dealloc;
{
    [_root release];
    // _openElementInfos is handled by super calling through to -close
    
    [super dealloc];
}

#pragma mark Elements

@synthesize rootElement = _root;

- (SVElementInfo *)currentElement;
{
    SVElementInfo *result = _earlyElement;
    if (!result) result = [_openElementInfos lastObject];
    return result;
}

- (void)willStartElement:(NSString *)element;
{
    // Let superclasses queue up any last minute stuff as they like
    [super willStartElement:element];
    
    
    // Stash a copy of the element
    if (_openElementInfos)
    {
        SVElementInfo *info;
        if (_earlyElement)
        {
            info = _earlyElement;
            _earlyElement = nil;
        }
        else
        {
            info = [[SVElementInfo alloc] init];
        }
        
        [info setAttributes:[[self currentAttributes] attributesAsDictionary]];
                
        [[self currentElement] addSubelement:info];
        [_openElementInfos addObject:info];
        
        [info release];
    }
}

- (void)endElement
{
    [super endElement];
    [_openElementInfos removeLastObject];
}

- (void)beginGraphicContainer:(id <SVComponent>)container;
{
    if (container)
    {
        //OBPRECONDITION(!_earlyElement);
        _earlyElement = [[SVElementInfo alloc] initWithGraphicContainer:container];
    }
    
    [super beginGraphicContainer:container];
}

- (void)endGraphicContainer;
{
    [super endGraphicContainer];
    
    // If early is still around, that means it never go written
    [_earlyElement release]; _earlyElement = nil;
}

#pragma mark Resizable Elements

- (void)buildAttributesForResizableElement:(NSString *)elementName object:(NSObject *)object DOMControllerClass:(Class)controllerClass sizeDelta:(NSSize)sizeDelta options:(SVResizingOptions)options;
{
    // There may be a DOM Controller in place already, but most likely need to make a dedicated one
    if (!_earlyElement)
    {
        id <SVComponent> container = ([object isKindOfClass:[SVPlugIn class]] ?
                                             [object valueForKey:@"container"] :
                                             object);
        
        _earlyElement = [[SVElementInfo alloc] initWithGraphicContainer:container];
    }
    
    [super buildAttributesForResizableElement:elementName object:object DOMControllerClass:controllerClass sizeDelta:sizeDelta options:options];
    
    [[self currentElement] setHorizontallyResizable:YES];
    [[self currentElement] setVerticallyResizable:!(options & SVResizingDisableVertically)];
}

#pragma mark Dependencies

- (void)addDependency:(KSObjectKeyPathPair *)dependency
{
    SVElementInfo *element = [self currentElement];
    OBASSERT(element);
    [element addDependency:dependency];
}
    
- (void)addDependencyOnObject:(NSObject *)object keyPath:(NSString *)keyPath;
{
    [super addDependencyOnObject:object keyPath:keyPath];
    
    
    KSObjectKeyPathPair *pair = [[KSObjectKeyPathPair alloc] initWithObject:object
                                                                    keyPath:keyPath];
    [self addDependency:pair];
    [pair release];
}

@end


#pragma mark -


@implementation SVElementInfo

- (id)init
{
    if (self = [super init])
    {
        _subelements = [[NSMutableArray alloc] init];
        _dependencies = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (id)initWithGraphicContainer:(id <SVComponent>)container;
{
    if (self = [self init])
    {
        _graphicContainer = [container retain];
    }
    return self;
}

- (void)dealloc;
{
    [_attributes release];
    [_subelements release];
    [_graphicContainer release];
    [_dependencies release];
    
    [super dealloc];
}

@synthesize attributes = _attributes;

- (NSArray *)subelements; { return [[_subelements copy] autorelease]; }

- (void)addSubelement:(SVElementInfo *)element;
{
    [_subelements addObject:element];
}

#pragma mark Sandvox Properties

@synthesize graphicContainer = _graphicContainer;
@synthesize elementIdNameWasInvented = _elementIdNameWasInvented;

- (NSSet *)dependencies; { return [[_dependencies copy] autorelease]; }

- (void)addDependency:(KSObjectKeyPathPair *)dependency;
{
    [_dependencies addObject:dependency];
}

@synthesize horizontallyResizable = _horizontallyResizable;
@synthesize verticallyResizable = _verticallyResizable;

@end