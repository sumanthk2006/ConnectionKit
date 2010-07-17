//  DMLocalizedNibBundle.m
//
//  Created by William Jon Shipley on 2/13/05.
//  Copyright © 2005-2009 Golden % Braeburn, LLC. All rights reserved except as below:
//  This code is provided as-is, with no warranties or anything. You may use it in your projects as you wish, but you must leave this comment block (credits and copyright) intact. That's the only restriction -- Golden % Braeburn otherwise grants you a fully-paid, worldwide, transferrable license to use this code as you see fit, including but not limited to making derivative works.


#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>


@interface NSBundle (DMLocalizedNibBundle)
+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
@end

@interface NSBundle ()
+ (void)				  _localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (NSString *)	 _localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
// localize particular attributes in objects
+ (void)					_localizeTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)		   _localizeAlternateTitleOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)			  _localizeStringValueOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)		_localizePlaceholderStringOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
+ (void)				  _localizeToolTipOfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
@end


@implementation NSBundle (DMLocalizedNibBundle)

#pragma mark NSObject

//+ (void)load;
//{
//    NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
//    if (self == [NSBundle class]) {
//		NSLog(@"Switching in Wil Shipley's Amazing Localizer Bundle. W00T!");
//        method_exchangeImplementations(class_getClassMethod(self, @selector(loadNibFile:externalNameTable:withZone:)), class_getClassMethod(self, @selector(deliciousLocalizingLoadNibFile:externalNameTable:withZone:)));
//    }
//    [autoreleasePool release];
//}


#pragma mark API

+ (BOOL)deliciousLocalizingLoadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone;
{
	NSLog(@"%s %@",__FUNCTION__, fileName);
	
	// Note: What about loading not from the main bundle? Can I try to load from where the nib file came from?
	
    NSString *localizedStringsTableName = [[fileName lastPathComponent] stringByDeletingPathExtension];
    NSString *localizedStringsTablePath = [[NSBundle mainBundle] pathForResource:localizedStringsTableName ofType:@"strings"];
    if (
//		YES ||
		localizedStringsTablePath
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"English.lproj"]
		&& ![[[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent] isEqualToString:@"en.lproj"]
		)
	{
        
        NSNib *nib = [[NSNib alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fileName]];
        NSMutableArray *topLevelObjectsArray = [context objectForKey:NSNibTopLevelObjects];
        if (!topLevelObjectsArray) {
            topLevelObjectsArray = [NSMutableArray array];
            context = [NSMutableDictionary dictionaryWithDictionary:context];
            [(NSMutableDictionary *)context setObject:topLevelObjectsArray forKey:NSNibTopLevelObjects];
        }
        BOOL success = [nib instantiateNibWithExternalNameTable:context];
		
		
		// Try to figure out bundle!
		NSBundle *itsBundle = [NSBundle mainBundle];
//		NSString *tryingPath = fileName;
//		do
//		{
//			itsBundle = [NSBundle bundleWithPath:tryingPath];
//			
//			NSLog(@"Trying %@ -> %@", tryingPath, itsBundle);
//			
//			tryingPath = [tryingPath stringByDeletingLastPathComponent];
//			
//		}
//		while (!itsBundle && [tryingPath length]);
		
		// Hmm, no, that doesn't really do it ... It's returning false positives, e.g. "Resources" directory of a bundle.
	
		
        [self _localizeStringsInObject:topLevelObjectsArray bundle:itsBundle table:localizedStringsTableName];		// BUNDLE?
        
        [nib release];
        return success;
        
    } else {
		
        if (localizedStringsTablePath)
		{
			NSLog(@"Not running through localizer because localizedStringsTablePath == nil");
		}
		else
		{
			NSLog(@"Not running through localizer because containing dir is not English: %@", [[localizedStringsTablePath stringByDeletingLastPathComponent] lastPathComponent]);
		}
		
		return [self deliciousLocalizingLoadNibFile:fileName externalNameTable:context withZone:zone];
    }
}



#pragma mark Private API

+ (void)_localizeStringsInObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table;
{
    if ([object isKindOfClass:[NSArray class]]) {
        NSArray *array = object;
        
        for (id nibItem in array)
            [self _localizeStringsInObject:nibItem bundle:bundle table:table];
        
    } else if ([object isKindOfClass:[NSCell class]]) {
        NSCell *cell = object;
        
        if ([cell isKindOfClass:[NSActionCell class]]) {
            NSActionCell *actionCell = (NSActionCell *)cell;
            
            if ([actionCell isKindOfClass:[NSButtonCell class]]) {
                NSButtonCell *buttonCell = (NSButtonCell *)actionCell;
                if ([buttonCell imagePosition] != NSImageOnly) {
                    [self _localizeTitleOfObject:buttonCell bundle:bundle table:table];
                    [self _localizeStringValueOfObject:buttonCell bundle:bundle table:table];
                    [self _localizeAlternateTitleOfObject:buttonCell bundle:bundle table:table];
                }
                
            } else if ([actionCell isKindOfClass:[NSTextFieldCell class]]) {
                NSTextFieldCell *textFieldCell = (NSTextFieldCell *)actionCell;
                // Following line is redundant with other code, localizes twice.
                // [self _localizeTitleOfObject:textFieldCell bundle:bundle table:table];
                [self _localizeStringValueOfObject:textFieldCell bundle:bundle table:table];
                [self _localizePlaceholderStringOfObject:textFieldCell bundle:bundle table:table];
                
            } else if ([actionCell type] == NSTextCellType) {
                [self _localizeTitleOfObject:actionCell bundle:bundle table:table];
                [self _localizeStringValueOfObject:actionCell bundle:bundle table:table];
            }
        }
        
    } else if ([object isKindOfClass:[NSMenu class]]) {
        NSMenu *menu = object;
        [self _localizeTitleOfObject:menu bundle:bundle table:table];
        
        [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table];
        
    } else if ([object isKindOfClass:[NSMenuItem class]]) {
        NSMenuItem *menuItem = object;
        [self _localizeTitleOfObject:menuItem bundle:bundle table:table];
        
        [self _localizeStringsInObject:[menuItem submenu] bundle:bundle table:table];
        
    } else if ([object isKindOfClass:[NSView class]]) {
        NSView *view = object;
        [self _localizeToolTipOfObject:view bundle:bundle table:table];
        
        if ([view isKindOfClass:[NSBox class]]) {
            NSBox *box = (NSBox *)view;
            [self _localizeTitleOfObject:box bundle:bundle table:table];
            
        } else if ([view isKindOfClass:[NSControl class]]) {
            NSControl *control = (NSControl *)view;
            
            if ([view isKindOfClass:[NSButton class]]) {
                NSButton *button = (NSButton *)control;
                
                if ([button isKindOfClass:[NSPopUpButton class]]) {
                    NSPopUpButton *popUpButton = (NSPopUpButton *)button;
                    NSMenu *menu = [popUpButton menu];
                    
                    [self _localizeStringsInObject:[menu itemArray] bundle:bundle table:table];
                } else
                    [self _localizeStringsInObject:[button cell] bundle:bundle table:table];
                
                
            } else if ([view isKindOfClass:[NSMatrix class]]) {
                NSMatrix *matrix = (NSMatrix *)control;
                
                NSArray *cells = [matrix cells];
                [self _localizeStringsInObject:cells bundle:bundle table:table];
                
                for (NSCell *cell in cells) {
                    
                    NSString *localizedCellToolTip = [self _localizedStringForString:[matrix toolTipForCell:cell] bundle:bundle table:table];
                    if (localizedCellToolTip)
                        [matrix setToolTip:localizedCellToolTip forCell:cell];
                }
                
            } else if ([view isKindOfClass:[NSSegmentedControl class]]) {
                NSSegmentedControl *segmentedControl = (NSSegmentedControl *)control;
                
                NSUInteger segmentIndex, segmentCount = [segmentedControl segmentCount];
                for (segmentIndex = 0; segmentIndex < segmentCount; segmentIndex++) {
                    NSString *localizedSegmentLabel = [self _localizedStringForString:[segmentedControl labelForSegment:segmentIndex] bundle:bundle table:table];
                    if (localizedSegmentLabel)
                        [segmentedControl setLabel:localizedSegmentLabel forSegment:segmentIndex];
                    
                    [self _localizeStringsInObject:[segmentedControl menuForSegment:segmentIndex] bundle:bundle table:table];
                }
                
            } else
                [self _localizeStringsInObject:[control cell] bundle:bundle table:table];
            
        }
        
        [self _localizeStringsInObject:[view subviews] bundle:bundle table:table];
        
    } else if ([object isKindOfClass:[NSWindow class]]) {
        NSWindow *window = object;
        [self _localizeTitleOfObject:window bundle:bundle table:table];
        
        [self _localizeStringsInObject:[window contentView] bundle:bundle table:table];
        
    }
}

+ (NSString *)_localizedStringForString:(NSString *)string bundle:(NSBundle *)bundle table:(NSString *)table;
{
    if (![string length])
        return nil;
    
    static NSString *defaultValue = @"I AM THE DEFAULT VALUE";
    NSString *localizedString = [bundle localizedStringForKey:string value:defaultValue table:table];
    if (localizedString != defaultValue) {
        return localizedString;
    } else { 
#ifdef DEBUG
        NSLog(@"        not going to localize string %@", string);
        return [string uppercaseString];
#else
        return string;
#endif
    }
}


#define DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(blahName, capitalizedBlahName) \
+ (void)_localize ##capitalizedBlahName ##OfObject:(id)object bundle:(NSBundle *)bundle table:(NSString *)table; \
{ \
NSString *localizedBlah = [self _localizedStringForString:[object blahName] bundle:bundle table:table]; \
if (localizedBlah) \
[object set ##capitalizedBlahName:localizedBlah]; \
}

DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(title, Title)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(alternateTitle, AlternateTitle)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(stringValue, StringValue)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(placeholderString, PlaceholderString)
DM_DEFINE_LOCALIZE_BLAH_OF_OBJECT(toolTip, ToolTip)

@end
