//
//  main.m
//  DS4EmuWindow
//
//  Created by Mathew A Gray on 5/26/17.
//  Copyright © 2017 Gray Gaming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <OpenGL/gl.h>
#import "FastSocket.h"
#import <GLFW/glfw3.h>
#include <IOKit/hid/IOHIDKeys.h>

double lastMouseX, lastMouseY;

FastSocket * sock;
int ticks;

uint8_t brep[] = {0x01, 0x7f, 0x81, 0x82, 0x7d, 0x08, 0x00, 0xb4, 0x00, 0x00, 0xc8, 0xad, 0xf9, 0x04, 0x00, 0xfe, 0xff, 0xfc, 0xff, 0xe5, 0xfe, 0xcb, 0x1f, 0x69, 0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1b, 0x00, 0x00, 0x01, 0x63, 0x8b, 0x80, 0xc1, 0x2e, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x80, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00};

//currently unused, checking if sticky keys works well instead of having to maintain our own structure
/*
static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
        glfwSetWindowShouldClose(window, GLFW_TRUE);
}*/


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

bool isKeyDown(GLFWwindow * window, int key)
{
    int state = glfwGetKey(window, key);
    return state == GLFW_PRESS || state == GLFW_REPEAT;
}

bool isMouseButtonDown(GLFWwindow * window, int button)
{
    int state = glfwGetMouseButton(window, button);
    return state == GLFW_PRESS || state == GLFW_REPEAT;
}

void parseKeys(GLFWwindow * window, PSReport * prep)
{
    bool X, O, square, triangle, PS, touchpad, options, share = false,
    L1, L2, L3, R1, R2, R3, dpadUp, dpadDown, dpadLeft, dpadRight;
    float leftX, leftY; // -1 to 1

    X = isKeyDown(window, GLFW_KEY_SPACE);
    O = isKeyDown(window, GLFW_KEY_C);
    square = isKeyDown(window, GLFW_KEY_R);
    triangle = isKeyDown(window, GLFW_KEY_Q);
    PS = isKeyDown(window, GLFW_KEY_P);
    touchpad = isKeyDown(window, GLFW_KEY_T);
    options = isKeyDown(window, GLFW_KEY_TAB);
    L1 = isKeyDown(window, GLFW_KEY_G);
    R1 = isKeyDown(window, GLFW_KEY_V);
    L3 = isKeyDown(window, GLFW_KEY_LEFT_SHIFT);
    R3 = isKeyDown(window, GLFW_KEY_LEFT_CONTROL);
    
    dpadUp = isKeyDown(window, GLFW_KEY_UP);
    dpadDown = isKeyDown(window, GLFW_KEY_DOWN);
    dpadLeft = isKeyDown(window, GLFW_KEY_LEFT);
    dpadRight = isKeyDown(window, GLFW_KEY_RIGHT);
    
    L2 = isMouseButtonDown(window, GLFW_MOUSE_BUTTON_RIGHT);
    R2 = isMouseButtonDown(window, GLFW_MOUSE_BUTTON_LEFT);
    
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
    
    leftX = leftY = 0;
    if(isKeyDown(window, GLFW_KEY_A))
        leftX -= 1;
    if(isKeyDown(window, GLFW_KEY_D))
        leftX += 1;
    if(isKeyDown(window, GLFW_KEY_S))
        leftY += 1;
    if(isKeyDown(window, GLFW_KEY_W))
        leftY -= 1;
    
    prep->buttons1 = (triangle ? (1 << 7) : 0) | (O ? (1 << 6) : 0) | (X ? (1 << 5) : 0) | (square ? (1 << 4) : 0) | dpad;
    prep->buttons2 = (R3 ? (1 << 7) : 0) | (L3 ? (1 << 6) : 0) | (options ? (1 << 5) : 0) | (share ? (1 << 4) : 0) |
    (R2 ? (1 << 3) : 0) | (L2 ? (1 << 2) : 0) | (R1 ? (1 << 1) : 0) | (L1 ? (1 << 0) : 0);
    prep->buttons3 = ((ticks << 2) & 0xFF) | (touchpad ? 2 : 0) | (PS ? 1 : 0);
    prep->left_trigger = L2 ? 255 : 0;
    prep->right_trigger = R2 ? 255 : 0;
    prep->left_x = (uint8_t) fmin(fmax(128 + leftX * 128, 0), 255);
    prep->left_y = (uint8_t) fmin(fmax(128 + leftY * 128, 0), 255);
}

void processMouse(GLFWwindow * window, PSReport * prep)
{
    double xpos, ypos;
    glfwGetCursorPos(window, &xpos, &ypos);
    
    double diffx = xpos - lastMouseX;
    double diffy = ypos - lastMouseY;
    
    NSLog(@"Prep X: %0.0f Y: %0.0f", diffx, diffy);
    
    //we need to scale these values from -1 to 1
    diffx /= 15;
    diffy /= 15;
    
    
    if(diffx < 0)
        diffx = fmax(90 + diffx * 90, 0);
    else if(diffx > 0)
        diffx = fmin(163 + diffx * 92, 255);
    else
        diffx = 128;
    
    if(diffy < 0)
        diffy = fmax(90 + diffy * 90, 0);
    else if(diffy > 0)
        diffy = fmin(163 + diffy * 92, 255);
    else
        diffy = 128;
    
    prep->right_x = (uint8_t) diffx;
    prep->right_y = (uint8_t) diffy;
    
    
    
    lastMouseX = xpos;
    lastMouseY = ypos;
}

void error_callback(int error, const char* description)
{
    fprintf(stderr, "Error: %s\n", description);
}

int main(int argc, const char * argv[]) {

    lastMouseX = lastMouseY = 0;
    ticks = 0;
    PSReport * report = (PSReport *)malloc(64);
    
    sock = [[FastSocket alloc] initWithHost:@"localhost" andPort:@"5555"];
    [sock connect];
    
    glfwSetErrorCallback(error_callback);
    
    if (!glfwInit())
    {
        NSLog(@"Initialization failed");
    }
    
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 2);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 0);
    glfwWindowHint(GLFW_REFRESH_RATE, 60);
    
    GLFWwindow * window;
    window = glfwCreateWindow(640, 480, "DS4EmuWindow", NULL, NULL);
    if(!window)
    {
        NSLog(@"Unable to create window!");
    }

    glfwMakeContextCurrent(window);
    
    glfwSetInputMode(window, GLFW_CURSOR, GLFW_CURSOR_DISABLED);
    //glfwSetInputMode(window, GLFW_STICKY_KEYS, 1);
    //glfwSetInputMode(window, GLFW_STICKY_MOUSE_BUTTONS, 1);
    while (!glfwWindowShouldClose(window))
    {
        // Keep running
        
        //If the user presses backspace, close the window
        int state = glfwGetKey(window, GLFW_KEY_BACKSPACE);
        if (state == GLFW_PRESS)
            glfwSetWindowShouldClose(window, 1);
        
        memcpy(report, brep, sizeof(brep));
        parseKeys(window, report);
        processMouse(window, report);
        
        //send the controller information over the wire to be processed
        [sock sendBytes:(void *)report count:64];
        
        float ratio;
        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        ratio = width / (float) height;
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT);
        glfwSwapBuffers(window);
        glfwPollEvents();
        
        //increment our ticks for the report
        ticks++;
    }
    
    glfwTerminate();
    free(report);
    
    return 0;
}

/*
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

static void Handle_IOHIDInputValueCallback(
                                           void *          inContext,      // context from IOHIDManagerRegisterInputValueCallback
                                           IOReturn        inResult,       // completion result for the input value operation
                                           void *          inSender,       // the IOHIDManagerRef
                                           IOHIDValueRef   inIOHIDValueRef // the new element value
) {
    IOHIDElementRef elementRef = IOHIDValueGetElement(inIOHIDValueRef);
    uint32_t usage = IOHIDElementGetUsage(elementRef);
    
    CFIndex x = IOHIDValueGetIntegerValue(inIOHIDValueRef);
    
    if(usage == 48)
        printf("%d - %u: %ld\n", reportCount++, usage, x);
}

int main(int argc, char * argv[])
{
    IOHIDManagerRef managerRef = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    // Create a matching dictionary
    CFDictionaryRef matchingCFDictRef =
    hu_CreateDeviceMatchingDictionary( kHIDPage_GenericDesktop, kHIDUsage_GD_Mouse );
    
    printf("hello world\n");
    
    if ( matchingCFDictRef ) {
        // set the HID device matching dictionary
        IOHIDManagerSetDeviceMatching( managerRef, matchingCFDictRef );
    } else {
        fprintf( stderr, "%s: hu_CreateDeviceMatchingDictionary failed.", __PRETTY_FUNCTION__ );
        return -1;
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
    CFRunLoopRun();
    
    //dispatch_semaphore_wait(mySemaphore, DISPATCH_TIME_FOREVER);
    
    return 0;
}*/
