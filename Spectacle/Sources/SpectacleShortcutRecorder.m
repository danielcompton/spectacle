#import "SpectacleShortcutRecorder.h"

#import <Carbon/Carbon.h>

#import "SpectacleShortcut.h"
#import "SpectacleShortcutRecorder.h"
#import "SpectacleShortcutRecorderDelegate.h"
#import "SpectacleShortcutTranslations.h"
#import "SpectacleShortcutValidation.h"

static const NSTrackingAreaOptions kTrackingAreaOptions = (NSTrackingMouseEnteredAndExited
                                                           | NSTrackingActiveWhenFirstResponder
                                                           | NSTrackingEnabledDuringMouseDrag);

static const NSEventModifierFlags kCocoaModifierFlagsMask = (NSControlKeyMask
                                                             | NSAlternateKeyMask
                                                             | NSShiftKeyMask
                                                             | NSCommandKeyMask);

@implementation SpectacleShortcutRecorder
{
  BOOL _isRecording;
  BOOL _isMouseAboveBadge;
  BOOL _isMouseDown;
  NSTrackingArea *_shortcutRecorderTrackingArea;
  NSTrackingArea *_badgeButtonTrackingArea;
}

- (instancetype)initWithFrame:(NSRect)frame
{
  if (self = [super initWithFrame:frame]) {
    _badgeButtonTrackingArea = [[NSTrackingArea alloc] initWithRect:badgeRectInBounds(self.bounds)
                                                            options:kTrackingAreaOptions
                                                              owner:self
                                                           userInfo:nil];
    [self addTrackingArea:_badgeButtonTrackingArea];
  }
  return self;
}

- (void)setShortcut:(SpectacleShortcut *)shortcut
{
  _shortcut = shortcut;
  [self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder
{
  return YES;
}

- (BOOL)resignFirstResponder
{
  [self _stopRecording];
  return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
  return YES;
}

- (void)mouseEntered:(NSEvent *)event
{
  if (event.trackingArea == _badgeButtonTrackingArea) {
    _isMouseAboveBadge = YES;
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseDown:(NSEvent *)event
{
  _isMouseDown = YES;
  [self setNeedsDisplay:YES];
}

- (void)mouseUp:(NSEvent *)event
{
  _isMouseDown = NO;
  NSPoint locationInView = [self convertPoint:event.locationInWindow fromView:nil];
  if ([self mouse:locationInView inRect:badgeRectInBounds(self.bounds)]) {
    if (_isRecording) {
      [self _stopRecording];
    } else {
      [self _clearShortcut];
    }
  } else if ([self mouse:locationInView inRect:self.bounds]) {
    [self _startRecording];
  } else if (!_isMouseAboveBadge) {
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseExited:(NSEvent *)event
{
  if (event.trackingArea == _badgeButtonTrackingArea) {
    _isMouseAboveBadge = NO;
    [self setNeedsDisplay:YES];
  }
}

- (void)keyDown:(NSEvent *)event
{
  if (![self performKeyEquivalent:event]) {
    [super keyDown:event];
  }
}

- (BOOL)performKeyEquivalent:(NSEvent *)event
{
  if (self.window.firstResponder != self) {
    return NO;
  }
  NSEventModifierFlags modifierFlags = event.modifierFlags & kCocoaModifierFlagsMask;
  if (modifierFlags == NSAlternateKeyMask) {
    return NO;
  }
  if (event.keyCode == kVK_Escape && modifierFlags == 0) {
    [self _stopRecording];
    return YES;
  }
  NSInteger keyCode = event.keyCode;
  BOOL functionKey = ((keyCode == kVK_F1)  || (keyCode == kVK_F2)  || (keyCode == kVK_F3)  || (keyCode == kVK_F4)  ||
                      (keyCode == kVK_F5)  || (keyCode == kVK_F6)  || (keyCode == kVK_F7)  || (keyCode == kVK_F8)  ||
                      (keyCode == kVK_F9)  || (keyCode == kVK_F10) || (keyCode == kVK_F11) || (keyCode == kVK_F12) ||
                      (keyCode == kVK_F13) || (keyCode == kVK_F14) || (keyCode == kVK_F15) || (keyCode == kVK_F16) ||
                      (keyCode == kVK_F17) || (keyCode == kVK_F18) || (keyCode == kVK_F19) || (keyCode == kVK_F20));
  if (_isRecording && (functionKey || [SpectacleShortcut validCocoaModifiers:modifierFlags])) {
    SpectacleShortcut *newShortcut = [[SpectacleShortcut alloc] initWithShortcutName:_shortcutName
                                                                     shortcutKeyCode:keyCode
                                                                   shortcutModifiers:modifierFlags];
    NSError *error = nil;
    if (![_shortcutValidation isShortcutValid:newShortcut error:&error]) {
      [[NSAlert alertWithError:error] runModal];
    } else {
      _shortcut = newShortcut;
      [_delegate shortcutRecorder:self didReceiveNewShortcut:newShortcut];
    }
    [self _stopRecording];
    return YES;
  }
  return NO;
}

- (void)flagsChanged:(NSEvent *)event
{
  if (!_isRecording) {
    return;
  }
  if ((event.modifierFlags & kCocoaModifierFlagsMask) == NSAlternateKeyMask) {
    return;
  }
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)rect
{
  CGFloat radius = NSHeight(rect) / 2.0f;
  [self _drawBorderInRect:rect withRadius:radius];
  [self _drawBackgroundInRect:rect withRadius:radius];
  [self _drawBadgeInRect:rect];
  [self _drawLabelInRect:rect];
}

- (void)_startRecording
{
  _isRecording = YES;
  [self setNeedsDisplay:YES];
}

- (void)_stopRecording
{
  if (!_isRecording) {
    return;
  }
  _isRecording = NO;
  [self setNeedsDisplay:YES];
}

- (void)_clearShortcut
{
  [_delegate shortcutRecorder:self didClearExistingShortcut:_shortcut];
  _shortcut = nil;
  [self setNeedsDisplay:YES];
}

- (void)_drawBorderInRect:(NSRect)rect withRadius:(CGFloat)radius
{
  NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:rect xRadius:radius yRadius:radius];
  [NSGraphicsContext.currentContext saveGraphicsState];
  [roundedPath addClip];
  [[NSColor windowFrameColor] set];
  [NSBezierPath fillRect:rect];
  [NSGraphicsContext.currentContext restoreGraphicsState];
}

- (void)_drawBackgroundInRect:(NSRect)rect withRadius:(CGFloat)radius
{
  NSBezierPath *roundedPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 1.0f, 1.0f)
                                                              xRadius:radius
                                                              yRadius:radius];
  NSColor *gradientStartingColor = nil;
  NSColor *gradientEndingColor = nil;
  NSGradient *gradient = nil;
  [NSGraphicsContext.currentContext saveGraphicsState];
  [roundedPath addClip];
  if (_isRecording) {
    gradientStartingColor = [NSColor colorWithDeviceRed:0.784f green:0.953f blue:1.0f alpha:1.0f];
    gradientEndingColor = [NSColor colorWithDeviceRed:0.694f green:0.859f blue:1.0f alpha:1.0f];
  } else {
    gradientStartingColor = [[[NSColor whiteColor] shadowWithLevel:0.2f] colorWithAlphaComponent:0.9f];
    gradientEndingColor = [[[NSColor whiteColor] highlightWithLevel:0.2f] colorWithAlphaComponent:0.9f];
  }
  if (!_isRecording && _isMouseDown && !_isMouseAboveBadge) {
    gradient = [[NSGradient alloc] initWithStartingColor:gradientEndingColor endingColor:gradientStartingColor];
  } else {
    gradient = [[NSGradient alloc] initWithStartingColor:gradientStartingColor endingColor:gradientEndingColor];
  }
  [gradient drawInRect:rect angle:90.0f];
  [NSGraphicsContext.currentContext restoreGraphicsState];
}

- (void)_drawBadgeInRect:(NSRect)rect
{
  NSRect badgeRect = badgeRectInBounds(rect);
  if ((_isRecording && !_shortcut) || (!_isRecording && _shortcut)) {
    [self _drawClearShortcutBadgeInRect:badgeRect opacity:0.25f];
  } else if (_isRecording) {
    [self _drawRevertShortcutBadgeInRect:badgeRect];
  }
  if (((_shortcut && !_isRecording) || (!_shortcut && _isRecording)) && _isMouseAboveBadge && _isMouseDown) {
    [self _drawClearShortcutBadgeInRect:badgeRect opacity:0.50f];
  }
}

- (void)_drawClearShortcutBadgeInRect:(NSRect)rect opacity:(CGFloat)opacity
{
  CGFloat horizontalScale = (rect.size.width / 13.0f);
  CGFloat verticalScale = (rect.size.height / 13.0f);
  [NSGraphicsContext.currentContext saveGraphicsState];
  [[NSColor colorWithCalibratedWhite:0.0f alpha:opacity] setFill];
  [[NSBezierPath bezierPathWithOvalInRect:rect] fill];
  [[NSColor whiteColor] setStroke];
  NSBezierPath *cross = [NSBezierPath new];
  [cross setLineWidth:horizontalScale * 1.4f];
  [cross moveToPoint:relativePointInRect(4.0f, 4.0f, rect, horizontalScale, verticalScale)];
  [cross lineToPoint:relativePointInRect(9.0f, 9.0f, rect, horizontalScale, verticalScale)];
  [cross moveToPoint:relativePointInRect(9.0f, 4.0f, rect, horizontalScale, verticalScale)];
  [cross lineToPoint:relativePointInRect(4.0f, 9.0f, rect, horizontalScale, verticalScale)];
  [cross stroke];
  [NSGraphicsContext.currentContext restoreGraphicsState];
}

- (void)_drawRevertShortcutBadgeInRect:(NSRect)rect
{
  CGFloat horizontalScale = (rect.size.width / 1.0f);
  CGFloat verticalScale = (rect.size.height / 1.0f);
  [NSGraphicsContext.currentContext saveGraphicsState];
  NSBezierPath *swoosh = [NSBezierPath new];
  [swoosh setLineWidth:horizontalScale];
  [swoosh moveToPoint:relativePointInRect(0.0489685f, 0.6181513f, rect, horizontalScale, verticalScale)];
  [swoosh lineToPoint:relativePointInRect(0.4085750f, 0.9469318f, rect, horizontalScale, verticalScale)];
  [swoosh lineToPoint:relativePointInRect(0.4085750f, 0.7226146f, rect, horizontalScale, verticalScale)];
  [swoosh curveToPoint:relativePointInRect(0.8508247f, 0.4836237f, rect, horizontalScale, verticalScale)
         controlPoint1:relativePointInRect(0.4085750f, 0.7226146f, rect, horizontalScale, verticalScale)
         controlPoint2:relativePointInRect(0.8371143f, 0.7491841f, rect, horizontalScale, verticalScale)];
  [swoosh curveToPoint:relativePointInRect(0.5507195f, 0.0530682f, rect, horizontalScale, verticalScale)
         controlPoint1:relativePointInRect(0.8677834f, 0.1545071f, rect, horizontalScale, verticalScale)
         controlPoint2:relativePointInRect(0.5507195f, 0.0530682f, rect, horizontalScale, verticalScale)];
  [swoosh curveToPoint:relativePointInRect(0.7421721f, 0.3391942f, rect, horizontalScale, verticalScale)
         controlPoint1:relativePointInRect(0.5507195f, 0.0530682f, rect, horizontalScale, verticalScale)
         controlPoint2:relativePointInRect(0.7458685f, 0.1913146f, rect, horizontalScale, verticalScale)];
  [swoosh curveToPoint:relativePointInRect(0.4085750f, 0.5154130f, rect, horizontalScale, verticalScale)
         controlPoint1:relativePointInRect(0.7383412f, 0.4930328f, rect, horizontalScale, verticalScale)
         controlPoint2:relativePointInRect(0.4085750f, 0.5154130f, rect, horizontalScale, verticalScale)];
  [swoosh lineToPoint:relativePointInRect(0.4085750f, 0.2654000f, rect, horizontalScale, verticalScale)];
  [swoosh fill];
  [NSGraphicsContext.currentContext restoreGraphicsState];
}

- (void)_drawLabelInRect:(NSRect)rect
{
  NSString *label = nil;
  NSColor *foregroundColor = [NSColor blackColor];
  if (_isRecording && !_isMouseAboveBadge) {
    label = NSLocalizedString(@"ShortcutRecorderLabelEnterShortcut", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut");
  } else if (_isRecording && _isMouseAboveBadge && !_shortcut) {
    label = NSLocalizedString(@"ShortcutRecorderLabelStopRecording", @"The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does not have a previously recorded shortcut");
  } else if (_isRecording && _isMouseAboveBadge) {
    label = NSLocalizedString(@"ShortcutRecorderLabelUseExisting", "The shortcut recorder label displayed when the shorcut recorder is recording a shortcut and the shortcut recorder does have a previously recorded shortcut");
  } else if (_shortcut) {
    label = _shortcut.displayString;
  } else {
    label = NSLocalizedString(@"ShortcutRecorderLabelClickToRecord", @"The shortcut recorder label displayed when the shorcut recorder is cleared and ready to record a new shortcut");
  }
  NSEventModifierFlags modifierFlags = [NSEvent modifierFlags] & kCocoaModifierFlagsMask;
  if (_isRecording && modifierFlags) {
    label = SpectacleTranslateModifiers(modifierFlags);
  }
  if (_isRecording) {
    [self _drawString:label withForegroundColor:foregroundColor inRect:rect];
  } else {
    [self _drawString:label withForegroundColor:foregroundColor inRect:rect];
  }
}

- (void)_drawString:(NSString *)string withForegroundColor:(NSColor *)foregroundColor inRect:(NSRect)rect
{
  NSMutableDictionary<NSString *, id> *attributes = stringAttributesWithShadow();
  NSRect labelRect = rect;
  attributes[NSFontAttributeName] = [NSFont systemFontOfSize:NSFont.smallSystemFontSize];
  attributes[NSForegroundColorAttributeName] = foregroundColor;
  labelRect.origin.y = -(NSMidY(rect) - [string sizeWithAttributes:attributes].height / 2.0f);
  [string drawInRect:labelRect withAttributes:attributes];
}

static NSRect badgeRectInBounds(NSRect bounds)
{
  NSRect badgeRect;
  NSSize badgeSize;
  badgeSize.width = 13.0f;
  badgeSize.height = 13.0f;
  badgeRect.origin = NSMakePoint(NSMaxX(bounds) - badgeSize.width - 4.0f, floor((NSMaxY(bounds) - badgeSize.height) / 2.0f));
  badgeRect.size = badgeSize;
  return badgeRect;
}

static NSMutableDictionary<NSString *, id> *stringAttributesWithShadow(void)
{
  NSMutableParagraphStyle *paragraphStyle = NSParagraphStyle.defaultParagraphStyle.mutableCopy;
  NSShadow *textShadow = [NSShadow new];
  NSMutableDictionary<NSString *, id> *stringAttributes = [NSMutableDictionary new];
  paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
  paragraphStyle.alignment = NSCenterTextAlignment;
  textShadow.shadowColor = [NSColor whiteColor];
  textShadow.shadowOffset = NSMakeSize(0.0f, -1.0);
  textShadow.shadowBlurRadius = 0.0f;
  stringAttributes[NSParagraphStyleAttributeName] = paragraphStyle;
  stringAttributes[NSShadowAttributeName] = textShadow;
  return stringAttributes;
}

static NSPoint relativePointInRect(CGFloat x, CGFloat y, CGRect rect, CGFloat horizontalScale, CGFloat verticalScale)
{
  return NSMakePoint((x * horizontalScale) + rect.origin.x, (y * verticalScale) + rect.origin.y);
}

@end
