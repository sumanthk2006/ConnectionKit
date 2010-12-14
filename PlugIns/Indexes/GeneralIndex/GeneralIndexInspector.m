//
//  GeneralIndexInspector.m
//  GeneralIndex
//
//  Created by Dan Wood on 12/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "GeneralIndexInspector.h"
#import "GeneralIndexPlugIn.h"



@implementation SVActionWhenDoneSliderCell

- (void)stopTracking:(NSPoint)lastPoint at:(NSPoint)stopPoint inView:(NSView *)controlView mouseIsUp:(BOOL)flag
{
	[super stopTracking:lastPoint at:stopPoint inView:controlView mouseIsUp:flag];
	
	if (flag)
	{
		NSControl *slider = (NSControl *)[self controlView];
		if ([slider respondsToSelector:@selector(sendAction:to:)])
		{
			BOOL sent = [slider sendAction:@selector(sliderDone:) to:self.target];
			if (!sent)
			{
				NSBeep();
			}
		}
	}
}
@end


@implementation GeneralIndexInspector

+ (void)initialize
{
	[self setKeys:[NSArray arrayWithObjects:
				   @"inspectedObjectsController.selection.truncationType",
				   @"truncateSliderValue",
				   nil]
	triggerChangeNotificationsForDependentKey:@"truncateCountLive"];
	
	[self setKeys:[NSArray arrayWithObjects:
				   @"inspectedObjectsController.selection.truncationType",
				   @"truncateSliderValue",
				   nil]
triggerChangeNotificationsForDependentKey:@"truncateCountLive"];
}

// Will a different function make the "slope" a bit closer to linear?
#define LOGFUNCTION log2
#define EXPFUNCTION(x) exp2(x)

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
	if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) != nil) {
	
		[self addObserver:self
				  forKeyPath:@"inspectedObjectsController.selection"
					 options:0
					 context:nil];
		[self addObserver:self
			   forKeyPath:@"inspectedObjectsController.selection.truncationType"
				  options:0
				  context:nil];
	}
	return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
					    change:(NSDictionary *)change
					   context:(void *)context
{
	if ([keyPath isEqualToString:@"inspectedObjectsController.selection"])
	{
		id truncCountNum = [self valueForKeyPath:@"inspectedObjectsController.selection.truncateCount"];
		if (!NSIsControllerMarker(truncCountNum))
		{
			NSUInteger truncCount = [truncCountNum intValue];
			self.truncateCountLive = truncCount;			// this will populate field and slider
		}
	}
	else if ([keyPath isEqualToString:@"inspectedObjectsController.selection.truncationType"])
	{
		id truncTypeNum = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
		if (!NSIsControllerMarker(truncTypeNum))
		{
			SVIndexTruncationType type = [truncTypeNum intValue];
			
			NSUInteger exponentTransformed = round(EXPFUNCTION(self.truncateSliderValue));
			NSUInteger truncCount = [GeneralIndexPlugIn truncationCountFromChars:exponentTransformed forType:type round:NO];
			self.truncateCountLive = truncCount;
		}
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"inspectedObjectsController.selection"];
	[self removeObserver:self forKeyPath:@"inspectedObjectsController.selection.truncationType"];
	[super dealloc];
}


-(void)awakeFromNib;
{
	[oTruncationSlider setTarget:self];
}

- (IBAction)sliderDone:(id)sender;		// Slider done dragging.  Move the final value into the model
{
	// if Sender is nil, then we are actually setting from a real number, so don't round.
	id truncTypeNum = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	if (!NSIsControllerMarker(truncTypeNum))
	{
		SVIndexTruncationType type = [truncTypeNum intValue];
		
		NSUInteger exponentTransformed = round(EXPFUNCTION(self.truncateSliderValue));
		NSUInteger truncCount = [GeneralIndexPlugIn
								 truncationCountFromChars:exponentTransformed
										forType:type
								 round:(nil != sender)];
		
		NSNumber *countNum = [NSNumber numberWithInt:truncCount];
		//NSLog(@"setting truncateCount to %@", countNum);
		NSNumber *oldValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncateCount"];
		if ([oldValue intValue] != truncCount)
		{
			// Don't record a change unless it has actually changed.
			[self setValue:countNum forKeyPath:@"inspectedObjectsController.selection.truncateCount"];
		}
	}
}

// Convert slider 0.0 to 1.0 range to approprate truncation types.
- (int) truncCountFromSliderValueWithTrucType:(SVIndexTruncationType *)outTruncType
{
	
	
	
	return 0;
}


@synthesize truncateSliderValue = _truncateSliderValue;		// bound to the slider; it's LOGFUNCTION of char count

- (void) setTruncateSliderValue:(double)aValue
{
	_truncateSliderValue = aValue;
	
	SVIndexTruncationType truncType = 0;
	NSLog(@"slider %.2f -> %@ %@", [self truncCountFromSliderValueWithTrucType:&truncType]);
}

- (NSUInteger)truncateCountLive	// bound to the text field. update text field when slider changes
{
	id theValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	if (!NSIsControllerMarker(theValue))
	{
		SVIndexTruncationType type = [theValue intValue];
		int exponentTransformed = round(EXPFUNCTION(self.truncateSliderValue));
		NSUInteger truncCount = [GeneralIndexPlugIn truncationCountFromChars:exponentTransformed forType:type round:NO];
		return truncCount;
	}
	return 0;
}

- (void) setTruncateCountLive:(NSUInteger)aCount	// number entered in text field. Set slider, and also model.
{
	id theValue = [self valueForKeyPath:@"inspectedObjectsController.selection.truncationType"];
	if (!NSIsControllerMarker(theValue))
	{
		SVIndexTruncationType type = [theValue intValue];
		NSUInteger charCount = [GeneralIndexPlugIn charsFromTruncationCount:aCount forType:type];
		//NSLog(@"setTruncateCountLive:%d setting charCount for slider to %d", aCount, charCount);
		self.truncateSliderValue = LOGFUNCTION(charCount);
		[self sliderDone:nil];		// copy slider
	}
}


- (IBAction)makeShortest:(id)sender;	// click on icon to make truncation the shortest
{
	[oTruncationSlider setDoubleValue:[oTruncationSlider minValue]];
}

- (IBAction)makeLongest:(id)sender;		// click on icon to make truncation the longest (remove truncation)
{
	[oTruncationSlider setDoubleValue:[oTruncationSlider maxValue]];
}


@end
