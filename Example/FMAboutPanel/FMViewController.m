//
//  FMViewController.m
//  FMAboutPanel
//
//  Created by Andrea Ottolina on 05/01/2015.
//  Copyright (c) 2014 Andrea Ottolina. All rights reserved.
//

#import "FMViewController.h"
#import "FMAboutPanel.h"

@interface FMViewController ()

@end

@implementation FMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
