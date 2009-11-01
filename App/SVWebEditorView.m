//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"
#import "SVWebEditorWebView.h"
#import "SVSelectionBorder.h"

#import "SVDocWindow.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSWorkspace+Karelia.h"


NSString *SVWebEditorViewSelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditorView () <SVWebEditorWebUIDelegate>

@property(nonatomic, retain, readonly) SVWebEditorWebView *webView; // publicly declared as a plain WebView, but we know better


// Selection
- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification;

- (void)updateSelectionByDeselectingAll:(BOOL)deselectAll
                         orDeselectItem:(id <SVWebEditorItem>)itemToDeselect
                            selectItems:(NSArray *)itemsToSelect
                          updateWebView:(BOOL)updateWebView;

@property(nonatomic, copy) NSArray *selectionParentItems;


// Getting Item Information
- (NSArray *)ancestorsForItem:(id <SVWebEditorItem>)item includeItem:(BOOL)includeItem;


// Event handling
- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector;

@end


#pragma mark -


@implementation SVWebEditorView

#pragma mark Initialization & Deallocation

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _selectedItems = [[NSMutableArray alloc] init];
    
    
    // WebView
    _webView = [[SVWebEditorWebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    [_webView setFrameLoadDelegate:self];
    [_webView setPolicyDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setEditingDelegate:self];
    
    [self addSubview:_webView];
    
    
    // Tracking area
    NSTrackingAreaOptions options = (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect);
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                options:options
                                                                  owner:self
                                                               userInfo:nil];
    
    [self addTrackingArea:trackingArea];
    [trackingArea release];
    
    
    return self;
}

- (void)viewDidMoveToWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidChangeFirstResponder:)
                                                     name:SVDocWindowDidChangeFirstResponderNotification
                                                   object:[self window]];
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:SVDocWindowDidChangeFirstResponderNotification
                                                      object:[self window]];
    }
}

- (void)dealloc
{
    [_webView setFrameLoadDelegate:nil];
    [_webView setPolicyDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView setEditingDelegate:nil];
    
    [_selectedItems release];
    [_webView release];
        
    [super dealloc];
}

#pragma mark Document

@synthesize webView = _webView;

- (DOMDocument *)DOMDocument { return [[self webView] mainFrameDocument]; }

#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
{
    _isLoading = YES;
    [[[self webView] mainFrame] loadHTMLString:string baseURL:URL];
    _isLoading = NO;
}

- (BOOL)loadUntilDate:(NSDate *)date;
{
    BOOL result = NO;
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!result && [date timeIntervalSinceNow] > 0)
    {
        [runLoop runUntilDate:[NSDate distantPast]];
        result = ![self isLoading];
    }
    
    return result;
}

@synthesize loading = _isLoading;

#pragma mark Selected DOM Range

- (DOMRange *)selectedDOMRange { return [[self webView] selectedDOMRange]; }

#pragma mark Text Selection

@synthesize focusedText = _focusedText;

// Notification is optional as it's just a nicety to pass onto text object
- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification
{
    // Ignore identical text as it would send unwanted editing messages to the text in question
    if (text == _focusedText) return;
    
    // Let the old text know it's done
    [[self focusedText] webEditorTextDidEndEditing:notification];
    [[self undoManager] removeAllActions];
    
    // Store the new text
    [_focusedText release], _focusedText = [text retain];
}

#pragma mark Selected Items

@synthesize selectedItems = _selectedItems;
- (void)setSelectedItems:(NSArray *)items
{
    [self selectItems:items byExtendingSelection:NO];
}

- (id <SVWebEditorItem>)selectedItem
{
    return [[self selectedItems] lastObject];
}

- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
{
    [self updateSelectionByDeselectingAll:!extendSelection
                           orDeselectItem:nil
                              selectItems:items
                            updateWebView:YES];
}

- (void)deselectItem:(id <SVWebEditorItem>)item;
{
    [self updateSelectionByDeselectingAll:NO
                           orDeselectItem:item
                              selectItems:nil
                            updateWebView:YES];
}

- (IBAction)deselectAll:(id)sender;
{
    [self setSelectedItems:nil];
}

/*  Support method to do the real work of all our selection methods
 */
- (void)updateSelectionByDeselectingAll:(BOOL)deselectAll
                         orDeselectItem:(id <SVWebEditorItem>)itemToDeselect
                            selectItems:(NSArray *)itemsToSelect
                          updateWebView:(BOOL)updateWebView;
{
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    SVSelectionBorder *border = [[[SVSelectionBorder alloc] init] autorelease];
    
    
    
    // Bracket the whole operation so no-one else gets the wrong idea
    OBPRECONDITION(_isChangingSelectedItems == NO);
    _isChangingSelectedItems = YES;
    
    
    
    // Remove items, including marking them for display. Could almost certainly be more efficient
    NSArray *itemsToDeselect = nil;
    if (deselectAll)
    {
        itemsToDeselect = [self selectedItems];
    }
    else if (itemToDeselect)
    {
        itemsToDeselect = [NSArray arrayWithObject:itemToDeselect];
    }
    
    if (itemsToDeselect)
    {
        for (id <SVWebEditorItem> anItem in itemsToDeselect)
        {
            NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
            [docView setNeedsDisplayInRect:drawingRect];
        }
        
        NSMutableArray *selection = [_selectedItems mutableCopy];
        [selection removeObjectsInArray:itemsToDeselect];
        [_selectedItems release], _selectedItems = selection;
    }
    
    
    
    // Add new items to the selection.
    if (itemsToSelect)
    {
        // Store them. Odd looking logic I know, but should handle edge cases like _selectedItems being nil
        [_selectedItems autorelease];
        _selectedItems = (_selectedItems ?
                          [[_selectedItems arrayByAddingObjectsFromArray:itemsToSelect] retain] :
                          [itemsToSelect copy]);
        
        // Draw new selection
        for (id <SVWebEditorItem> anItem in itemsToSelect)
        {
            NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
            [docView setNeedsDisplayInRect:drawingRect];
        }
    }
    
    
    
    // Update WebView selection to match. Selecting the node would be ideal, but WebKit ignores us if it's not in an editable area
    id <SVWebEditorItem> selectedItem = [self selectedItem];
    if (updateWebView && selectedItem)
    {
        DOMElement *domElement = [selectedItem DOMElement];
        if ([domElement containingContentEditableElement])
        {
            [[self window] makeFirstResponder:[domElement documentView]];
            
            DOMRange *range = [[domElement ownerDocument] createRange];
            [range selectNode:domElement];
            [[self webView] setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
        }
        else
        {
            [[self window] makeFirstResponder:self];
        }
    }
    
    
    
    // Update parentItems list
    NSArray *parentItems = nil;
    if (selectedItem)
    {
        parentItems = [self ancestorsForItem:selectedItem includeItem:NO];
    }
    else
    {
        DOMNode *selectionNode = [[self selectedDOMRange] commonAncestorContainer];
        if (selectionNode)
        {
            id <SVWebEditorItem> parent = [self itemForDOMNode:selectionNode];
            if (parent)
            {
                parentItems = [self ancestorsForItem:parent includeItem:YES];
            }
        }
    }
    
    [self setSelectionParentItems:parentItems];
    
    
    
    // Finish bracketing
    _isChangingSelectedItems = NO;
    
    
    
    // Alert observers
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewSelectionDidChangeNotification
                                                        object:self];
}

- (SVSelectionBorder *)selectionBorderAtPoint:(NSPoint)point;
{
    SVSelectionBorder *result = nil;
    
    // TODO: Re-enable this method
    /*
    CGPoint cgPoint = [self convertPointToContent:point];
    
    for (SVSelectionBorder *aLayer in [self selectionBorders])
    {
        if ([aLayer hitTest:cgPoint])
        {
            result = aLayer;
            break;
        }
    }
    */
    return result;
}

@synthesize selectionParentItems = _selectionParentItems;
- (void)setSelectionParentItems:(NSArray *)items
{
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    
    // Mark old as needing display
    [border setEditing:YES];
    for (id <SVWebEditorItem> anItem in [self selectionParentItems])
    {
        NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
        [docView setNeedsDisplayInRect:drawingRect];
    }
    
    // Store items
    items = [items copy];
    [_selectionParentItems release]; _selectionParentItems = items;
    
    // Draw new items
    for (id <SVWebEditorItem> anItem in items)
    {
        NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
        [docView setNeedsDisplayInRect:drawingRect];
    }
    
    [border release];
}

- (void)windowDidChangeFirstResponder:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self window]);
}

#pragma mark Editing

- (BOOL)canEditText;
{
    //  Editing is only supported while the WebView is First Responder. Otherwise there is no selection to indicate what is being edited. We can work around the issue a bit by forcing there to be a selection, or refusing the edit if not
    BOOL result = [[self webView] isFirstResponder];
    if (!result)
    {
        result = [[self window] makeFirstResponder:[self webView]];
    }
    return result;
}

- (void)willEditTextInDOMRange:(DOMRange *)range
{
    // Record the range ready for a -didChange notification
    OBASSERT(!_DOMRangeOfNextEdit);
    _DOMRangeOfNextEdit = [range retain];
}

- (void)didChangeTextInDOMRange:(DOMRange *)range notification:(NSNotification *)notification;
{
    OBPRECONDITION(range);
    
    // Alert the corresponding Text object that it did change
    id <SVWebEditorText> text = [[self dataSource] webEditorView:self
                                            textBlockForDOMRange:range];
    [text webEditorTextDidChange:notification];
}

#pragma mark Undo Support

- (NSUndoManager *)undoManager
{
    if (!_undoManager)
    {
        _undoManager = [[NSUndoManager alloc] init];
    }
    return _undoManager;
}

/*  This is pretty sucky: There are -undo: and -redo: actions for menu items but they are not documented anywhere. Since we're using a custom undo manager, need to implement these methods ourself
 */

- (void)undo:(id)sender
{
    [[self undoManager] undo];
}

- (void)redo:(id)sender
{
    [[self undoManager] redo];
}

/*  Covers for prviate WebKit methods
 */

- (BOOL)allowsUndo { return [(NSTextView *)[self webView] allowsUndo]; }
- (void)setAllowsUndo:(BOOL)undo { [(NSTextView *)[self webView] setAllowsUndo:undo]; }

- (void)removeAllUndoActions
{
    [[self webView] performSelector:@selector(_clearUndoRedoOperations)];
}

#pragma mark Cut, Copy & Paste

- (void)cut:(id)sender
{
    if ([self copySelectedItemsToGeneralPasteboard])
    {
        [self delete:sender];
    }
}

- (void)copy:(id)sender
{
    [self copySelectedItemsToGeneralPasteboard];
}

- (BOOL)copySelectedItemsToGeneralPasteboard;
{
    // Rely on the datasource to serialize items to the pasteboard
    BOOL result = [[self dataSource] webEditorView:self 
                                        writeItems:[self selectedItems]
                                      toPasteboard:[NSPasteboard generalPasteboard]];
    if (!result) NSBeep();
    
    return result;
}

- (void)delete:(id)sender;
{
    if (![[self dataSource] webEditorView:self deleteItems:[self selectedItems]])
    {
        NSBeep();
    }
}

#pragma mark Getting Item Information

/*  What item would be selected if you click at that point?
 */
- (id <SVWebEditorItem>)itemAtPoint:(NSPoint)point;
{
    id <SVWebEditorItem> result = nil;
    
    NSDictionary *element = [[self webView] elementAtPoint:point];
    DOMNode *domNode = [element objectForKey:WebElementDOMNodeKey];
    if (domNode)
    {
        result = [self itemForDOMNode:domNode];
    }
    
    return result;
}

- (id <SVWebEditorItem>)itemForDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    
    // Figure out deepest item
    NSArray *items = [[self dataSource] webEditorView:self childrenOfItem:nil];
    id <SVWebEditorItem> result = [self itemForDOMNode:node inItems:items];
    
    
    // Then work our way up the tree looking for the highest-level object that isn't in the parents list
    while (result)
    {
        id <SVWebEditorItem> parent = [self parentForItem:result];
        if (parent && ![[self selectionParentItems] containsObject:parent])
        {
            result = parent;
        }
        else
        {
            break;
        }
    }
    
    return result;
}

- (NSArray *)itemsInDOMRange:(DOMRange *)range
{
    NSMutableArray *result = [NSMutableArray array];
    NSArray *items = [[self dataSource] webEditorView:self childrenOfItem:nil];
    
    for (id <SVWebEditorItem> anItem in items)
    {
        if ([range containsNode:[anItem DOMElement]])
        {
            [result addObject:anItem];
        }
    }
    
    return result;
}

- (id <SVWebEditorItem>)parentForItem:(id <SVWebEditorItem>)item;
{
    OBPRECONDITION(item);
    
    // Pretty simple actually; just search up the DOM again
    DOMNode *parentNode = [[item DOMElement] parentNode];
    id <SVWebEditorItem> result = [self itemForDOMNode:parentNode];
    return result;
}

- (NSArray *)ancestorsForItem:(id <SVWebEditorItem>)item includeItem:(BOOL)includeItem;
{
    OBPRECONDITION(item);
    
    NSArray *result = (includeItem ? [NSArray arrayWithObject:item] : nil);
    
    id <SVWebEditorItem> parent = item;
    while (parent)
    {
        parent = [self parentForItem:parent];
        if (parent)
        {
            if (result)
            {
                result = [result arrayByAddingObject:parent];
            }
            else
            {
                result = [NSArray arrayWithObject:parent];
            }
        }
    }
    
    return result;
}

- (id <SVWebEditorItem>)itemForDOMNode:(DOMNode *)node inItems:(NSArray *)items;
{
    id <SVWebEditorItem> result = nil;
    NSArray *itemDOMElements = [items valueForKey:@"DOMElement"];
    
    DOMNode *aNode = node;
    while (aNode)
    {
        NSUInteger index = [itemDOMElements indexOfObjectIdenticalTo:aNode];
        if (index != NSNotFound)
        {
            result = [items objectAtIndex:index];
            break;
        }
        aNode = [aNode parentNode];
    }
    
    return result;
}

#pragma mark Drawing

- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view
{
    // Draw drop highlight if there is one. 3px inset from bounding box, "Aqua" colour
    if (_dragHighlightNode)
    {
        NSRect dropRect = [_dragHighlightNode boundingBox];
        
        [[NSColor aquaColor] setFill];
        NSFrameRectWithWidth(dropRect, 3.0f);
    }
    
    
    // Draw selection
    [self drawSelectionRect:dirtyRect inView:view];
    
    // Draw drag caret
    [self drawDragCaretInView:view];
}

- (void)drawSelectionRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    
    // Draw selection parent items
    for (id <SVWebEditorItem> anItem in [self selectionParentItems])
    {
        // Draw the item if it's in the dirty rect (otherwise drawing can get pretty pricey)
        [border setEditing:YES];
        NSRect frameRect = [[anItem DOMElement] boundingBox];
        NSRect drawingRect = [border drawingRectForFrame:frameRect];
        if (NSIntersectsRect(drawingRect, dirtyRect))
        {
            [border drawWithFrame:frameRect inView:view];
        }
    }
    
    // Draw actual selection
    [border setEditing:NO];
    for (id <SVWebEditorItem> anItem in [self selectedItems])
    {
        // Draw the item if it's in the dirty rect (otherwise drawing can get pretty pricey)
        NSRect frameRect = [[anItem DOMElement] boundingBox];
        NSRect drawingRect = [border drawingRectForFrame:frameRect];
        if (NSIntersectsRect(drawingRect, dirtyRect))
        {
            [border drawWithFrame:frameRect inView:view];
        }
    }
    
    // Tidy up
    [border release];
}

#pragma mark Event Handling

/*  AppKit uses hit-testing to drill down into the view hierarchy and figure out just which view it needs to target with a mouse event. We can exploit this to effectively "hide" some portions of the webview from the standard event handling mechanisms; all such events will come straight to us instead. We have 2 different behaviours depending on current mode:
 *
 *      1)  Usually, any portion of the webview designated as "selectable" (e.g. pagelets) overrides hit-testing so that clicking selects them rather than the standard WebKit behaviour.
 *
 *      2)  But with -isEditingSelection set to YES, the role is flipped. The user has scoped in on the selected portion of the webview. They have normal access to that, but everything else we need to take control of so that clicking outside the box ends editing.
 */
- (NSView *)hitTest:(NSPoint)aPoint
{
    // First off, we'll only consider special behaviour if targeting the document
    NSView *result = [super hitTest:aPoint];
    if ([result isDescendantOf:[[[[self webView] mainFrame] frameView] documentView]])
    {
        NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
        
        // Normally, we want to target self if there's an item at that point but not if the item is the parent of a selected item.
        id <SVWebEditorItem> item = [self itemAtPoint:point];
        if (item)
        {
            if (![[self selectionParentItems] containsObject:item])
            {
                result = self;
            }
        }
        else if ([[self selectionParentItems] count] > 0)
        {
            result = self;
        }
    }
    
    
    
    
    
    //NSLog(@"Hit Test: %@", result);
    return result;
}

- (void)keyDown:(NSEvent *)theEvent
{
    // Interpret delete keys specially, otherwise ignore key events
    if ([theEvent isDeleteKeyEvent])
    {
        [self delete:self];
    }
    else
    {
        [super keyDown:theEvent];
    }
}

- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector
{
    // If content also decides it's not interested in the event, we will be given it again as part of the responder chain. So, keep track of whether we're processing and ignore the event in such cases.
    if (_isProcessingEvent)
    {
        [super scrollWheel:theEvent];
    }
    else
    {
        NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSView *targetView = [[self webView] hitTest:location];
        
        _isProcessingEvent = YES;
        [targetView performSelector:selector withObject:theEvent];
        _isProcessingEvent = NO;
    }
}

#pragma mark Tracking the Mouse

/*  Actions we could take from this:
 *      - Deselect everything
 *      - Change selection to new item
 *      - Start editing selected item (actually happens upon -mouseUp:)
 *      - Add to the selection
 */
- (void)mouseDown:(NSEvent *)event
{
    // Store the event for a bit (for draging, editing, etc.). Note that we're not interested in it while editing
    OBASSERT(!_mouseDownEvent);
    _mouseDownEvent = [event retain];
    
    
    
    
    // What was clicked? We want to know top-level object
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    id <SVWebEditorItem> item = [self itemAtPoint:location];
      
    if (item)
    {
        BOOL itemIsSelected = [[self selectedItems] containsObjectIdenticalTo:item];
        
        // Depending on the command key, add/remove from the selection, or become the selection
        if ([event modifierFlags] & NSCommandKeyMask)
        {
            if (itemIsSelected)
            {
                [self deselectItem:item];
            }
            else
            {
                [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:YES];
            }
        }
        else
        {
            [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO];
            
            if (itemIsSelected)
            {
                // If you click an aready selected item quick enough, it will start editing
                _mouseUpMayBeginEditing = YES;
            }
        }
    }
    else
    {
        // If editing inside an item, the click needs to go straight through to the WebView; we were just claiming ownership of that area in order to gain control of the cursor
        if ([[self selectionParentItems] count] > 0)
        {
            [self setSelectionParentItems:nil];
            [_mouseDownEvent release]; _mouseDownEvent = nil;
            [NSApp sendEvent:event];    // this time round it'll go through to the WebView
            return;
        }
        else
        {
            // Don't really expect to hit this point. Since if there is no item at the location, we should never have hit-tested positively in the first place
            [super mouseDown:event];
        }
    }
}

- (void)mouseUp:(NSEvent *)mouseUpEvent
{
    if (_mouseDownEvent)
    {
        NSEvent *mouseDownEvent = [_mouseDownEvent retain];
        [_mouseDownEvent release],  _mouseDownEvent = nil;
        
        
        if (_mouseUpMayBeginEditing && [[self selectedItem] isEditable])
        {
            // Was the mouse up quick enough to start editing? If so, it's time to hand off to the webview for editing.
            if ([mouseUpEvent timestamp] - [mouseDownEvent timestamp] < 0.5)
            {
                // Repost equivalent events so they go to their correct target. Can't call -sendEvent: as that doesn't update -currentEvent
                // Note that they're posted in reverse order since I'm placing onto the front of the queue.
                // To stop the events being repeatedly posted back to ourself, have to indicate to -hitTest: that it should target the WebView. This can best be done by switching selected item over to editing
                [self setSelectionParentItems:[self selectedItems]];    // should only be 1
                
                [NSApp postEvent:[mouseUpEvent eventWithClickCount:1] atStart:YES];
                [NSApp postEvent:[mouseDownEvent eventWithClickCount:1] atStart:YES];
            }
        }
        
        
        // Tidy up
        [mouseDownEvent release];
        _mouseUpMayBeginEditing = NO;
    }
}

// -mouseDragged: is over in the Dragging category

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events, let content have a crack at them.
    [self forwardMouseEvent:theEvent selector:_cmd];
}

#pragma mark Changing the First Responder

- (BOOL)resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if (result && !_isChangingSelectedItems)
    {
        [self setSelectedItems:nil];
    }
    return result;
}

#pragma mark Setting the DataSource/Delegate

@synthesize dataSource = _dataSource;

@synthesize delegate = _delegate;

#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    SEL action = [anItem action];
    
    if (action == @selector(undo:))
    {
        result = [[self undoManager] canUndo];
    }
    else if (action == @selector(redo:))
    {
        result = [[self undoManager] canRedo];
    }
    
    // You can cut or copy as long as there is a suggestion (just hope the datasource comes through for us!)
    else if (action == @selector(cut:) || action == @selector(copy:))
    {
        result = ([[self selectedItems] count] >= 1);
    }
    
    return result;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    //  And here I am forced to lie a bit to the undo manager. If we're not in the middle of editing, we want undo messages to be handled by the window as usual. Easiest way is just to claim we don't respond.
    BOOL result;
    if (aSelector == @selector(undo:))
    {
        result = [[self undoManager] canUndo];
    }
    else if (aSelector == @selector(redo:))
    {
        result = [[self undoManager] canRedo];
    }
    else
    {
        result = [super respondsToSelector:aSelector];
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVWebEditorView (WebDelegates)

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorViewDidFinishLoading:self];
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorView:self didReceiveTitle:title];
    }
}

#pragma mark WebPolicyDelegate

/*	We don't want to allow navigation within Sandvox! Open in web browser instead
 */
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id <WebPolicyDecisionListener>)listener
{
	// Open the URL in the user's web browser
	[listener ignore];
	
	NSURL *URL = [request URL];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
}

/*  We don't allow navigation, but our delegate may then decide to
 */
- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
    if ([self isLoading])
    {
        // We want to allow initial loading of the webview…
        [listener use];
    }
    else
    {
        // …but after that navigation is undesireable
        [listener ignore];
        [[self delegate] webEditorView:self handleNavigationAction:actionInformation request:request];
    }
}

#pragma mark WebUIDelegate

/*  Generally the only drop action we support is for text editing. BUT, for an area of the WebView which our datasource has claimed for its own, need to dissallow all actions
 */
- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)dragInfo
{
    NSUInteger result = WebDragDestinationActionEdit;
    
    if ([[self dataSource] webEditorView:self dataSourceShouldHandleDrop:dragInfo])
    {
        result = WebDragDestinationActionNone;
    }
    
    return result;
}

#pragma mark WebUIDelegatePrivate

/*  Log javacript to the standard console; it may be helpful for us or for people who put javascript into their stuff.
 *  Hint originally from: http://lists.apple.com/archives/webkitsdk-dev/2006/Apr/msg00018.html
 */
- (void)webView:(WebView *)sender addMessageToConsole:(NSDictionary *)aDict
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"LogJavaScript"])
	{
		NSString *message = [aDict objectForKey:@"message"];
		NSString *lineNumber = [aDict objectForKey:@"lineNumber"];
		if (!lineNumber) lineNumber = @""; else lineNumber = [NSString stringWithFormat:@" line %@", lineNumber];
		// NSString *sourceURL = [aDict objectForKey:@"sourceURL"]; // not that useful, it's an applewebdata
		NSLog(@"JavaScript%@> %@", lineNumber, message);
	}
}

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyRect
{
    NSView *drawingView = [NSView focusView];
    NSRect dirtyDrawingRect = [drawingView convertRect:dirtyRect fromView:sender];
    [self drawOverlayRect:dirtyDrawingRect inView:drawingView];
}

#pragma mark WebEditingDelegate

- (BOOL)webView:(WebView *)webView shouldBeginEditingInDOMRange:(DOMRange *)range
{
    id <SVWebEditorText> text = [[self dataSource] webEditorView:self
                                            textBlockForDOMRange:range];
    [self setFocusedText:text notification:nil];
    
    return YES;
}

- (BOOL)webView:(WebView *)webView shouldDeleteDOMRange:(DOMRange *)range
{
    [self willEditTextInDOMRange:range];
    return YES;
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
    if (result)
    {
        id <SVWebEditorText> text = [[self dataSource] webEditorView:self textBlockForDOMRange:range];
        
        // Let the text object decide
        NSPasteboard *pasteboard = nil;
        if ([webView respondsToSelector:@selector(_insertionPasteboard)])
        {
            pasteboard = [webView performSelector:@selector(_insertionPasteboard)];
        }
        
        result = [text webEditorTextShouldInsertNode:node
                                        replacingDOMRange:range
                                              givenAction:action
                                               pasteboard:pasteboard];
        
        if (result)
        {
            [self willEditTextInDOMRange:range];
        }
    }
    
    return result;
}

- (BOOL)webView:(WebView *)webView shouldInsertText:(NSString *)string replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
    if (result)
    {
        id <SVWebEditorText> text = [[self dataSource] webEditorView:self textBlockForDOMRange:range];
        
        // Let the text object decide
        NSPasteboard *pasteboard = nil;
        if ([webView respondsToSelector:@selector(_insertionPasteboard)])
        {
            pasteboard = [webView performSelector:@selector(_insertionPasteboard)];
        }
        
        result = [text webEditorTextShouldInsertText:string
                                   replacingDOMRange:range
                                         givenAction:action
                                          pasteboard:pasteboard];
        
        if (result)
        {
            [self willEditTextInDOMRange:range];
        }
    }
    
    return result;
}

/*  The WebView sends this message whenever its content changes. Unfortunately, there is no way to know what part of the DOM changed, so we are left guessing who to send this message to. The best workaround I can think of is to trap what part of the DOM will be edited and use that.
 */
- (void)webViewDidChange:(NSNotification *)notification
{
    // During undo operations, there's no indication that a change is about to be made, only a -didChange message. I'm going to ignore such messages as I'm not sure clients are interested
    if (_DOMRangeOfNextEdit)
    {
        DOMRange *range = _DOMRangeOfNextEdit;
        _DOMRangeOfNextEdit = nil;  // I'm trying to force this back to nil asap as it's a bit of a hack
        
        [self didChangeTextInDOMRange:range notification:notification];
        [range release];
    }
    else
    {
        NSUndoManager *undoManager = [[self webView] undoManager];
        if (![undoManager isUndoing] && ![undoManager isRedoing])
        {
            OBASSERT_NOT_REACHED("No DOMRange recorded for edit");
        }
    }
}

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self webView]);
    
    //  Update -selectedItems to match. Make sure not to try and change the WebView's selection in turn or it'll all end in tears. It doesn't make sense to bother doing this if the selection change was initiated by ourself.
    if (!_isChangingSelectedItems)
    {
        DOMRange *range = [[self webView] selectedDOMRange];
        NSArray *items = nil;
        if (range)
        {
            items = [self itemsInDOMRange:range];
        }
        
        [self updateSelectionByDeselectingAll:YES
                               orDeselectItem:nil
                                  selectItems:nil
                                updateWebView:YES];
    }
}

- (void)webViewDidEndEditing:(NSNotification *)notification
{
    [self setFocusedText:nil notification:notification];
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)command
{
    BOOL result = [_focusedText doCommandBySelector:command];
    return result;
}

@end


/*  SEP - Somebody Else's Problem
*/