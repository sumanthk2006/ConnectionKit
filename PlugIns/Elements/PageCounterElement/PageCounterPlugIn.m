//
//  PageCounterPlugIn.m
//  PageCounterElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//


#import "PageCounterPlugIn.h"

 /*
  
  DROP TABLE IF EXISTS PageCounts;
  CREATE TABLE  `PageCounts` (
							  `urlID` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT ,
							  `url` VARCHAR(100) CHARACTER SET utf8 COLLATE utf8_unicode_ci NOT NULL ,
							  `count` BIGINT NOT NULL default '0',
							  PRIMARY KEY(urlID)
							  ) ENGINE = innodb CHARACTER SET utf8 COLLATE utf8_unicode_ci;
  
  ALTER TABLE PageCounts ADD INDEX(url);
  
  */
 

//LocalizedStringInThisBundle("page views",@" preceeded by a number to show how many times a page has been viewed over the web");


NSString *PCThemeKey = @"theme";
NSString *PCTypeKey = @"type";		
NSString *PCWidthKey = @"width";
NSString *PCHeightKey = @"height";
NSString *PCImagesPathKey = @"path";
NSString *PCSampleImageKey = @"sampleImage";


@implementation PageCounterPlugIn


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"selectedThemeIndex", 
            nil];
}


#pragma mark Initialization

+ (NSArray *)themes
{
	static NSArray *sThemes;
	
	if (!sThemes)
	{
		NSMutableArray *themes = [NSMutableArray array];
		NSMutableDictionary *d;
		
		d = [NSMutableDictionary dictionary];
		[d setObject:LocalizedStringInThisBundle(@"Text", @"Text style of page counter") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithUnsignedInteger:PC_TEXT] forKey:PCTypeKey];
		[themes addObject:d];
		
		d = [NSMutableDictionary dictionary];
		[d setObject:LocalizedStringInThisBundle(@"Invisible", @"Invisible style of page counter; outputs no number") forKey:PCThemeKey];
		[d setObject:[NSNumber numberWithUnsignedInteger:PC_INVISIBLE] forKey:PCTypeKey];
		[themes addObject:d];
		
		NSString *resourcePath = [[NSBundle bundleForClass:[PageCounterPlugIn class]] resourcePath];
		resourcePath = [resourcePath stringByAppendingPathComponent:@"digits"];
		NSString *fileName;
		NSDirectoryEnumerator *dirEnum =
		[[NSFileManager defaultManager] enumeratorAtPath:resourcePath];
		
		while (fileName = [dirEnum nextObject])
		{
			// Look for all "0" digits to represent the whole group.
			// MUST END WITH .png
			unsigned int whereZeroPng = [fileName rangeOfString:@"-0.png"].location;
			if (NSNotFound != whereZeroPng)
			{
				NSString *path = [resourcePath stringByAppendingPathComponent:fileName];
				
				// Determine image size
				NSSize size = NSMakeSize(0,0);
				NSURL *url = [NSURL fileURLWithPath:path];
				CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
				if (source)
				{
					NSDictionary *props = (NSDictionary *) CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
					
					size = NSMakeSize([[props objectForKey:(NSString *)kCGImagePropertyPixelWidth] intValue],
									  [[props objectForKey:(NSString *)kCGImagePropertyPixelHeight] intValue]);
					CFRelease(source);
					[props release];
					
					if (!NSEqualSizes(size, NSZeroSize))
					{
						// Get the other properties into a dictionary
						NSString *baseName = [fileName substringToIndex:whereZeroPng];
						d = [NSMutableDictionary dictionary];
						[d setObject:[NSNumber numberWithUnsignedInteger:PC_GRAPHICS] forKey:PCTypeKey];
						[d setObject:baseName forKey:PCThemeKey];	// Used internally not for display
						[d setObject:[NSNumber numberWithInt:(int)size.width] forKey:PCWidthKey];
						[d setObject:[NSNumber numberWithInt:(int)size.height] forKey:PCHeightKey];
						[themes addObject:d];
						
	#define MAX_SAMPLE_WIDTH 148	// best width for a 250 pixel inspector; depends on nib width!
						
						int maxDigits = MAX_SAMPLE_WIDTH / (int) size.width;
						
						NSRect digitRect = NSMakeRect(0,0,size.width, size.height);
						NSImage *sampleImage = [[[NSImage alloc] initWithSize:NSMakeSize(size.width * maxDigits, size.height)] autorelease];
						[sampleImage lockFocus];
						int i;
						for (i = 0 ; i < maxDigits ; i++)
						{
							NSString *digitFilePath = [resourcePath stringByAppendingPathComponent:
								[NSString stringWithFormat:@"%@-%d.png", baseName, i]];
							NSImage *digitImage = [[[NSImage alloc] initWithContentsOfFile:digitFilePath] autorelease];
							[digitImage drawAtPoint:NSMakePoint(size.width * i, 0) fromRect:digitRect operation:NSCompositeSourceOver fraction:1.0];
						}
								
						[sampleImage unlockFocus];
						[d setObject:sampleImage forKey:PCSampleImageKey];
					}
				}
			}
		}
		
		// Add any from user defaults  (NOT SURE HOW THIS WOULD REALLY WORK...
		NSArray *ud = [[NSUserDefaults standardUserDefaults] objectForKey:@"PageCounterThemes"];
		if (ud)
		{ 
			[themes addObjectsFromArray:ud];
		}
		
		
		// Store the themes
		sThemes = [[NSArray alloc] initWithArray:themes];
	}
	
	return sThemes;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"selectedThemeIndex" ofObject:self];
    
    // add resources
	if (PC_GRAPHICS == self.themeType)
	{
		NSString *theme = self.themeTitle;
		NSBundle *b = [self bundle];
		NSString *imagePath = [self.selectedTheme objectForKey:PCImagesPathKey];	// from default
		
		unsigned i;
		
		for (i = 0; i < 10; i++)
		{
			NSString *format = [NSString stringWithFormat:@"%@-%d.png", theme, i];
			if (imagePath)
			{
                NSURL *imageURL = [NSURL fileURLWithPath:[imagePath stringByAppendingPathComponent:format]];
                [context addResourceWithURL:imageURL];
			}
			else
			{
				NSString *resource = [b pathForResource:[format stringByDeletingPathExtension]
                                                 ofType:[format pathExtension] 
                                            inDirectory:@"digits"];
                OBASSERT(resource);
                NSURL *resourceURL = [NSURL fileURLWithPath:resource];
                [context addResourceWithURL:resourceURL];
			}
		}
	}
}

- (NSURL *)previewResourceDirectory
{
	NSString *path = [[[self bundle] resourcePath] stringByAppendingPathComponent:@"digits"];
	return [NSURL fileURLWithPath:path];
}


#pragma mark Properties

@synthesize selectedThemeIndex = _selectedThemeIndex;

- (NSArray *)themes
{
	return [[self class] themes];
}

- (NSDictionary *)selectedTheme
{
    NSUInteger index = self.selectedThemeIndex;
    //FIXME: is this guard really necessary?
    if ( index >= self.themes.count ) index = 0;
    return [self.themes objectAtIndex:self.selectedThemeIndex];
}

- (NSString *)themeTitle
{
	return [self.selectedTheme objectForKey:PCThemeKey];
}

- (id)themeWidth
{
	return [self.selectedTheme objectForKey:PCWidthKey];
}

- (id)themeHeight
{
	return [self.selectedTheme objectForKey:PCHeightKey];
}

- (NSUInteger)themeType
{ 
	return [[self.selectedTheme objectForKey:PCTypeKey] unsignedIntegerValue];
}

@end
