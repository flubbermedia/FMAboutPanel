//
//  FMAboutPanel.h
//
//  Created by Maurizio Cremaschi and Andrea Ottolina on 1/16/12.
//  Copyright 2012 Flubber Media Ltd.
//
//  Distributed under the permissive zlib License
//  Get the latest version from https://github.com/flubbermedia/FMAboutPanel
//
//  This software is provided 'as-is', without any express or implied
//  warranty.  In no event will the authors be held liable for any damages
//  arising from the use of this software.
//
//  Permission is granted to anyone to use this software for any purpose,
//  including commercial applications, and to alter it and redistribute it
//  freely, subject to the following restrictions:
//
//  1. The origin of this software must not be misrepresented; you must not
//  claim that you wrote the original software. If you use this software
//  in a product, an acknowledgment in the product documentation would be
//  appreciated but is not required.
//
//  2. Altered source versions must be plainly marked as such, and must not be
//  misrepresented as being the original software.
//
//  3. This notice may not be removed or altered from any source distribution.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import <MessageUI/MFMailComposeViewController.h>

typedef void (^EventTracking)(NSString *category, NSString *action, NSString *label, NSDictionary *parameters);
typedef void (^PageTracking)(NSString *page, NSDictionary *parameters);

@interface FMAboutPanel : UIViewController <NSURLConnectionDelegate, UIScrollViewDelegate, UITextFieldDelegate, UIAlertViewDelegate, MFMailComposeViewControllerDelegate>

// Tracking Block

@property (nonatomic, copy) EventTracking logEvent;
@property (nonatomic, copy) PageTracking logPresent;
@property (nonatomic, copy) PageTracking logDismiss;

// Outlet

@property (strong, nonatomic) IBOutlet UIView *box;
@property (strong, nonatomic) IBOutlet UIView *darkView;
@property (strong, nonatomic) IBOutlet UIImageView *bgImageView;
@property (strong, nonatomic) IBOutlet UIImageView *logoImageView;
@property (strong, nonatomic) IBOutlet UILabel *followUsLabel;
@property (strong, nonatomic) IBOutlet UILabel *supportLabel;
@property (strong, nonatomic) IBOutlet UILabel *ourAppsLabel;
@property (strong, nonatomic) IBOutlet UILabel *appVersionLabel;
@property (strong, nonatomic) IBOutlet UILabel *infoLabel;
@property (strong, nonatomic) IBOutlet UIButton *facebookButton;
@property (strong, nonatomic) IBOutlet UIButton *twitterButton;
@property (strong, nonatomic) IBOutlet UIButton *websiteButton;
@property (strong, nonatomic) IBOutlet UIButton *newsletterButton;
@property (strong, nonatomic) IBOutlet UIView *supportView;
@property (strong, nonatomic) IBOutlet UIButton *supportButton;
@property (strong, nonatomic) IBOutlet UIScrollView *appsScrollView;
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;

// Public

@property (assign, nonatomic) BOOL debug;
@property (assign, nonatomic) BOOL trackingPageViews;
@property (assign, nonatomic) BOOL newsletterEnabled;
@property (assign, nonatomic) BOOL newsletterDoubleOptIn;
@property (assign, nonatomic) BOOL supportEnabled;
@property (assign, nonatomic) double applicationsUpdatePeriod;
@property (strong, nonatomic) NSString *applicationsRemoteBaseURL;
@property (strong, nonatomic) NSString *logoImageName;
@property (strong, nonatomic) NSString *facebookWebURL;
@property (strong, nonatomic) NSString *facebookNativeURL;
@property (strong, nonatomic) NSString *twitterWebURL;
@property (strong, nonatomic) NSString *twitterNativeURL;
@property (strong, nonatomic) NSString *websiteURL;
@property (strong, nonatomic) NSString *newsletterApiKey;
@property (strong, nonatomic) NSString *newsletterListID;
@property (strong, nonatomic) NSString *newsletterListGroup;
@property (strong, nonatomic) NSString *newsletterListGroupOption;
@property (strong, nonatomic) NSString *supportEmail;
@property (strong, nonatomic) NSString *supportMessage;
@property (strong, nonatomic) NSString *copyrightString;
@property (strong, nonatomic) NSString *trackingPrefix;


+ (FMAboutPanel *)sharedInstance;
- (void)present;
- (void)presentAnimated:(BOOL)animated;
- (void)dismiss;
- (void)dismissAnimated:(BOOL)animated;

- (void)forceRemoteUpdate;

@end
