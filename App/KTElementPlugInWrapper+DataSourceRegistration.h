//
//  KTElementPlugInWrapper+DataSourceRegistration.h
//  Marvel
//
//  Created by Mike on 16/10/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTElementPlugInWrapper.h"
#import "KTDataSourceProtocol.h"


@class SVGraphic;
#import "SVPageletPlugIn.h"


@interface KTElementPlugInWrapper (DataSourceRegistration)

+ (NSArray *)graphicsFomPasteboard:(NSPasteboard *)pasteboard
                      insertIntoManagedObjectContext:(NSManagedObjectContext *)context;

// Looks at just first item on pboard
+ (SVGraphic *)graphicFromPasteboard:(NSPasteboard *)pasteboard
                       insertIntoManagedObjectContext:(NSManagedObjectContext *)context;


+ (NSUInteger)numberOfItemsInPasteboard:(NSPasteboard *)draggingInfo;

+ (Class <KTDataSource>)highestPriorityDataSourceForPasteboard:(NSPasteboard *)draggingInfo index:(unsigned)anIndex isCreatingPagelet:(BOOL)isCreatingPagelet;

+ (void)doneProcessingDrag;
@end
