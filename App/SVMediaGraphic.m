//
//  SVMediaGraphic.m
//  Sandvox
//
//  Created by Mike on 04/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaGraphic.h"

#import "SVAudio.h"
#import "SVFlash.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "KTImageScalingURLProtocol.h"
#import "KTMaster.h"
#import "SVMediaGraphicInspector.h"
#import "SVMediaRecord.h"
#import "SVImage.h"
#import "KTPage.h"
#import "SVTextAttachment.h"
#import "KSWebLocation.h"
#import "SVVideo.h"

#import "NSError+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSURLUtilities.h"


@interface SVMediaGraphic ()

@property(nonatomic, retain, readwrite) SVMediaRecord *media;
@property(nonatomic, copy, readwrite) NSURL *externalSourceURL;
@property(nonatomic, copy) NSString *externalSourceURLString;

- (void)setSourceWithMediaRecord:(SVMediaRecord *)media;
- (void)didSetSource;

@property(nonatomic, copy, readwrite) NSNumber *constrainedAspectRatio;

@end


#pragma mark -


@implementation SVMediaGraphic

#pragma mark Init

+ (id)insertNewGraphicInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVMediaGraphic *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaGraphic"
                                                           inManagedObjectContext:context];
    [result setWidth:nil];  // graphics normally default to 200px. #92688
    [result loadPlugInAsNew:YES];
    return result;
}

- (void)didAddToPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media] && ![self externalSourceURL])
    {
        SVMediaRecord *media = [[page master] makePlaceholdImageMediaWithEntityName:
                                [[self class] mediaEntityName]];
        
        [self setSourceWithMediaRecord:media];
        [self setTypeToPublish:[media typeOfFile]];
        [self makeOriginalSize];
        [self setConstrainProportions:[self isConstrainProportionsEditable]];
    }
    
    
    // Placeholder images have effectively changed source. #94513
    if ([[self media] isPlaceholder])
    {
        [self didSetSource];
    }
    
    
    [super didAddToPage:page];
    
    
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

#pragma mark Plug-in

- (NSString *)plugInIdentifier;
{
    // The plug-in to use depends on the type of file you have. Ideally use .codecType as it means the file's content has been better analyzed
    NSString *type = [self codecType];
    if (!type) type = [[self media] typeOfFile];
    if (!type) type = [NSString UTIForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    
    
    if ([type conformsToUTI:(NSString *)kUTTypeMovie] ||
        [type conformsToUTI:(NSString *)kUTTypeVideo] ||
        [type isEqualToString:@"unloadable-video"])	// special case for video we can't actually play on this machine
    {
        return @"com.karelia.sandvox.SVVideo";
    }
    else if ([type conformsToUTI:(NSString *)kUTTypeAudio] ||
             [type conformsToUTI:@"com.apple.quicktime-audio"] ||   // nothing built-in that I can see
			 [type isEqualToString:@"unloadable-audio"])	// special case for audio we can't actually play on this machine
    {
        return @"com.karelia.sandvox.SVAudio";
    }
    else if ([type conformsToUTI:@"com.adobe.shockwave-flash"] ||
             [type conformsToUTI:@"com.macromedia.shockwave-flash"])
		// annoying to have to check both, but somehow I got the macromedia UTI....
    {
        return @"com.karelia.sandvox.SVFlash";
    }
    else
    {
        return @"com.karelia.sandvox.Image";
    }
}

#pragma mark Placement

- (BOOL)isPagelet;
{
    // Images are no longer pagelets once you turn off all additional stuff like title & caption
    if ([[self placement] intValue] == SVGraphicPlacementInline &&
        ![self showsTitle] &&
        ![self showsIntroduction] &&
        ![self showsCaption])
    {
        return NO;
    }
    else
    {
        return [super isPagelet];
    }
}

#pragma mark Media

@dynamic media;

- (void)setSourceWithMedia:(SVMedia *)media;
{
    SVMediaRecord *record = [SVMediaRecord mediaRecordWithMedia:media
                                                     entityName:[[self class] mediaEntityName]
                                 insertIntoManagedObjectContext:[self managedObjectContext]];
    
    [self setSourceWithMediaRecord:record];
}

- (void)setSourceWithMediaRecord:(SVMediaRecord *)media;
{
    [self replaceMedia:media forKeyPath:@"media"];
    [self didSetSource];
}

+ (NSString *)mediaEntityName; { return @"GraphicMedia"; }

@dynamic isMediaPlaceholder;

#pragma mark External URL

@dynamic externalSourceURLString;

- (NSURL *)externalSourceURL
{
    NSString *string = [self externalSourceURLString];
    return (string) ? [NSURL URLWithString:string] : nil;
}
- (void)setExternalSourceURL:(NSURL *)URL
{
    if (URL) [self replaceMedia:nil forKeyPath:@"media"];
    
    // Bindings can sometimes call this twice while swapping plug-in Inspector types, so we have to be a bit defensive to avoid calling -didSetSource twice
    if (![[URL absoluteString] isEqualToString:[[self externalSourceURL] absoluteString]])
    {
        [self setExternalSourceURLString:[URL absoluteString]];
        if (URL) [self didSetSource];
    }
}

- (void)setSourceWithExternalURL:(NSURL *)URL;
{
    [self setExternalSourceURL:URL];
}

#pragma mark Source

- (void)reloadPlugInIfNeeded
{
    // Does this change the type?
    NSString *identifier = [self plugInIdentifier];
    SVGraphicFactory *factory = [SVGraphicFactory factoryWithIdentifier:identifier];
    
    if (![[self plugIn] isKindOfClass:[factory plugInClass]])
    {
        NSNumber *width = [self width];
        
        [self loadPlugInAsNew:NO];
        [[self plugIn] awakeFromNew];   // which will probably set size…
        
        // …so bring the width back to desired value
        [self setContentWidth:width];
    }
    
}

- (void)didSetSource;
{
    // Reset size & codecType BEFORE media so setting the source can store a new size
    self.naturalWidth = nil;
    self.naturalHeight = nil;
    [self setCodecType:nil];
    
    
    // Reset type
    NSString *type = [[self media] typeOfFile];
    if (!type) type = [NSString UTIForFilenameExtension:[[self externalSourceURL] ks_pathExtension]];
    [self setTypeToPublish:type];
    
    
    // Reset poster frame
    [[[self posterFrame] managedObjectContext] deleteObject:[self posterFrame]];
    [self replaceMedia:nil forKeyPath:@"posterFrame"];
    
    
    [self reloadPlugInIfNeeded];
    
    
    [[self plugIn] didSetSource];
}

- (NSURL *)sourceURL;
{
    NSURL *result = nil;
    
    SVMediaRecord *record = [self media];
    if (record)
    {
        result = [record fileURL];
        if (!result) result = [[record media] mediaURL];
    }
    else
    {
        result = [self externalSourceURL];
    }
    
    return result;
}

- (BOOL)hasFile; { return YES; }

+ (BOOL)acceptsType:(NSString *)uti; { return NO; }

+ (NSArray *)allowedTypes;
{
    NSMutableSet *result = [NSMutableSet set];
    [result addObjectsFromArray:[SVImage allowedFileTypes]];
    [result addObjectsFromArray:[SVVideo allowedFileTypes]];
    [result addObjectsFromArray:[SVAudio allowedFileTypes]];
    [result addObjectsFromArray:[SVFlash allowedFileTypes]];
    
	return [result allObjects];
}

- (BOOL)validateSource:(NSError **)error;
{
    // Must have media OR external URL as soure. #92086
    if (![self media] && ![self externalSourceURL])
    {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                               code:NSValidationMissingMandatoryPropertyError
                               localizedDescription:@"Must have either media or external URL as source"];
        
        return NO;
    }
    
    return YES;
}

#pragma mark Poster Frame

@dynamic posterFrame;
- (BOOL)validatePosterFrame:(SVMediaRecord **)media error:(NSError **)error;
{
    BOOL result = [[self plugIn] validatePosterFrame:*media];
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError localizedDescription:@"Plug-in doesn't want a poster image"];
    }
    
    return result;
}

#pragma mark Media Type

- (NSString *)codecType; { return [self extensiblePropertyForKey:@"codecType"]; }
- (void)setCodecType:(NSString *)type;
{
    if (type)
    {
        [self setExtensibleProperty:type forKey:@"codecType"];
    }
    else
    {
        [self removeExtensiblePropertyForKey:@"codecType"];
    }
}

- (BOOL)usesExtensiblePropertiesForUndefinedKey:(NSString *)key;
{
    return ([key isEqualToString:@"codecType"] ?
            YES :
            [super usesExtensiblePropertiesForUndefinedKey:key]);
}

@dynamic typeToPublish;
- (BOOL)validateTypeToPublish:(NSString **)type error:(NSError **)error;
{
    BOOL result = [[self plugIn] validateTypeToPublish:*type];
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSValidationMissingMandatoryPropertyError localizedDescription:@"typeToPublish is non-optional for images"];
    }
    
    return result;
}

#pragma mark Size

- (void)setConstrainProportions:(BOOL)constrainProportions;
{
    if (constrainProportions)
    {
        // Doesn't make sense to constrain proportions unless both values are known
        OBASSERT([[self height] intValue] > 0);
        OBASSERT([[self width] intValue] > 0);
        
        CGFloat aspectRatio = [[self width] floatValue] / [[self height] floatValue];
        [self setConstrainedAspectRatio:[NSNumber numberWithFloat:aspectRatio]];
    }
    else
    {
        [self setConstrainedAspectRatio:nil];
    }
}

+ (NSSet *)keyPathsForValuesAffectingConstrainProportions;
{
    return [NSSet setWithObject:@"constrainedAspectRatio"];
}

@dynamic constrainedAspectRatio;

@dynamic naturalWidth;
@dynamic naturalHeight;

#pragma mark Size, inherited

- (BOOL)validateWidth:(NSNumber **)width error:(NSError **)error;
{
    // SVGraphic.width is optional. For media graphics it becomes compulsory unless using external URL
    BOOL result = (*width != nil || (![self media] && [self externalSourceURL]));
    if (!result && error)
    {
        *error = [NSError errorWithDomain:NSCocoaErrorDomain
                                     code:NSValidationMissingMandatoryPropertyError
                     localizedDescription:@"width is a mandatory property"];
    }
    
    return result;
}

- (BOOL)validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // Push off validation to plug-in
    return [[self plugIn] validateHeight:height error:error];
}

#pragma mark Validation

- (BOOL)validateForInsert:(NSError **)error;
{
    if ([super validateForInsert:error])
    {
        return [self validateSource:error];
    }
    
    return NO;
}

- (BOOL)validateForUpdate:(NSError **)error;
{
    if ([super validateForUpdate:error])
    {
        return [self validateSource:error];
    }
    
    return NO;
}

#pragma mark HTML

- (void)writeBody:(SVHTMLContext *)context
{
    [context addDependencyOnObject:self keyPath:@"media"];
    if (![self media]) [context addDependencyOnObject:self keyPath:@"externalSourceURL"];
    
    
    // Pagelets expect a few extra classes
    BOOL isPagelet = [self isPagelet];
    NSString *elementClass = [[[self plugIn] class] elementClassName];
    NSString *contentClass = [[[self plugIn] class] contentClassName];
    
    if (isPagelet && elementClass && contentClass)
    {
        [context startElement:@"div" className:elementClass];
        [context startElement:@"div" className:contentClass];
        
        [super writeBody:context];
        
        [context endElement];
        [context endElement];
    }
    else
    {
        [super writeBody:context];
    }
}

- (void)buildClassName:(SVHTMLContext *)context;
{
    [super buildClassName:context];
    
    NSString *elementClass = [[[self plugIn] class] elementClassName];
    if (elementClass) [context pushClassName:elementClass];
}

- (BOOL)shouldWriteHTMLInline;
{
    BOOL result = [super shouldWriteHTMLInline];
    
    // Media becomes inline once you turn off all additional stuff like title & caption
    if (![self isPagelet])
    {
        SVTextAttachment *attachment = [self textAttachment];
        if (![[attachment causesWrap] boolValue])
        {
            result = YES;
        }
        else
        {
            SVGraphicWrap wrap = [[attachment wrap] intValue];
            result = (wrap == SVGraphicWrapRight ||
                      wrap == SVGraphicWrapLeft ||
                      wrap == SVGraphicWrapNone);
        }
    }
    
    return result;
}

- (BOOL)canWriteHTMLInline; { return [[self plugIn] canWriteHTMLInline]; }

#pragma mark Inspector

- (Class)inspectorFactoryClass; { return [[self plugIn] class]; }

- (id)objectToInspect; { return self; }

#pragma mark Thumbnail

- (void)writeThumbnailImage:(SVHTMLContext *)context
                   maxWidth:(NSUInteger)width
                  maxHeight:(NSUInteger)height;
{
    id <SVMedia> media = [[self plugIn] thumbnailMedia];
    if (media)
    {
        // Calculate dimensions
        NSNumber *aspectRatioNumber = [self constrainedAspectRatio];
        [context addDependencyOnObject:self keyPath:@"constrainedAspectRatio"];
        
        CGFloat aspectRatio;
        if (aspectRatioNumber)
        {
            aspectRatio = [aspectRatioNumber floatValue];
        }
        else
        {
            aspectRatio = [[self width] floatValue] / [[self height] floatValue];
            [context addDependencyOnObject:self keyPath:@"width"];
            [context addDependencyOnObject:self keyPath:@"height"];
        }
        
        if (aspectRatio > 1.0f)
        {
            height = width / aspectRatio;
        }
        else if (aspectRatio < 1.0f)
        {
            width = height * aspectRatio;
        }
        
        
        // Type? Images want to pick their own, but movies etc. must be converted to JPEG
        NSString *type = [self typeToPublish];
        CFArrayRef types = CGImageDestinationCopyTypeIdentifiers();
        if (![(NSArray *)types containsObject:type]) type = (NSString *)kUTTypeJPEG;
        CFRelease(types);
        
        
        // During editing, cheat and use special URL if possible. #98041
        if ([context isForEditing] && ![media mediaData])
        {
            NSURL *url = [NSURL sandvoxImageURLWithFileURL:[media mediaURL]
                                                      size:NSMakeSize(width, height)
                                               scalingMode:0
                                                sharpening:0.0f
                                         compressionFactor:1.0f
                                                  fileType:type];
            
            [context writeImageWithSrc:[context relativeURLStringOfURL:url]
                                   alt:@""
                                 width:[NSNumber numberWithUnsignedInteger:width]
                                height:[NSNumber numberWithUnsignedInteger:height]];
        }
        else
        {
            // Where to publish?
            NSString *filename = [[[media preferredUploadPath] lastPathComponent] stringByDeletingPathExtension];
            filename = [filename stringByAppendingFormat:@"_%u", width];
            filename = [filename stringByAppendingPathExtension:[NSString filenameExtensionForUTI:type]];
            
            // Write out the image
            [context writeImageWithSourceMedia:media
                                           alt:@""
                                         width:[NSNumber numberWithUnsignedInteger:width]
                                        height:[NSNumber numberWithUnsignedInteger:height]
                                          type:type
                             preferredFilename:filename];
        }
    }
}

- (id <SVMedia>)thumbnailMedia;
{
    return [[self plugIn] thumbnailMedia];	// video may want to return poster frame
}

- (id)imageRepresentation;
{
	return [[self plugIn] imageRepresentation];
}

- (NSString *)imageRepresentationType
{
	return [[self plugIn] imageRepresentationType];
}

+ (NSSet *)keyPathsForValuesAffectingImageRepresentation { return [NSSet setWithObject:@"media"]; }

#pragma mark RSS Enclosure

- (id <SVEnclosure>)enclosure;
{
	return [self plugIn];
}

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    SVMediaRecord *record = [self media];
    
    if ([record fileURL])
    {
        [propertyList setObject:[[record fileURL] absoluteString] forKey:@"fileURL"];
    }
    else
    {
        NSData *data = [[record media] mediaData];
        [propertyList setValue:data forKey:@"fileContents"];
    }
    
    NSURL *URL = [self sourceURL];
    [propertyList setValue:[URL absoluteString] forKey:@"sourceURL"];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    [super awakeFromPropertyList:propertyList];
    
    // Pull out image data
    SVMediaRecord *record = nil;
    
    NSData *data = [propertyList objectForKey:@"fileContents"];
    if (data)
    {
        NSString *urlString = [propertyList objectForKey:@"sourceURL"];
        NSURL *url = [NSURL URLWithString:urlString];
        SVMedia *media = [[SVMedia alloc] initWithData:data URL:url];
        
        record = [SVMediaRecord mediaRecordWithMedia:media
                                          entityName:[[self class] mediaEntityName]
                      insertIntoManagedObjectContext:[self managedObjectContext]];
        
        [media release];
    }
    else
    {
        NSString *fileURL = [propertyList objectForKey:@"fileURL"];
        if (fileURL)
        {
            record = [SVMediaRecord mediaByReferencingURL:[NSURL URLWithString:fileURL]
                                     entityName:[[self class] mediaEntityName]
                 insertIntoManagedObjectContext:[self managedObjectContext]
                                          error:NULL];
        }
    }
    
    if (record) [self replaceMedia:record forKeyPath:@"media"];
}

#pragma mark Pasteboard

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    BOOL result = [super awakeFromPasteboardItems:items];
    
    
    NSString *title = [[items lastObject] title];
    if (title) [self setTitle:title];
    
    
    // Can we read a media oject from the pboard?
    SVMediaRecord *record = nil;
    id <SVPasteboardItem> item = [items objectAtIndex:0];
    
    NSURL *URL = [item URL];
    if ([URL isFileURL])
    {
        record = [SVMediaRecord mediaByReferencingURL:URL
                                 entityName:[[self class] mediaEntityName]
             insertIntoManagedObjectContext:[self managedObjectContext]
                                      error:NULL];
    }
    else
    {
        NSString *type = [item availableTypeFromArray:[SVImage allowedFileTypes]];
        if (type)
        {
            // Invent a URL
            NSString *extension = [NSString filenameExtensionForUTI:type];
            
            NSString *path = [[@"/" stringByAppendingPathComponent:@"pasted-file"]
                              stringByAppendingPathExtension:extension];
            
            // TODO: Use as much of URL as possible
            NSURL *url = [NSURL URLWithScheme:@"sandvox-fake-url"
                                         host:[NSString UUIDString]
                                         path:path];        
            
            SVMedia *media = [[SVMedia alloc] initWithData:[item dataForType:type] URL:url];
            
            record = [SVMediaRecord mediaRecordWithMedia:media
                                              entityName:[[self class] mediaEntityName]
                          insertIntoManagedObjectContext:[self managedObjectContext]];
            [media release];
        }
    }
    
    
    // Swap in the new media
    if (record)
    {
        [self setSourceWithMediaRecord:record];
		
		NSNumber *oldWidth = [self width];
		[self makeOriginalSize];
		[self setConstrainProportions:[self isConstrainProportionsEditable]];
		if (oldWidth)
		{
			[self setContentWidth:oldWidth];
		}
		else
		{
			if ([[self width] integerValue] > 200)
			{
				[self setContentWidth:[NSNumber numberWithInt:200]];
			}
			// If going from external URL to proper media, this means your image is quite probably now 200px wide. Not ideal, but so rare I'm not going to worry abiout it. #92576
		}
    
        result = [[self plugIn] awakeFromPasteboardItems:items];
    }
    
    return result;
}

@end
