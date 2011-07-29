//
//  WEKDOMController.h
//  Sandvox
//
//  Created by Mike on 24/11/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@class WEKDOMEventListener;


@interface WEKDOMController : NSResponder
{
  @private
    // DOM
    DOMHTMLElement      *_DOMElement;
    WEKDOMEventListener  *_eventListener;
    
    // Content
    id              _representedObject;
    
    // Loading by creation
    NSString    *_elementID;
    DOMNode     *_node;
}

#pragma mark Init

// For subclasses that know how to load HTML element from within an existing node
// Pass in a DOMDocument or subclass to improve speed of searching the DOM for your element
- (id)initWithElementIdName:(NSString *)elementID ancestorNode:(DOMNode *)node;

// Convenience method:
- (id)initWithHTMLElement:(DOMHTMLElement *)element;


#pragma mark DOM

// Unlike NSViewController it's generally OK for a DOM Controller to have no HTMLElement. This is because they may need to be created before the DOM has loaded. It might be good to have an init method that does demand element be created though.
@property(nonatomic, retain) DOMHTMLElement *HTMLElement;
- (void)loadHTMLElement;
- (BOOL)isHTMLElementLoaded;

@property(nonatomic, copy) NSString *elementIdName;
@property(nonatomic, retain, readonly) DOMNode *node;
@property(nonatomic, retain, readonly) DOMHTMLDocument *HTMLDocument;

- (DOMRange *)DOMRange; // returns -HTMLElement as a range

#pragma mark Events

//  Somewhat problematically, the DOM will retain any event listeners added to it. This can quite easily leave a DOM controller and its HTML element in a retain cycle. When the DOM is torn down, it somehow releases the listener repeatedly, causing a crash.
//  The best solution I can come up with is to avoid the retain cycle between listener and DOM by creating a simple proxy to listen to events and forward them on to the real target, but not retain either object. That object is automatically managed for you and returned here.
@property(nonatomic, retain, readonly) id <DOMEventListener> eventsListener;


#pragma mark Content
@property(nonatomic, retain) id representedObject;


@end
