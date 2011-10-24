//
//  SVDOMController.h
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

//  
//  Sandvox's general class for other controllers to subclass.
//


#import "WEKWebEditorItem.h"
#import "WebEditingKit.h"

#import "SVContentObject.h"
#import "SVHTMLContext.h"

#import "KSDependenciesTracker.h"


@class SVWebEditorHTMLContext, KSObjectKeyPathPair, SVWebEditorViewController, SVGraphic, SVPlugInDOMController, SVElementInfo;


@interface SVDOMController : WEKWebEditorItem <KSDependenciesTrackerDelegate>
{
  @private
    // Loading
    BOOL            _shouldPublishElementID;
    SVElementInfo   *_elementInfo;
    
    // Updating
    NSMutableSet            *_updateSelectors;
    KSDependenciesTracker   *_dependenciesTracker;
    SVWebEditorHTMLContext  *_context;
    
    // MOC
    NSManagedObjectContext  *_moc;
    
    // Moving
    CGPoint _anchorPoint;
    BOOL    _moving;
    CGPoint _relativePosition;
    
    // Dragging
    NSArray *_dragTypes;
}

#pragma mark Hierarchy
- (WEKWebEditorItem *)itemForDOMNode:(DOMNode *)node;


#pragma mark DOM Element Loading

@property(nonatomic, retain) SVElementInfo *elementInfo;
@property(nonatomic) BOOL shouldIncludeElementIdNameWhenPublishing;

- (void)loadPlaceholderDOMElement;

@property(nonatomic, retain, readwrite) SVWebEditorHTMLContext *HTMLContext;


#pragma mark Updating

- (void)update;
- (void)writeUpdateHTML:(SVHTMLContext *)context;
- (void)willUpdateWithNewChildController:(WEKWebEditorItem *)newChildController;

- (BOOL)canUpdate;  // default is [self respondsToSelector:@selector(update)]
- (void)didUpdateWithSelector:(SEL)selector;    // you MUST call this after updating


#pragma mark Marking for Update

// If the receiver supports updating itself (-canUpdate), schedules an update with -setNeedsUpdateWithSelector:
// Otherwise, proceeds up the hierarchy looking for a controller that does support updating
- (void)setNeedsUpdate;

// Direct action to schedule a selector on next runloop pass
- (void)setNeedsUpdateWithSelector:(SEL)selector;

@property(nonatomic, readonly) BOOL needsUpdate;    // have any updates been registered?
- (BOOL)needsToUpdateWithSelector:(SEL)selector;    // has a specific selector been registered?

- (void)updateIfNeeded; // recurses down the tree


#pragma mark Generic Dependencies
@property(nonatomic, copy, readonly) NSSet *dependencies;
- (void)addDependency:(KSObjectKeyPathPair *)pair;
- (void)removeAllDependencies;
- (void)startObservingDependencies; // recursive
- (void)stopObservingDependencies;  // guaranteed to be called by -dealloc if needed


#pragma mark Content
// Automatically set from represented object is possible
// In general this is an ugly workaround for the problem of DOM controllers outliving their represented object's MOC. I think ideally the DOM Controller ought to observe an NSObjectController (or subclass) such that the MOC is handled there
@property(nonatomic, retain) NSManagedObjectContext *managedObjectContext;


#pragma mark Delete
// Attempts to hide the corresponding object, else passes action onto next responder
- (void)delete:(id)sender forwardingSelector:(SEL)action;


#pragma mark Editing
- (BOOL)shouldHighlightWhileEditing;


#pragma mark Moving

- (void)moveToPosition:(CGPoint)position;   // takes existing relative position into account

- (BOOL)hasRelativePosition;
- (void)setRelativePosition:(CGPoint)position;
- (void)removeRelativePosition:(BOOL)animated;

- (CGPoint)positionIgnoringRelativePosition;
- (NSRect)rectIgnoringRelativePosition;
- (NSArray *)relativePositionDOMElements;

@property(nonatomic) CGPoint anchorPoint;   // somewhat like Core Animation
- (CGPoint)anchorPointToGivePosition:(CGPoint)position;


#pragma mark Dragging
- (void)registerForDraggedTypes:(NSArray *)newTypes;
- (void)unregisterDraggedTypes;
- (NSArray *)registeredDraggedTypes;


@end


#pragma mark -


/*  We want all Web Editor items to be able to handle updating in some form, just not necessarily the full complexity of it.
*/

@interface WEKWebEditorItem (SVDOMController)

#pragma mark Tree
- (NSArray *)ancestorItems; // sorted with nearest ancestor first


#pragma mark Updating
- (SVWebEditorViewController *)webEditorViewController;
- (void)setNeedsUpdate; // pass up to parent
- (void)updateIfNeeded; // recurses down the tree
- (SVWebEditorHTMLContext *)HTMLContext;


#pragma mark Dependencies
- (BOOL)isObservingDependencies;
- (void)startObservingDependencies; // recursive
- (void)stopObservingDependencies;  // recursive


#pragma mark Moving in Article

// Default implementation doesn't know how to handle the move, so passes on, asking parent to move itself. Generally item should be a child
- (void)moveItemUp:(WEKWebEditorItem *)item;
- (void)moveItemDown:(WEKWebEditorItem *)item;

// Ask parent to move receiver
- (void)moveUp;
- (void)moveDown;


#pragma mark Drag & Drop
- (NSArray *)registeredDraggedTypes;


@end


#pragma mark -


@interface WEKDOMController (SVDOMController)

- (DOMNode *)previousDOMNode;
- (DOMNode *)nextDOMNode;


#pragma mark Moving
- (void)exchangeWithPreviousDOMNode;
- (void)exchangeWithNextDOMNode;


@end

