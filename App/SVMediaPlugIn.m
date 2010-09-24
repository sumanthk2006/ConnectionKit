//
//  SVMediaPlugIn.m
//  Sandvox
//
//  Created by Mike on 24/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVMediaPlugIn.h"


@implementation SVMediaPlugIn

#pragma mark Metrics

- (BOOL)isExplicitlySized; { return YES; }

- (CGSize)originalSize;
{
    CGSize result = CGSizeZero;
    
    SVMediaGraphic *container = [self container];
    
    SVMediaRecord *media = [container media];
    if (media)
	{
		NSNumber *naturalWidth = container.naturalWidth;
		NSNumber *naturalHeight = container.naturalHeight;
		// Try to get cached natural size first
		if (nil != naturalWidth && nil != naturalHeight)
		{
			result = CGSizeMake([naturalWidth floatValue], [naturalHeight floatValue]);
		}
		else	// ask the media for it, and cache it.
		{
			result = [media originalSize];
			container.naturalWidth = [NSNumber numberWithFloat:result.width];
			container.naturalHeight = [NSNumber numberWithFloat:result.height];
		}
	}
	if (CGSizeEqualToSize(result, CGSizeMake(0.0,0.0)))
	{
		result = CGSizeMake(200.0f, 128.0f);
	}
    return result;
}

- (void)makeOriginalSize;
{
    SVMediaGraphic *container = [self container];
    [container makeOriginalSize];
}

@end
