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

int velX;
int velY;
int mouseUpdates;
FastSocket * sock;

//currently unused, checking if sticky keys works well instead of having to maintain our own structure
static void key_callback(GLFWwindow* window, int key, int scancode, int action, int mods)
{
    if (key == GLFW_KEY_ESCAPE && action == GLFW_PRESS)
        glfwSetWindowShouldClose(window, GLFW_TRUE);
}

void error_callback(int error, const char* description)
{
    fprintf(stderr, "Error: %s\n", description);
}

int main(int argc, const char * argv[]) {

    velX = velY = 0;
    mouseUpdates = 0;
    
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
    glfwSetInputMode(window, GLFW_STICKY_KEYS, 1);
    
    while (!glfwWindowShouldClose(window))
    {
        // Keep running
        
        //first, lets get the cursor position
        double xpos, ypos;
        glfwGetCursorPos(window, &xpos, &ypos);
        NSLog(@"Cursor X: %0.5f Y: %0.5f", xpos, ypos);
        
        //then get the keys that are down
        int state = glfwGetKey(window, GLFW_KEY_E);
        if (state == GLFW_PRESS)
            glfwSetWindowShouldClose(window, 1);
        
        //send the controller information over the wire to be processed
        
        float ratio;
        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        ratio = width / (float) height;
        glViewport(0, 0, width, height);
        glClear(GL_COLOR_BUFFER_BIT);
        glfwSwapBuffers(window);
        glfwPollEvents();
    }
    
    glfwTerminate();
    
    /*glutInitDisplayMode(GLUT_RGB);
    glutInitWindowSize(300,300);
    glutCreateWindow("FPS Mouse Sample");
    glutDisplayFunc(&display);
    glutPassiveMotionFunc(&passivemotion);
    glutMotionFunc(&passivemotion);
    glutSetCursor( GLUT_CURSOR_NONE );
    glutTimerFunc(16,timerfunc,0);
    
    glfw
    glutMainLoop();*/
    
    return 0;
}
