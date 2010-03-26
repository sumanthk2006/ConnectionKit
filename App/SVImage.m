// 
//  SVImage.m
//  Sandvox
//
//  Created by Mike on 27/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImage.h"

#import "SVApplicationController.h"
#import "SVImageDOMController.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"
#import "SVWebEditorHTMLContext.h"

#import "NSManagedObject+KTExtensions.h"


@interface SVImage ()

@property(nonatomic, copy) NSString *externalSourceURLString;

@property(nonatomic, copy) NSNumber *constrainedAspectRatio;

@end


#pragma mark -


@implementation SVImage 

+ (SVImage *)insertNewImageWithMedia:(SVMediaRecord *)media;
{
    SVImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"Image"
                                                   inManagedObjectContext:[media managedObjectContext]];
    [result setMedia:media];
    
    CGSize size = [result originalSize];
    [result setWidth:[NSNumber numberWithFloat:size.width]];
    [result setHeight:[NSNumber numberWithFloat:size.height]];
    [result setConstrainProportions:YES];
    
    return result;
}

- (void)awakeFromInsert
{
    [super awakeFromInsert];
    
    // Use same format & compression as last image
    BOOL prefersPNG = [[NSUserDefaults standardUserDefaults] boolForKey:kSVPrefersPNGImageFormatKey];
    if (prefersPNG)
    {
        [self setStorageType:[NSNumber numberWithInteger:NSPNGFileType]];
    }
}

#pragma mark Media

@dynamic media;
@dynamic externalSourceURLString;

- (NSURL *)externalSourceURL { return [NSURL URLWithString:[self externalSourceURLString]]; }
- (void)setExternalSourceURL:(NSURL *)URL
{
    if (URL) [[self managedObjectContext] deleteObject:[self media]];
    [self setExternalSourceURLString:[URL absoluteString]];
}

- (NSURL *)imagePreviewURL; // picks out URL from media, sourceURL etc.
{
    NSURL *result = nil;
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        result = [media fileURL];
        if (!result) result = [[media fileURLResponse] URL];
        [[SVHTMLContext currentContext] addMedia:media];
    }
    else
    {
        //result = [self sourceURL];
    }
    
    if (!result)
    {
        result = [self placeholderImageURL];
    }
    
    return result;
}

- (NSURL *)placeholderImageURL; // the fallback when no media or external source is chose
{
    NSURL *result = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"LogoPlaceholder"]];
    return result;
}

#pragma mark Metrics

@dynamic alternateText;

#pragma mark Placement

- (BOOL)canBePlacedInline; { return YES; }

#pragma mark Size

@dynamic width;
- (void)setWidth:(NSNumber *)width;
{
    [self willChangeValueForKey:@"width"];
    [self setPrimitiveValue:width forKey:@"width"];
    [self didChangeValueForKey:@"width"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger height = ([width floatValue] / [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"height"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:height] forKey:@"height"];
        [self didChangeValueForKey:@"height"];
    }
}

@dynamic height;
- (void)setHeight:(NSNumber *)height;
{
    [self willChangeValueForKey:@"height"];
    [self setPrimitiveValue:height forKey:@"height"];
    [self didChangeValueForKey:@"height"];
    
    NSNumber *aspectRatio = [self constrainedAspectRatio];
    if (aspectRatio)
    {
        NSUInteger width = ([height floatValue] * [aspectRatio floatValue]);
        
        [self willChangeValueForKey:@"width"];
        [self setPrimitiveValue:[NSNumber numberWithUnsignedInteger:width] forKey:@"width"];
        [self didChangeValueForKey:@"width"];
    }
}

- (BOOL)constrainProportions { return [self constrainedAspectRatio] != nil; }
- (void)setConstrainProportions:(BOOL)constrainProportions;
{
    if (constrainProportions)
    {
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

- (CGSize)originalSize;
{
    CGSize result = CGSizeMake(200.0f, 128.0f);
    
    SVMediaRecord *media = [self media];
    if (media)
    {
        CIImage *image = [CIImage imageWithIMBImageItem:media];
        result = [image extent].size;
    }
    
    return result;
}

#pragma mark Link

@dynamic link;

#pragma mark Publishing

@dynamic storageType;
@dynamic compressionFactor;

#pragma mark HTML

- (void)writeBody
{
    SVHTMLContext *context = [SVHTMLContext currentContext];
    
    // src=
    NSURL *imageURL = [self imagePreviewURL];
    
    // alt=
    NSString *alt = [self alternateText];
    if (!alt) alt = @"";
    
    // Link
    if ([self isPagelet] && [self link])
    {
        [context writeAnchorStartTagWithHref:[[self link] URLString] title:nil target:nil rel:nil];
    }
    
    // Actually write the image
    [context writeImageWithIdName:[self editingElementID]
                        className:[self className]
                              src:[context relativeURLStringOfURL:imageURL]
                              alt:alt 
                            width:[[self width] description]
                           height:[[self height] description]];
    
    [context addDependencyOnObject:self keyPath:@"className"];
    
    if ([self isPagelet] && [self link]) [context writeEndTag];
}

- (BOOL)shouldPublishEditingElementID; { return NO; }

#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return [self media]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"media"]; }

#pragma mark Serialization

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    [super populateSerializedProperties:propertyList];
    
    // Write image data
    NSData *data = [[self media] fileContents];
    if (!data)
    {
        NSURL *URL = [[self media] fileURL];
        if (URL) data = [NSData dataWithContentsOfURL:URL];
    }
    [propertyList setValue:data forKey:@"fileContents"];
}

@end
