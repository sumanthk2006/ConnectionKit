//
//  KTAbstractPluginDelegate.h
//  Sandvox
//
//  Copyright (c) 2005-2008, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
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

#import <Cocoa/Cocoa.h>
#import "KTAbstractElement.h"

// this class essentially defines an informal plugin delegatae protocol

@class KTDocument;

@interface KTAbstractPluginDelegate : NSObject
{
	KTAbstractElement *myDelegateOwner; // should be a subclass of KTAbstractElement
}

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject;
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary;

#pragma mark Validation

- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError;

#pragma mark accessors

- (id)delegateOwner;
- (void)setDelegateOwner:(id)anObject; // sets only a weak reference
- (KTPage *)page;

// these are covers for the same accessors in myDelegateOwner
- (NSBundle *)bundle;

- (KTMediaManager *)mediaManager;
- (NSUndoManager *)undoManager;

@end
