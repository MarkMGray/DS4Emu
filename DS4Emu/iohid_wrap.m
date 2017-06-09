#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOTypes.h>
#include <IOKit/IOReturn.h>
#include <IOKit/hid/IOHIDLib.h>
#import <objc/runtime.h>

#include <stdio.h>
#include <unistd.h>
#include <dlfcn.h>

// function to create matching dictionary
static CFMutableDictionaryRef hu_CreateDeviceMatchingDictionary( UInt32 inUsagePage, UInt32 inUsage )
{
    // create a dictionary to add usage page/usages to
    CFMutableDictionaryRef result = CFDictionaryCreateMutable(
                                                              kCFAllocatorDefault, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks );
    if ( result ) {
        if ( inUsagePage ) {
            // Add key for device type to refine the matching dictionary.
            CFNumberRef pageCFNumberRef = CFNumberCreate(
                                                         kCFAllocatorDefault, kCFNumberIntType, &inUsagePage );
            if ( pageCFNumberRef ) {
                CFDictionarySetValue( result,
                                     CFSTR( kIOHIDDeviceUsagePageKey ), pageCFNumberRef );
                CFRelease( pageCFNumberRef );
                
                // note: the usage is only valid if the usage page is also defined
                if ( inUsage ) {
                    CFNumberRef usageCFNumberRef = CFNumberCreate(
                                                                  kCFAllocatorDefault, kCFNumberIntType, &inUsage );
                    if ( usageCFNumberRef ) {
                        CFDictionarySetValue( result,
                                             CFSTR( kIOHIDDeviceUsageKey ), usageCFNumberRef );
                        CFRelease( usageCFNumberRef );
                    } else {
                        fprintf( stderr, "%s: CFNumberCreate( usage ) failed.", __PRETTY_FUNCTION__ );
                    }
                }
            } else {
                fprintf( stderr, "%s: CFNumberCreate( usage page ) failed.", __PRETTY_FUNCTION__ );
            }
        }
    } else {
        fprintf( stderr, "%s: CFDictionaryCreateMutable failed.", __PRETTY_FUNCTION__ );
    }
    return result;
}   // hu_CreateDeviceMatchingDictionary

char * MYCFStringCopyUTF8String(CFStringRef aString) {
    if (aString == NULL) {
        return NULL;
    }
    
    CFIndex length = CFStringGetLength(aString);
    CFIndex maxSize =
    CFStringGetMaximumSizeForEncoding(length, kCFStringEncodingUTF8) + 1;
    char *buffer = (char *)malloc(maxSize);
    if (CFStringGetCString(aString, buffer, maxSize,
                           kCFStringEncodingUTF8)) {
        return buffer;
    }
    free(buffer); // If we failed
    return NULL;
}

int reportCount = 0;
double diffx = 0;
double diffy = 0;
bool leftMouseDown = false;
bool rightMouseDown = false;
bool startMouseWarp = false;

dispatch_semaphore_t mouseSemaphore;

static void Handle_IOHIDInputValueCallback(
                                           void *          inContext,      // context from IOHIDManagerRegisterInputValueCallback
                                           IOReturn        inResult,       // completion result for the input value operation
                                           void *          inSender,       // the IOHIDManagerRef
                                           IOHIDValueRef   inIOHIDValueRef // the new element value
) {
    IOHIDElementRef elementRef = IOHIDValueGetElement(inIOHIDValueRef);
    uint32_t usage = IOHIDElementGetUsage(elementRef);
    
    CFIndex x = IOHIDValueGetIntegerValue(inIOHIDValueRef);
    
    dispatch_semaphore_wait(mouseSemaphore, DISPATCH_TIME_FOREVER);
    switch(usage)
    {
        case 1:
            leftMouseDown = x;
            break;
        case 2:
            rightMouseDown = x;
            break;
        case 48: diffx = x;
            break;
        case 49: diffy = x;
            break;
    }
    dispatch_semaphore_signal(mouseSemaphore);
}

typedef struct {
    uint8_t id,
    left_x, left_y,
    right_x, right_y,
    buttons1, buttons2, buttons3,
    left_trigger, right_trigger,
    unk1, unk2, unk3;
    int16_t gyro_x, gyro_y, gyro_z;
    int16_t accel_x, accel_y, accel_z;
    uint8_t unk4[39];
} PSReport;

@interface HIDRunner:NSObject
{
    bool keys[256];
    bool X, O, square, triangle, PS, touchpad, options, share,
    L1, L2, L3, R1, R2, R3, dpadUp, dpadDown, dpadLeft, dpadRight;
    float leftX, leftY, rightX, rightY; // -1 to 1
    int ticks;
    CFAbsoluteTime lastMouseTime;
    float sensitivity;
}

@end

static HIDRunner *hid;

typedef void (*send_type)(id, SEL, CFIndex, uint8_t *, CFIndex);
static send_type originalParse = NULL;

#define SWAP(ocls, sel) do { \
	id rcls = NSClassFromString(@"_TtC10RemotePlay17RPWindowStreaming"); \
	SEL selector = @selector sel; \
	Method original = class_getInstanceMethod(rcls, selector); \
	Method new = class_getInstanceMethod(cls, selector); \
	method_exchangeImplementations(original, new); \
} while(0)

@implementation HIDRunner

+ (void)load {
    
    mouseSemaphore = dispatch_semaphore_create(1);
    
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		id cls = NSClassFromString(@"HIDRunner");
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (keyDown:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (keyUp:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (mouseMoved:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (mouseDown:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (mouseUp:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (rightMouseDown:));
		SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (rightMouseUp:));
        SWAP(@"_TtC10RemotePlay17RPWindowStreaming", (flagsChanged:));
        
        id mcls = NSClassFromString(@"DSDevice");
        SEL mSelector = @selector(parseInputReportID:Report:Length:);
        Method orig = class_getInstanceMethod(mcls, mSelector);
        originalParse = (send_type) method_getImplementation(orig);
        Method new = class_getInstanceMethod(cls, @selector(parseInputReportID:Report:Length:));
        method_exchangeImplementations(orig, new);
        
        hid = [[HIDRunner alloc] init];
	});
    
    IOHIDManagerRef managerRef = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    // Create a matching dictionary
    CFDictionaryRef matchingCFDictRef =
    hu_CreateDeviceMatchingDictionary( kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse );
    
    hid->lastMouseTime = CFAbsoluteTimeGetCurrent();
    hid->sensitivity = 6.0;
    printf("hello world\n");
    
    if ( matchingCFDictRef ) {
        // set the HID device matching dictionary
        IOHIDManagerSetDeviceMatching( managerRef, matchingCFDictRef );
    } else {
        fprintf( stderr, "%s: hu_CreateDeviceMatchingDictionary failed.", __PRETTY_FUNCTION__ );
        return;
    }
    
    CFRunLoopRef runLoopRef = CFRunLoopGetCurrent();
    IOHIDManagerScheduleWithRunLoop(managerRef, runLoopRef, kCFRunLoopDefaultMode);
    
    
    IOReturn ret = IOHIDManagerOpen(managerRef, kIOHIDOptionsTypeNone);
    
    if(ret != kIOReturnSuccess)
        fprintf( stderr, "%s: IOHIDManagerOpen failed.", __PRETTY_FUNCTION__ );
    
    //IOHIDManagerClose(managerRef, kIOHIDOptionsTypeNone);
    
    int context = 1;
    IOHIDManagerRegisterInputValueCallback( managerRef, Handle_IOHIDInputValueCallback, &context );
    printf("here");
    //CFRunLoopRun();
}

#define DOWN(key) keys[key]
- (uint8_t *) mapKeys: (uint8_t *) rep{
#include "../mapKeys.h"
    
    uint8_t brep[] = {0x01, 0x7f, 0x81, 0x82, 0x7d, 0x08, 0x00, 0xb4, 0x00, 0x00, 0xc8, 0xad, 0xf9, 0x04, 0x00, 0xfe, 0xff, 0xfc, 0xff, 0xe5, 0xfe, 0xcb, 0x1f, 0x69, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1b, 0x00, 0x00, 0x01, 0x63, 0x8b, 0x80, 0xc1, 0x2e, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00};
    
    PSReport *prep = (PSReport *) rep;
    
    memcpy(rep, brep, sizeof(brep));
    
    //keys
    uint8_t dpad = 8;
    if(dpadLeft) {
        if(dpadUp)
            dpad = 7;
        else if(dpadDown)
            dpad = 5;
        else
            dpad = 6;
    } else if(dpadRight) {
        if(dpadUp)
            dpad = 1;
        else if(dpadDown)
            dpad = 3;
        else
            dpad = 2;
    } else if(dpadUp)
        dpad = 0;
    else if(dpadDown)
        dpad = 4;
    
    prep->buttons1 = (triangle ? (1 << 7) : 0) | (O ? (1 << 6) : 0) | (X ? (1 << 5) : 0) | (square ? (1 << 4) : 0) | dpad;
    prep->buttons2 = (R3 ? (1 << 7) : 0) | (L3 ? (1 << 6) : 0) | (options ? (1 << 5) : 0) | (share ? (1 << 4) : 0) |
    (leftMouseDown ? (1 << 3) : 0) | (rightMouseDown ? (1 << 2) : 0) | (R1 ? (1 << 1) : 0) | (L1 ? (1 << 0) : 0);
    prep->buttons3 = ((ticks << 2) & 0xFF) | (touchpad ? 2 : 0) | (PS ? 1 : 0);
    prep->left_x = (uint8_t) fmin(fmax(128 + leftX * 128, 0), 255);
    prep->left_y = (uint8_t) fmin(fmax(128 + leftY * 128, 0), 255);
    
    //mouses
    dispatch_semaphore_wait(mouseSemaphore, DISPATCH_TIME_FOREVER);
    
    prep->left_trigger = rightMouseDown ? 255 : 0;
    prep->right_trigger = leftMouseDown ? 255 : 0;
    
    CFAbsoluteTime currTime = CFAbsoluteTimeGetCurrent();
    float diffTimeMs = currTime - hid->lastMouseTime;
    diffTimeMs *= 100.0f;
    
    hid->lastMouseTime = currTime;
    float speedX = fabs(diffx/diffTimeMs);
    float speedY = fabs(diffy/diffTimeMs);
    
    float dist = sqrtf(diffx*diffx + diffy*diffy);
    
    float vX = dist == 0 ? 0 : speedX / dist*diffx;
    float vY = dist == 0 ? 0 : speedY / dist*diffy;
    
    vX *= hid->sensitivity;
    vY *= hid->sensitivity;
    
    if(vX < 0)
        vX = fmax(96 + vX, 0);
    else if(vX > 0)
        vX = fmin(160 + vX, 255);
    else
        vX = 128;
    
    if(vY < 0)
        vY = fmax(96 + vY, 0);
    else if(vY > 0)
        vY = fmin(160 + vY, 255);
    else
        vY = 128;
    
    prep->right_x = (uint8_t) vX;
    prep->right_y = (uint8_t) vY;
    
    //NSLog(@"\nvX: %f\n vY: %f", vX, vY);
    diffx = diffy = 0;
    
    dispatch_semaphore_signal(mouseSemaphore);
    
    NSWindow * window = [[NSApplication sharedApplication] mainWindow];
    NSRect f = [window frame];
    
    if(startMouseWarp && [[NSApplication sharedApplication] isActive])
        CGWarpMouseCursorPosition(CGPointMake(f.origin.x + f.size.width / 2, f.origin.y + f.size.height / 2));
    
    
    
    ticks++;
    
    return rep;
}

-(void) parseInputReportID: (CFIndex) index Report: (uint8_t *) rep Length: (CFIndex) len
{
    if(index == 1 && len == 64)
    {
        rep = [hid mapKeys:rep];
        //NSLog(@"Input Report ID: %lu, Length: %lu", index, len);
        originalParse(self, @selector(parseInputReportID:Report:Length:), index, rep, len);
    }else{
        NSLog(@"We received a different report - ID: %lu Length: %lu", index, len);
    }
    
}

- (void)keyDown:(NSEvent *)event {
    hid->keys[[event keyCode]] = true;
    
    NSLog(@"Key down: %i", [event keyCode]);
    
    if(!startMouseWarp) startMouseWarp = true;
}

const int NumPadPlusKeyCode = 69;
const int NumPadMinusKeyCode = 78;
const int LeftShiftKeyCode = 56;
const int LeftCtrlKeyCode = 59;
const float SensitivityIncriment = 0.1;
- (void)flagsChanged:(NSEvent*) event {
    hid->keys[LeftShiftKeyCode] = [event modifierFlags] & NSEventModifierFlagShift;
    hid->keys[LeftCtrlKeyCode] = [event modifierFlags] & NSEventModifierFlagControl;
}

- (void)keyUp:(NSEvent *)event {
    hid->keys[[event keyCode]] = false;
    
    //NSLog(@"Key up: %i", [event keyCode]);
    
    if ([event keyCode] == NumPadPlusKeyCode)
        hid->sensitivity += SensitivityIncriment;
    if ([event keyCode] == NumPadMinusKeyCode)
        hid->sensitivity -= SensitivityIncriment;
    
    if ([event keyCode] == NumPadPlusKeyCode || [event keyCode] == NumPadMinusKeyCode)
        NSLog(@"Sensitivity: %f", hid->sensitivity);
}

@end
