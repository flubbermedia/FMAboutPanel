//
//  FMAppDelegate.m
//  FMAboutPanel
//
//  Created by CocoaPods on 05/01/2015.
//  Copyright (c) 2014 Andrea Ottolina. All rights reserved.
//

#import "FMAppDelegate.h"
#import "FMAboutPanel.h"

@implementation FMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	//Pre-initialize the panel
	[FMAboutPanel sharedInstance];
	[FMAboutPanel sharedInstance].newsletterEnabled = YES;
	[FMAboutPanel sharedInstance].newsletterApiKey = @"example";
	[FMAboutPanel sharedInstance].newsletterListID = @"example";
	[FMAboutPanel sharedInstance].supportEnabled = NO;
	
	return YES;
}

@end
