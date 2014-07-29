//
//  PNLAnimatingButtonCell.m
//  TestAnimatingCheckbox
//
//  Created by Peter N Lewis on 29/07/2014.
//  Public Domain. No rights reserved.
//

#import "PNLAnimatingButtonCell.h"

CFTimeInterval kDelayedStartAnimationDuration = 0.03;
CFTimeInterval kStateAnimationDuration = 0.2;
CFTimeInterval kDownAnimationDuration = 0.2;

inline static NSPoint POINT16th( NSRect dstRect, float x, float y )
{
	return NSMakePoint(dstRect.origin.x+dstRect.size.width*(x)/16.0,dstRect.origin.y+dstRect.size.height*(y)/16.0);
}

inline static NSRect RECT16th( NSRect dstRect, float x, float y, float w, float h )
{
	return NSMakeRect(dstRect.origin.x+dstRect.size.width*(x)/16.0,dstRect.origin.y+dstRect.size.height*(y)/16.0,dstRect.size.width*(w)/16.0,dstRect.size.height*(h)/16.0);
}

inline static float WIDTH16th( NSRect dstRect, float x )
{
	return dstRect.size.width*x/16.0;
}

inline static NSPoint FLPOINT16th( float horizf, BOOL flipped, NSRect dstRect, float x, float y )
{
	NSPoint zero = POINT16th( dstRect, 16-y, 16-x );
	NSPoint one = POINT16th( dstRect, x, y );
	NSPoint result = NSMakePoint( zero.x + horizf*(one.x-zero.x), zero.y + horizf*(one.y-zero.y) );
	if ( flipped ) {
		result.y = NSMaxY(dstRect) - result.y;
	}
	return result;
}

/*
 DrawAnimatedFrame draws the image frame in an optionally flipped rectangle.
 The image frame is horizf (float 0.0-1.0) transition from state 0 to state 1
 The image frame is downf (float 0.0-1.0) transition from up 0 to down 1
 */
static void DrawAnimatedFrame( BOOL flipped, NSRect dstRect, float horizf, float downf )
{
	const float borderwidthup = 0.6;
	const float borderwidthdown = 1.5;
	const float cornerradius = 3;
	const float linewidth = 1.5;
	const float xinset = 3;
	const float yinset = 4;
	const float bezcorner = 3;
	const float arrowwidth = 3;
	const float arrowheight = 6;

	if ( horizf < 0 ) horizf = 0;
	if ( horizf > 1 ) horizf = 1;
	if ( downf < 0 ) downf = 0;
	if ( downf > 1 ) downf = 1;

	NSColor* borderColor = [NSColor colorWithCalibratedWhite:0.5 alpha:1];
	float borderwidth = borderwidthup + downf*(borderwidthdown - borderwidthup);
	NSColor* backgroundColor = [NSColor colorWithCalibratedWhite:1 - downf*0.1 alpha:1];
	NSColor* color = [NSColor colorWithCalibratedWhite:0.1*(1 - downf) alpha:1];

	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:RECT16th(dstRect, borderwidth/2,borderwidth/2,16-borderwidth,16-borderwidth) xRadius:WIDTH16th(dstRect, cornerradius) yRadius:WIDTH16th(dstRect, cornerradius)];
	[path setLineWidth:WIDTH16th(dstRect,borderwidth)];
	if ( backgroundColor ) {
		[backgroundColor set];
		[path fill];
	}
	[borderColor set];
	[path stroke];

	path = [NSBezierPath bezierPath];
	[path moveToPoint:FLPOINT16th( horizf, flipped, dstRect, xinset, 16-yinset )];
	[path lineToPoint:FLPOINT16th( horizf, flipped, dstRect, 16-xinset-bezcorner, 16-yinset )];
	[path curveToPoint:FLPOINT16th( horizf, flipped, dstRect, 8,8 ) controlPoint1:FLPOINT16th( horizf, flipped, dstRect, 16-xinset, 16-yinset ) controlPoint2:FLPOINT16th( horizf, flipped, dstRect, 16-xinset, 16-yinset )];
	[path curveToPoint:FLPOINT16th( horizf, flipped, dstRect, xinset+bezcorner, yinset ) controlPoint1:FLPOINT16th( horizf, flipped, dstRect, xinset, yinset ) controlPoint2:FLPOINT16th( horizf, flipped, dstRect, xinset, yinset )];
	[path lineToPoint:FLPOINT16th( horizf, flipped, dstRect, 16-xinset-arrowwidth/2, yinset)];
	[path setLineCapStyle:NSRoundLineCapStyle];
	[color set];
	[path setLineWidth:WIDTH16th(dstRect,linewidth)];
	[path stroke];

	path = [NSBezierPath bezierPath];
	[path moveToPoint:FLPOINT16th( horizf, flipped, dstRect, 16-xinset, yinset )];
	[path lineToPoint:FLPOINT16th( horizf, flipped, dstRect, 16-xinset-arrowwidth, yinset-arrowheight/2 )];
	[path lineToPoint:FLPOINT16th( horizf, flipped, dstRect, 16-xinset-arrowwidth, yinset+arrowheight/2 )];
	[path closePath];
	[color set];
	[path fill];
	
}

static float direction( float where, float destination )
{
	if ( where < destination ) return 1;
	if ( where > destination ) return -1;
	return 0;
}

@implementation PNLAnimatingButtonCell {

	BOOL i_doneSetup;
	BOOL i_animating;

	float i_currentState;
	float i_currentDown;

	CFTimeInterval i_lastTime;
}

- (void) drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
{
	NSButton* buttonView = (NSButton*)controlView;
	if ( ![buttonView isKindOfClass:[NSButton class]] ) return; // Fail!

	// Get joystick values, umm, I mean, desired destination state
	int destinationState = ([buttonView integerValue] != 0) ? 1 : 0;
	int destinationDown = self.isHighlighted ? 1 : 0;
	if ( destinationDown ) { // animate to the alternate state when pressed down
		destinationState = 1 - destinationState;
	}

	CFTimeInterval now = CACurrentMediaTime();

	if ( !i_doneSetup ) { // setup initial conditions
		i_lastTime = now;
		i_currentState = destinationState;
		i_currentDown = destinationDown;
		i_doneSetup = YES;
	}
	if ( !i_animating ) {
		i_lastTime = now;
	}

	i_animating = NO;
	CFTimeInterval timeChange = now - i_lastTime;

	// Move state
	i_currentState += direction( i_currentState, destinationState ) * timeChange / kStateAnimationDuration;
	if ( i_currentState <= 0.0 ) {
		i_currentState = 0;
	} else if ( i_currentState >= 1.0 ) {
		i_currentState = 1.0;
	}

	// Move down
	i_currentDown += direction( i_currentDown, destinationDown ) * timeChange / kDownAnimationDuration;
	if ( i_currentDown <= 0.0 ) {
		i_currentDown = 0;
	} else if ( i_currentDown >= 1.0 ) {
		i_currentDown = 1.0;
	}

	// Technically, comparing against floating point numbers is a bad idea, but 0.0 and 1.0 are exactly representable, so this should be safe
	i_animating = (i_currentState != (float)destinationState) || (i_currentDown != (float)destinationDown);

	if ( i_animating ) {
		[controlView setNeedsDisplayInRect:cellFrame]; // This is insufficient, probably because the dirty flag is cleared after the drawing
		dispatch_async( dispatch_get_main_queue(), ^{
			[controlView setNeedsDisplayInRect:cellFrame];
		});
	}
//	NSLog( @"DrawImage %d %d, %f %f, %f", destinationState, destinationDown, i_currentState, i_currentDown, now-i_lastTime );
	DrawAnimatedFrame( controlView.isFlipped, cellFrame, i_currentState, i_currentDown );

	i_lastTime = now;
}

@end
