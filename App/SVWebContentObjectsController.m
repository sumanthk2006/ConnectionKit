//
//  SVWebContentObjectsController.m
//  Sandvox
//
//  Created by Mike on 06/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentObjectsController.h"

#import "SVRichText.h"
#import "SVLogoImage.h"
#import "KTPage.h"
#import "SVSidebar.h"
#import "SVSidebarPageletsController.h"
#import "SVTitleBox.h"
#import "SVTextBox.h"


@interface SVWebContentObjectsController ()
- (void)synchronizeSidebarPageletsController;
@end


@implementation SVWebContentObjectsController

- (void)dealloc
{
    [_page release];
    [super dealloc];
}

- (SVGraphic *)newPagelet;
{
    NSManagedObjectContext *moc = [[self page] managedObjectContext];
    SVTextBox *result = [SVTextBox insertNewTextBoxIntoManagedObjectContext:moc];
	OBASSERT(result);
    
    // Create matching first paragraph
    [[result body] setString:@"<p>Test</p>"];
    
    
    return [result retain]; // it's a -newFoo method
}

@synthesize page = _page;
- (void)setPage:(KTPage *)page
{
    if (page != _page)
    {
        [_page release]; _page = [page retain];
        
        // Generate new sidebar controller
        [_sidebarPageletsController release]; _sidebarPageletsController = nil;
        if (page)
        {
            _sidebarPageletsController = [[SVSidebarPageletsController alloc] initWithSidebar:[page sidebar]];
            [self synchronizeSidebarPageletsController];
        }
    }
}

- (void)didChangeSelection
{
    [self synchronizeSidebarPageletsController];
}

- (void)willRemoveObject:(id)object;
{
    [super willRemoveObject:object];
    
    if ([object isKindOfClass:[SVGraphic class]])
    {
        // Remove pagelet from sidebar/callout. Delete if appropriate
        // If it is in the sidebar, the corresponding controller can take care of the matter. Otherwise, it's up to us
        if ([[[self sidebarPageletsController] arrangedObjects] containsObject:object])
        {
            [[self sidebarPageletsController] removeObject:object];
        }
        else if ([object isKindOfClass:[SVLogoImage class]])
        {
            [(SVLogoImage *)object setHidden:[NSNumber numberWithBool:YES]];
        }
        else
        {
            SVGraphic *pagelet = object;
            
            // Remove from callout, and delete that if it's now empty
            if ([[pagelet sidebars] count] == 0)
            {
                [[pagelet managedObjectContext] deleteObject:pagelet];
            }
        }
    }
    else if ([object isKindOfClass:[SVTitleBox class]])
    {
        [(SVTitleBox *)object setHidden:[NSNumber numberWithBool:YES]];
    }
}

#pragma mark Sidebar Pagelets

- (BOOL)sidebarPageletAppearsOnAncestorPage:(SVGraphic *)pagelet;
{
    BOOL result = NO;
    
    // Search up the tree from our page to see if any of them contain the pagelet
    KTPage *page = [[self page] parentPage];
    while (page)
    {
        if ([[[page sidebar] pagelets] containsObject:pagelet])
        {
            result = YES;
            break;
        }
        page = [page parentPage];
    }
    
    return result;
}

@synthesize sidebarPageletsController = _sidebarPageletsController;

- (void)synchronizeSidebarPageletsController
{
    NSArrayController *controller = [self sidebarPageletsController];
    [controller setSelectedObjects:[self selectedObjects]];
}

#pragma mark Support

- (BOOL)setSelectedObjects:(NSArray *)objects
{
    BOOL result = [super setSelectedObjects:objects];
    if (result) [self didChangeSelection];
    return result;
}

- (BOOL)selectObjectByInsertingIfNeeded:(id)object;
{
    BOOL result = [self setSelectedObjects:[NSArray arrayWithObject:object]];
    if ([[self selectedObjects] count] == 0)
    {
        [self addObject:object];
        if (![self selectsInsertedObjects]) result = [self selectObjectByInsertingIfNeeded:object];
    }
    
    return result;
}

@end
