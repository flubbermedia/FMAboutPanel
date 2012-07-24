//
//  AppDelegate.m
//  Demo
//
//  Created by Maurizio Cremaschi on 7/24/12.
//  Copyright (c) 2012 Flubber Media Ltd. All rights reserved.
//

#import "AppDelegate.h"
#import "FMAboutPanel.h"

@implementation AppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    //Pre-initialize the panel
    [FMAboutPanel sharedInstance];
    
    return YES;
}

@end
