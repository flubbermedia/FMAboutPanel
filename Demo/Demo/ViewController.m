//
//  ViewController.m
//  Demo
//
//  Created by Maurizio Cremaschi on 7/24/12.
//  Copyright (c) 2012 Flubber Media Ltd. All rights reserved.
//

#import "ViewController.h"
#import "FMAboutPanel.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPhone)
    {
        return interfaceOrientation == UIInterfaceOrientationPortrait;
    }
    return YES;
}

#pragma mark - Actions

- (IBAction)didTapShowPanel:(id)sender
{
    [[FMAboutPanel sharedInstance] present];
}

@end
