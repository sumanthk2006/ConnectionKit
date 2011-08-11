//
//  SVImageScalingOperation.m
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVImageScalingOperation.h"

#import "KTImageScalingSettings.h"
#import "KTImageScalingURLProtocol.h"
#import "SVMedia.h"
#import "SVMediaRequest.h"

#import "NSImage+KTExtensions.h"

#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"
#import "KSURLUtilities.h"

#import <QuartzCore/CoreImage.h>


@implementation SVImageScalingOperation

- (id)initWithMedia:(id <SVMedia>)media parameters:(NSDictionary *)params;
{
    [self init];
    
    _sourceMedia = [media retain];
    _parameters = [params copy];
    
    return self;
}

- (id)initWithURL:(NSURL *)URL;
{
    [self init];
 
	_sourceMedia = [[SVMedia alloc] initByReferencingURL:[NSURL fileURLWithPath:[URL path]
                                                                    isDirectory:NO]];
    
    _parameters = [[URL ks_queryParameters] copy];
    
    return self;
}

- (void)dealloc
{
    [_sourceMedia release];
    [_parameters release];
    [_result release];
    [_response release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize result = _result;
@synthesize returnedResponse = _response;

#pragma mark Work

/*  Support method to read in an image, scale it down and then create the the specified data representation
 */
- (NSData *)_loadImageScaledToSize:(NSSize)size type:(NSString *)fileType error:(NSError **)error // Mode will be read from the URL
{
#ifdef DEBUG
    NSDate *start = [NSDate date];
#endif
    
    // Load the image from disk
    CIImage *image;
    if ([_sourceMedia mediaData])
    {
        image = [[CIImage alloc] initWithData:[_sourceMedia mediaData]];
    }
    else
    {
        image = [[CIImage alloc] initWithContentsOfURL:[_sourceMedia mediaURL]];
        if (!image)
        {
            // Maybe it's a custom URL protocol
            NSData *data = [[NSData alloc] initWithContentsOfURL:[_sourceMedia mediaURL]];
            if (data)
            {
                image = [[CIImage alloc] initWithData:data];
                [data release];
            }
        }
    }
    
    if (!image)
    {
        if (error) *error = [NSError errorWithDomain:NSURLErrorDomain
                                                code:NSURLErrorResourceUnavailable
                                            userInfo:nil];
        return nil;
    }
    
    
    // Get hold of the color space first
    CGColorSpaceRef colorSpace = NULL;
    if ([image respondsToSelector:@selector(colorSpace)])
    {
        colorSpace = [image colorSpace];
    }
    
    
    // Construct image scaling properties dictionary from the URL
    NSDictionary *URLQuery = _parameters;
    KSImageScalingMode scalingMode = [URLQuery integerForKey:@"mode"];
    
    CGSize sourceSize = [image extent].size;
    if (sourceSize.width != size.width && sourceSize.height != size.height)
    {
        // Scale the image
        CIImage *scaledImage = [image imageByScalingToSize:CGSizeMake(size.width, size.height)
                                                            mode:scalingMode
                                                     opaqueEdges:YES];
        OBASSERT(scaledImage);
        
        
        // Sharpen if needed
        float sharpeningFactor = [URLQuery floatForKey:@"sharpen"];
        if (sharpeningFactor)
        {
            scaledImage = [scaledImage sharpenLuminanceWithFactor:sharpeningFactor];
        }
        OBASSERT(scaledImage);
        
        [scaledImage retain];
        [image release]; image = scaledImage;
    }
    
    
    // Ensure we have a graphics context big enough to render into
    // Cache contexts per thread
    CIContext *coreImageContext = [[[NSThread currentThread] threadDictionary]
                                    objectForKey:@"SVImageScalingOperationCIContext"];
    
    // Create CIIContext to match
    if (!coreImageContext)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        
        coreImageContext = [CIContext contextWithCGContext:nil
                                                   options:[NSDictionary dictionaryWithObjectsAndKeys:
                                                            NSBOOL(YES), kCIContextUseSoftwareRenderer,
                                                            colorSpace, kCIContextOutputColorSpace,
                                                            colorSpace, kCIContextWorkingColorSpace,
                                                            nil]];
        
        CFRelease(colorSpace);
        
        [[[NSThread currentThread] threadDictionary]
         setObject:coreImageContext forKey:@"SVImageScalingOperationCIContext"];
    }
    
    
    // Render a CGImage
    CGRect neededContextRect = [image extent];    // Clang, we assert scaledImage is non-nil above
    
    CGImageRef finalImage = NULL;
    if (colorSpace)
    {
        // Web browsers only support RGB and monochrome color spaces
        CGColorSpaceModel model = CGColorSpaceGetModel(colorSpace);
        if (model == kCGColorSpaceModelRGB || model == kCGColorSpaceModelMonochrome)
        {
            finalImage = [coreImageContext createCGImage:image
                                                fromRect:neededContextRect
                                                  format:kCIFormatARGB8
                                              colorSpace:colorSpace];
        }
    }
    
    if (!finalImage)
    {
        finalImage = [coreImageContext createCGImage:image fromRect:neededContextRect];
    }
    
    
    // If given a CMYK image that didn't need scaling, the result may not be in the desired colorspace. Try to force it to be
    CGColorSpaceModel model = CGColorSpaceGetModel(CGImageGetColorSpace(finalImage));
    if (model != kCGColorSpaceModelRGB && model != kCGColorSpaceModelMonochrome)
    {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        
        CGImageRef rgbImage = [coreImageContext createCGImage:image
                                                     fromRect:neededContextRect
                                                       format:kCIFormatARGB8
                                                   colorSpace:colorSpace];
        
        CFRelease(colorSpace);
        
        if (rgbImage)
        {
            CFRelease(finalImage); finalImage = rgbImage;
        }
    }
    
    
    OBASSERT(finalImage);
    
    
    // Convert to data
	NSArray *identifiers = (NSArray *)CGImageDestinationCopyTypeIdentifiers();
	OBASSERT([identifiers containsObject:fileType]);
    [identifiers release];
	
    
    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)result,
                                                                              (CFStringRef)fileType,
                                                                              1,
                                                                              NULL);
    OBASSERT(imageDestination);
    
    CGImageDestinationAddImage(imageDestination,
                               finalImage,
                               (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    if (!CGImageDestinationFinalize(imageDestination)) result = nil;
    CFRelease(imageDestination);
    CGImageRelease(finalImage); // On Tiger the CGImage MUST be released before deallocating the CIImage!
    [image release];
    
    
#ifdef DEBUG
    NSLog(@"Spent %fs doing Core Image", -[start timeIntervalSinceNow]);
#endif
    
    
    // Finish up
    return result;
}


/*  Support method to convert an image to the specified format without scaling
 */
- (NSData *)_loadImageConvertedToType:(NSString *)fileType error:(NSError **)error
{
    CGImageSourceRef imageSource;
    if ([_sourceMedia mediaData])
    {
        imageSource = CGImageSourceCreateWithData((CFDataRef)[_sourceMedia mediaData], NULL);
    }
    else
    {
        imageSource = CGImageSourceCreateWithURL((CFURLRef)[_sourceMedia mediaURL], NULL);
    }
    
    if (!imageSource)
    {
        // CGImageSource doesn't give proper error output, so assume it's because the file doesn't exist
        if (error)
        {
            *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadUnknownError userInfo:nil];
        }
        
        return nil;
    }
        
    
    NSMutableData *result = [NSMutableData data];
    CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)result,
                                                                              (CFStringRef)fileType,
                                                                              1,
                                                                              NULL);
    OBASSERT(imageDestination);
    
    CGImageDestinationAddImageFromSource(imageDestination,
                                         imageSource,
                                         0,
                                         (CFDictionaryRef)[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:0.7] forKey:(NSString *)kCGImageDestinationLossyCompressionQuality]);
    
    if (!CGImageDestinationFinalize(imageDestination)) result = nil;
    CFRelease(imageDestination);
    CFRelease(imageSource);
    
    return result;
}

- (NSData *)_loadFavicon:(NSError **)error
{
    NSImage *sourceImage;
    if ([_sourceMedia mediaData])
    {
        sourceImage = [[NSImage alloc] initWithData:[_sourceMedia mediaData]];
    }
    else
    {
        sourceImage = [[NSImage alloc] initWithContentsOfURL:[_sourceMedia mediaURL]];
    }
    
    NSData *result = [sourceImage faviconRepresentation];
    [sourceImage release];
    return result;
}

- (void)main
{
    @try
    {        
        // There are three possible ways to render the result
        //  A) Scale with CoreImage
        //  B) Convert without scaling using CGImageDestination/Source
        //  C) Create a favicon representation
        NSString *UTI = [_parameters objectForKey:@"filetype"];
        OBASSERT(UTI);
        
        NSData *imageData = nil;
        NSError *error = nil;
        
        if ([UTI isEqualToString:(NSString *)kUTTypeICO])
        {
            // This is a little bit of a hack as it ignores size info, and purely creates a favicon
            imageData = [self _loadFavicon:&error];
        }
        else
        {
            NSString *size = [_parameters objectForKey:@"size"];
            if (size)
            {
                imageData = [self _loadImageScaledToSize:NSSizeFromString(size) type:UTI error:&error];
            }
            else
            {
                imageData = [self _loadImageConvertedToType:UTI error:&error];
            }
        }
        
        
        
        if (imageData)
        {
            // Construct URL response for cache etc. to use
            NSURL *url = [NSURL sandvoxImageURLWithFileURL:[_sourceMedia mediaURL]
                                           queryParameters:_parameters];
            
            _response = [[NSURLResponse alloc] initWithURL:url
                                                  MIMEType:[KSWORKSPACE ks_MIMETypeForType:UTI]
                                     expectedContentLength:[imageData length]
                                          textEncodingName:nil];
            
            _result = [imageData retain];
        }
    }
    @catch (NSException *exception)
    {
        [NSApp performSelectorOnMainThread:@selector(reportException:) withObject:exception waitUntilDone:NO];
    }
}

+ (NSData *)dataWithMediaRequest:(SVMediaRequest *)request response:(NSURLResponse **)response;
{
    if ([request isNativeRepresentation])
    {
        NSData *result = [[request media] mediaData];
        if (!result) result = [NSData dataWithContentsOfURL:[[request media] mediaURL]];
        
        if (response) *response = nil;
        
        return result;
    }
    else
    {
        if ([NSThread isMainThread])
        {
            NSLog(@"Evaluating scaled image data on main thread which is inadvisable as generally takes a significant amount of time");
        }
        
        SVImageScalingOperation *op = [[SVImageScalingOperation alloc]
                                       initWithMedia:[request media]
                                       parameters:[request imageScalingParameters]];
        [op start];
        
        NSData *result = [[[op result] copy] autorelease];
        if (response) *response = [[[op returnedResponse] copy] autorelease];
        
        [op release];
        
        return result;
    }
}

@end
