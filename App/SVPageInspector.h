//
//  SVPageInspector.h
//  Sandvox
//
//  Created by Mike on 06/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KSInspectorViewController.h"


@class KTPlaceholderBindingTextField, SVSidebarPageletsController;


@interface SVPageInspector : KSInspectorViewController
{
    IBOutlet KTPlaceholderBindingTextField  *oMenuTitleField;
    
    IBOutlet NSButton *showTimestampCheckbox;
    
    IBOutlet SVSidebarPageletsController    *oSidebarPageletsController;
}

- (IBAction)selectTimestampType:(NSPopUpButton *)sender;

@end
