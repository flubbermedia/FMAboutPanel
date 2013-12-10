//
//  FMAboutPanel.m
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

#import "FMAboutPanel.h"
#import "ZZArchive.h"
#import "ZZArchiveEntry.h"
#import "ZZError.h"
#import <QuartzCore/QuartzCore.h>

static NSInteger const kBoxTag = 1001;

static double const kSecondsInADay = 86400.0;
static double const kApplicationsUpdatePeriod = 1;

static NSString * const kPlistApplicationsKey = @"applications";
static NSString * const kPlistAppStoreURLKey = @"appStoreURL";
static NSString * const kPlistURLSchemesKey = @"URLSchemes";
static NSString * const kFPName = @"name";
static NSString * const kFPImage = @"image";

static NSString * const kApplicationsRemoteBaseURL = @"http://services.flubbermedia.com/flubberpanel";
static NSString * const kApplicationsRemoteRequestFormat = @"?appid=%@&appversion=%@&applocale=%@&device=%@&contentversion=%@";
static NSString * const kApplicationsRemoteLastCheckDateKey = @"flubberpanel.lastcheck";
static NSString * const kApplicationsTempZipFilename = @"applications.temp.zip";
static NSString * const kApplicationsLocalZipFilename = @"applications.zip";
static NSString * const kApplicationsLocalPlistFilename = @"applications.plist";
static NSString * const kAppStoreFormat = @"itms-apps://itunes.apple.com/app/id%@";
static NSString * const kTrackingPrefix = @"page.flubberpanel";

static NSString * const kLogoImageName = @"FMAboutPanel.bundle/flubber-panel-logo.png";
static NSString * const kFacebookWebURL = @"https://www.facebook.com/flubbermedia";
static NSString * const kFacebookNativeURL = @"fb://profile/327002840656323";
static NSString * const kTwitterWebURL = @"https://twitter.com/#!/flubbermedia";
static NSString * const kTwitterNativeURL = @"twitter://user?screen_name=flubbermedia";
static NSString * const kWebsiteURL = @"http://flubbermedia.com";
static NSString * const kSupportEmail = @"support@flubbermedia.com";
static NSString * const kCopyrightText = @"Copyright © Flubber Media Ltd\nAll rights reserved";

//localization

static NSString * const kLocalizeCancel = @"Cancel";
static NSString * const kLocalizeEmailAddress = @"Email Address";
static NSString * const kLocalizesEnterEmail = @"Enter your email address to subscribe to our mailing list.";
static NSString * const kLocalizeFollowUs = @"Follow us";
static NSString * const kLocalizeOk = @"OK";
static NSString * const kLocalizeOurApps = @"Our Apps";
static NSString * const kLocalizeSubscribe = @"Subscribe";
static NSString * const kLocalizeSubscriptionFailed = @"Subscription Failed";
static NSString * const kLocalizeSupport = @"Support";
static NSString * const kLocalizeNotSubscribed = @"We couldn't subscribe you to the list. Please check your email address and try again.";
static NSString * const kLocalizeConnectionNeeded = @"You need an Internet connection to download this App";




@interface FMAboutPanel ()

@property (strong, nonatomic) NSURLConnection *iTunesConnection;
@property (strong, nonatomic) NSURL *iTunesURL;
@property (strong, nonatomic) NSArray *applications;
@property (strong, nonatomic) NSString *applicationsPlistVersion;
@property (strong, nonatomic) UIAlertView *newsletterSignupAlertView;
@property (strong, nonatomic) UITextField *newsletterSignupTextField;

@property (strong, nonatomic) NSString *textAppVersion;
@property (strong, nonatomic) NSString *textPanelFollow;
@property (strong, nonatomic) NSString *textPanelSupport;
@property (strong, nonatomic) NSString *textPanelApps;
@property (strong, nonatomic) NSString *textPanelAppsAlertNoConnection;
@property (strong, nonatomic) NSString *textPanelAppsAlertDismiss;
@property (strong, nonatomic) NSString *textNewsletterSubscribeAlertTitle;
@property (strong, nonatomic) NSString *textNewsletterSubscribeAlertMessage;
@property (strong, nonatomic) NSString *textNewsletterSubscribeAlertButtonSubscribe;
@property (strong, nonatomic) NSString *textNewsletterSubscribeAlertButtonDismiss;
@property (strong, nonatomic) NSString *textNewsletterSubscribeAlertFieldPlaceholder;
@property (strong, nonatomic) NSString *textNewsletterFailAlertTitle;
@property (strong, nonatomic) NSString *textNewsletterFailAlertMessage;
@property (strong, nonatomic) NSString *textNewsletterFailAlertDismiss;

@end

@implementation FMAboutPanel

+ (FMAboutPanel *)sharedInstance
{
	static FMAboutPanel *sharedInstance = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
        
        //nib name
        NSString *nibName = @"FMAboutPanel~iphone";
        if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad)
            nibName = @"FMAboutPanel~ipad";
        
        //bundle
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:NSStringFromClass([self class]) ofType:@"bundle"];
        NSBundle *bundle = [NSBundle bundleWithPath:bundlePath];
        
		sharedInstance = [[FMAboutPanel alloc] initWithNibName:nibName bundle:bundle];
        
	});
	return sharedInstance;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{	
	//check if the zip pack exists
    BOOL localZipExists = NO;
    localZipExists = [[NSFileManager defaultManager] fileExistsAtPath:[self localZipContentFilePath]];
    NSAssert(localZipExists, @"FMAboutPanel couldn't find the applications.zip file");
	
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self)
	{
		//register for iphone application events
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(applicationLaunched:)
													 name:UIApplicationDidFinishLaunchingNotification
												   object:nil];
		
		if (&UIApplicationWillEnterForegroundNotification)
		{
			[[NSNotificationCenter defaultCenter] addObserver:self
													 selector:@selector(applicationWillEnterForeground:)
														 name:UIApplicationWillEnterForegroundNotification
													   object:nil];
		}
		
		// set defaults
		_debug = NO;
		_trackingPageViews = NO;
		_newsletterEnabled = NO;
		_newsletterDoubleOptIn = NO;
		_supportEnabled = NO;
		_applicationsUpdatePeriod = kApplicationsUpdatePeriod;
		_applicationsRemoteBaseURL = kApplicationsRemoteBaseURL;
		_logoImageName = kLogoImageName;
		_facebookWebURL = kFacebookWebURL;
		_facebookNativeURL = kFacebookNativeURL;
		_twitterWebURL = kTwitterWebURL;
		_twitterNativeURL = kTwitterNativeURL;
		_websiteURL = kWebsiteURL;
		_supportEmail = kSupportEmail;
		_newsletterApiKey = nil;
		_newsletterListID = nil;
		_newsletterListGroup = nil;
		_newsletterListGroupOption = nil;
		_copyrightString = kCopyrightText;
		_trackingPrefix = kTrackingPrefix;
		_logEvent = ^(NSString *category, NSString *action, NSString *label, NSDictionary *parameters)
		{
			NSLog(@"*** Warning: Tracking Block Missing for event category:%@|action:%@|label:%@|parameters:%@", category, action, label, parameters);
		};
		_logPage = ^(NSString *page, NSDictionary *parameters)
		{
			NSLog(@"*** Warning: Tracking Block Missing for page:%@|parameters:%@", page, parameters);
		};
		
		// text
		_textPanelFollow = [self localizedStringForKey:kLocalizeFollowUs];
		_textPanelSupport = [self localizedStringForKey:kLocalizeSupport];
		_textPanelApps = [self localizedStringForKey:kLocalizeOurApps];
		_textPanelAppsAlertNoConnection = [self localizedStringForKey:kLocalizeConnectionNeeded];
		_textPanelAppsAlertDismiss = [self localizedStringForKey:kLocalizeOk];
		_textNewsletterSubscribeAlertTitle = [self localizedStringForKey:kLocalizeSubscribe];
		_textNewsletterSubscribeAlertMessage = [self localizedStringForKey:kLocalizesEnterEmail];
		_textNewsletterSubscribeAlertButtonSubscribe = [self localizedStringForKey:kLocalizeSubscribe];
		_textNewsletterSubscribeAlertButtonDismiss = [self localizedStringForKey:kLocalizeCancel];
		_textNewsletterSubscribeAlertFieldPlaceholder = [self localizedStringForKey:kLocalizeEmailAddress];
		_textNewsletterFailAlertTitle = [self localizedStringForKey:kLocalizeSubscriptionFailed];
		_textNewsletterFailAlertMessage = [self localizedStringForKey:kLocalizeNotSubscribed];
		_textNewsletterFailAlertDismiss = [self localizedStringForKey:kLocalizeOk];
		
		// initialize local data
		if ([self shouldLoadApplicationsLocalData])
		{
			[self loadApplicationsLocalData];
		}
		
		[self updateApplications];
		
	}	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	UIEdgeInsets bgInset = UIEdgeInsetsMake(310, 0, 20, 0);
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		bgInset = UIEdgeInsetsMake(620, 0, 40, 0);
	}
	_bgImageView.image = [_bgImageView.image resizableImageWithCapInsets:bgInset];
	_logoImageView.image = [UIImage imageNamed:_logoImageName];
	
	_followUsLabel.text = _textPanelFollow;
	_supportLabel.text = _textPanelSupport;
	_ourAppsLabel.text = _textPanelApps;
	
	NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
	NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
    NSString *debug = @"";
#if DEBUG
    debug = @" #DEBUG";
#endif
    
	if (shortVersion)
	{
		_textAppVersion = [NSString stringWithFormat:@"%@ v%@ (%@)%@", appName, shortVersion, version, debug];
	}
	else
	{
		_textAppVersion = [NSString stringWithFormat:@"%@ v%@%@", appName, version, debug];
	}
	_appVersionLabel.text = _textAppVersion;
	_infoLabel.text = _copyrightString;
	
	UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
	[_darkView addGestureRecognizer:tapGesture];
	
	if (_newsletterEnabled == NO)
	{
		CGAffineTransform buttonTransform = CGAffineTransformMakeTranslation(40., 0.);
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
		{
			buttonTransform = CGAffineTransformMakeTranslation(80., 0.);
		}
		_newsletterButton.hidden = YES;
		_facebookButton.transform = buttonTransform;
		_twitterButton.transform = buttonTransform;
	}
	
	_supportView.hidden = !_supportEnabled;
	[_supportButton setTitle:_supportEmail forState:UIControlStateNormal];
	if (_supportEnabled == YES)
	{
		_box.frame = CGRectInset(_box.frame, 0.0, -CGRectGetHeight(_supportView.frame) * 0.5);
	}
	
}

- (void)viewDidUnload
{
	_box = nil;
	_darkView = nil;
	_bgImageView = nil;
	_logoImageView = nil;
	_followUsLabel = nil;
	_supportLabel = nil;
	_ourAppsLabel = nil;
	_infoLabel = nil;
	_facebookButton = nil;
	_twitterButton = nil;
	_websiteButton = nil;
	_newsletterButton = nil;
	_supportView = nil;
	_supportButton = nil;
	_appsScrollView = nil;
	_pageControl = nil;
	[super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self layout];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[self cancelConnection:_iTunesConnection];
}

- (void)layout
{	
	// Clear up appsScrollView
	[[_appsScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	// Add updated apps icons
	CGFloat totalApps = [_applications count];
	CGFloat appsPerPage = 4.;
	CGFloat totalPages = ceil(totalApps / appsPerPage);
	CGSize pageSize = _appsScrollView.bounds.size;
	CGFloat totalWithPlaceholders = totalPages * appsPerPage;
	
	UIFont *labelFont = [UIFont boldSystemFontOfSize:9.];
	
	CGRect boxFrame = CGRectMake(0., 0., 52., 52.);
	CGFloat boxBorderWidth = 1.;
	CGFloat boxCornerRadius = 10.;
	
	CGRect labelFrame = CGRectMake(-1., 56., 54., 12.);
	CGSize pageOffset = CGSizeMake(7., 10.);
	CGSize appOffset = CGSizeMake(6., 0.);
	CGSize shadowOffset = CGSizeMake(0., 1.);
	
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		labelFont = [UIFont boldSystemFontOfSize:18.];
		
		boxFrame = CGRectMake(0., 0., 104., 104.);
		boxBorderWidth = 2.;
		boxCornerRadius = 20.;
		
		labelFrame = CGRectMake(-2., 112., 108., 24.);
		pageOffset = CGSizeMake(14., 20.);
		appOffset = CGSizeMake(12., 0.);
		shadowOffset = CGSizeMake(0., 2.);
	}
	
	_appsScrollView.contentSize = CGSizeMake(totalPages * pageSize.width, pageSize.height);
	_pageControl.numberOfPages = totalPages;
	
	for (int currentIndex = 0; currentIndex < totalWithPlaceholders; currentIndex++)
	{
		CGFloat currentPage = floor(currentIndex / appsPerPage);
		CGFloat currentIndexPerPage = fmod(currentIndex, appsPerPage);
		
		CGRect appBoxFrame = CGRectOffset(boxFrame, pageOffset.width + currentPage * pageSize.width + currentIndexPerPage * (boxFrame.size.width + appOffset.width), pageOffset.height);
		UIView *appBoxView = [[UIView alloc] initWithFrame:appBoxFrame];
		appBoxView.layer.borderWidth = boxBorderWidth;
		appBoxView.layer.cornerRadius = boxCornerRadius;
		appBoxView.layer.borderColor = [UIColor colorWithRed:22./255. green:22./255. blue:22./255. alpha:1.].CGColor;
		appBoxView.backgroundColor = [UIColor colorWithRed:51./255. green:51./255. blue:52./255. alpha:1.];
		[_appsScrollView addSubview:appBoxView];
		
		if (currentIndex < totalApps)
		{
			NSDictionary *app = [_applications objectAtIndex:currentIndex];
			appBoxView.tag = kBoxTag + currentIndex;
			
			//app image
			NSString *imagePath = [[self privateDataPath] stringByAppendingPathComponent:[app objectForKey:kFPImage]];
			UIImage *appImage = [UIImage imageWithContentsOfFile:imagePath];
			UIButton *appButton = [[UIButton alloc] initWithFrame:CGRectInset(boxFrame, boxBorderWidth, boxBorderWidth)];
			[appButton setImage:appImage forState:UIControlStateNormal];
			[appButton addTarget:self action:@selector(didTapApp:) forControlEvents:UIControlEventTouchUpInside];
			appButton.layer.cornerRadius = boxCornerRadius;
			appButton.layer.masksToBounds = YES;
			[appBoxView addSubview:appButton];
			
			//name label
			UILabel *appLabel = [[UILabel alloc] initWithFrame:labelFrame];
			appLabel.font = labelFont;
			appLabel.text = [app objectForKey:kFPName];
			appLabel.textAlignment = UITextAlignmentCenter;
			appLabel.textColor = [UIColor colorWithRed:153./255. green:153./255. blue:153./255. alpha:1.];
			appLabel.shadowColor = [UIColor colorWithRed:0. green:0. blue:0. alpha:0.75];
			appLabel.shadowOffset = shadowOffset;
			appLabel.backgroundColor = [UIColor clearColor];
			[appBoxView addSubview:appLabel];
			
			//app cover
			UIImageView *appCover = [[UIImageView alloc] initWithFrame:CGRectInset(appBoxView.bounds, appBoxView.layer.borderWidth, appBoxView.layer.borderWidth)];
			NSArray *URLSchemes = [app objectForKey:kPlistURLSchemesKey];
			for (NSString *URLScheme in URLSchemes)
			{
				NSURL *url = [NSURL URLWithString:URLScheme];
				if ([[UIApplication sharedApplication] canOpenURL:url])
				{
					appCover.image = [UIImage imageNamed:@"FMAboutPanel.bundle/cover-launch.png"];
					break;
				}
			}
			if (appCover.image == nil)
			{
				appCover.image = [UIImage imageNamed:@"FMAboutPanel.bundle/cover-download.png"];
			}
			[appBoxView addSubview:appCover];
		}
	}
}

#pragma mark - Rotation

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return [[UIApplication sharedApplication].keyWindow.rootViewController shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

#pragma mark - Public methods

- (void)present
{
	[self presentAnimated:YES];
}

- (void)presentAnimated:(BOOL)animated
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = nil;
	NSString *eventLabel = nil;
	NSDictionary *eventParameters = [NSDictionary dictionaryWithObjectsAndKeys:_applicationsPlistVersion, @"plistVersion", nil];
	if (_trackingPageViews)
	{
		_logPage(eventCategory, eventParameters);
	}
	else
	{
		_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	}
	
	UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
	[viewController.view addSubview:self.view];
	self.view.frame = viewController.view.bounds;
	// needs to be called after adding the view, otherwise subviews won't have any frame set.
	[self viewWillAppear:animated];
	_box.center = _darkView.center;
	
	void (^animations) (void) = ^{
		_darkView.alpha = 1.;
		_box.transform = CGAffineTransformIdentity;
	};
	
	void (^completion) (BOOL) = ^(BOOL finished){
		self.view.layer.shouldRasterize = NO;
		[self viewDidAppear:animated];
	};
	
	// there's a problem with animateWithDuration when you give it 0.
	self.view.layer.shouldRasterize = YES;
	if (animated == NO)
	{
		animations();
		completion(YES);
		return;
	}
	
	_darkView.alpha = 0.;
	_box.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0., self.view.frame.size.height);
	
	[UIView animateWithDuration:.3
					 animations:animations
					 completion:completion];
}

- (void)dismiss
{
	[self dismissAnimated:YES];
}

- (void)dismissAnimated:(BOOL)animated
{
	[self viewWillDisappear:animated];
	
	//dismiss the support email panel if showed
	[self dismissModalViewControllerAnimated:animated];
	
	void (^animations) (void) = ^{
		_darkView.alpha = 0.;
		_box.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0., self.view.frame.size.height);
	};
	
	void (^completion) (BOOL) = ^(BOOL finished){
		self.view.layer.shouldRasterize = NO;
		[self.view removeFromSuperview];
		[self viewDidDisappear:animated];
	};
	
	// there's a problem with animateWithDuration when you give it 0.
	self.view.layer.shouldRasterize = YES;
	if (animated == NO)
	{
		animations();
		completion(YES);
		return;
	}
	
	[UIView animateWithDuration:.3
					 animations:animations
					 completion:completion];
}

#pragma mark - Actions

- (IBAction)didTapClose:(id)sender
{
	[self dismiss];
}

- (IBAction)didTapApp:(id)sender
{
	
	NSInteger index = [[(UIButton*)sender superview] tag] - kBoxTag;
	NSDictionary *app = index < _applications.count ? [_applications objectAtIndex:index] : nil;
	
	//check if the app is installed
	BOOL found = NO;
	NSURL *url = nil;
	NSArray *URLSchemes = [app objectForKey:kPlistURLSchemesKey];
	for (NSString *URLScheme in URLSchemes)
	{
		url = [NSURL URLWithString:URLScheme];
		
		if ([[UIApplication sharedApplication] canOpenURL:url])
		{
			found = YES;
			break;
		}
	}
	
	if (found == NO)
	{
		//NSString *urlPath = [NSString stringWithFormat:kAppStoreFormat, [app objectForKey:kFPAppStoreID]];
		NSString *urlPath = [app objectForKey:kPlistAppStoreURLKey];
		url = [NSURL URLWithString:urlPath];
	}
	
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"apps";
	NSString *eventLabel = nil;
	NSDictionary *eventParameters = [NSDictionary dictionaryWithObjectsAndKeys:[app objectForKey:kFPName], @"appName", [NSNumber numberWithBool:found], @"installed", nil];
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	// This must be called after analitycs/tracking calls
	if (found)
	{
		//open the installed app
		[[UIApplication sharedApplication] openURL:url];
	}
	else
	{
		//open the appstore link
		[self openReferralURL:url];
	}
}

- (IBAction)didTapFacebook:(id)sender
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"follow";
	NSString *eventLabel = @"facebook";
	NSDictionary *eventParameters = nil;
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	NSURL *url = [NSURL URLWithString:_facebookNativeURL];
	if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
	{
		url = [NSURL URLWithString:_facebookWebURL];
	}
	[[UIApplication sharedApplication] openURL:url];
	
}

- (IBAction)didTapTwitter:(id)sender
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"follow";
	NSString *eventLabel = @"twitter";
	NSDictionary *eventParameters = nil;
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	NSURL *url = [NSURL URLWithString:_twitterNativeURL];
	if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
	{
		url = [NSURL URLWithString:_twitterWebURL];
	}
	[[UIApplication sharedApplication] openURL:url];
}

- (IBAction)didTapWebsite:(id)sender
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"follow";
	NSString *eventLabel = @"website";
	NSDictionary *eventParameters = nil;
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	NSURL *url = [NSURL URLWithString:_websiteURL];
	[[UIApplication sharedApplication] openURL:url];
	
}

- (IBAction)didTapNewsletter:(id)sender
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"follow";
	NSString *eventLabel = @"newsletter";
	NSDictionary *eventParameters = nil;
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	if (!_newsletterApiKey || !_newsletterListID)
	{
		NSLog(@"Warning: Newsletter ApiKey or ListID missing");
		return;
	}
	_newsletterSignupAlertView = [[UIAlertView alloc] initWithTitle:_textNewsletterSubscribeAlertTitle
															message:_textNewsletterSubscribeAlertMessage
														   delegate:self
												  cancelButtonTitle:_textNewsletterSubscribeAlertButtonDismiss
												  otherButtonTitles:_textNewsletterSubscribeAlertButtonSubscribe, nil ];
	
	_newsletterSignupAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	
	_newsletterSignupTextField = [_newsletterSignupAlertView textFieldAtIndex:0];
	
	// Common text field properties
	_newsletterSignupTextField.delegate = self;
	_newsletterSignupTextField.placeholder = _textNewsletterSubscribeAlertFieldPlaceholder;
	_newsletterSignupTextField.keyboardType = UIKeyboardTypeEmailAddress;
	_newsletterSignupTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	_newsletterSignupTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	
	[_newsletterSignupAlertView show];
}

- (IBAction)didTapSupport:(id)sender
{
	NSString *eventCategory = [_trackingPrefix lowercaseString];
	NSString *eventAction = @"support";
	NSString *eventLabel = nil;
	NSDictionary *eventParameters = nil;
	_logEvent(eventCategory, eventAction, eventLabel, eventParameters);
	
	if ([MFMailComposeViewController canSendMail])
	{
		NSArray *toRecipients = [NSArray arrayWithObject:_supportEmail];
		NSString *subject = [self localizedStringForKey:kLocalizeSupport];
		subject = [subject stringByAppendingFormat:@": %@", _textAppVersion];
		MFMailComposeViewController* mailController = [[MFMailComposeViewController alloc] init];
		[mailController setToRecipients:toRecipients];
		[mailController setSubject:subject];
		[mailController setMailComposeDelegate:self];
		[mailController setMessageBody:_supportMessage isHTML:NO];
		[self presentViewController:mailController animated:YES completion:nil];
	}
	else
	{
		NSString *toRecipients = _supportEmail;
		NSString *email = [NSString stringWithFormat:@"mailto:%@" , toRecipients];
		email = [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:email]];
	}
}

#pragma mark - Applications method

- (void)updateApplications
{
	NSString *appsFilePath = [[self privateDataPath] stringByAppendingPathComponent:kApplicationsLocalPlistFilename];
	NSDictionary *content = [NSDictionary dictionaryWithContentsOfFile:appsFilePath];
	_applications = [content objectForKey:kPlistApplicationsKey];
	_applicationsPlistVersion = [content objectForKey:@"version"];
}

- (BOOL)shouldLoadApplicationsLocalData
{
	NSString *appsFilePath = [[self privateDataPath] stringByAppendingPathComponent:kApplicationsLocalPlistFilename];
	if ([[NSFileManager defaultManager] fileExistsAtPath:appsFilePath])
	{
		//there's already a file
		return NO;
	}
	//missing files, copy over from bundle
	return YES;
}

- (void)loadApplicationsLocalData
{
	NSData *contentData = [NSData dataWithContentsOfFile:[self localZipContentFilePath]];
	[self unzipData:contentData];
}

- (BOOL)shouldLoadApplicationsRemoteData
{
	NSDate *lastCheckDate = [[NSUserDefaults standardUserDefaults] objectForKey:kApplicationsRemoteLastCheckDateKey];
	BOOL isWaitingPeriod = [[NSDate date] timeIntervalSinceDate:lastCheckDate] < _applicationsUpdatePeriod * kSecondsInADay;
	if (_debug == NO && isWaitingPeriod == YES)
	{
		return NO;
	}
	return YES;
}

- (void)loadApplicationsRemoteData
{
	//start downloading the remote applications.plist
	
	NSString *urlParameters = [NSString stringWithFormat:kApplicationsRemoteRequestFormat,
							   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleIdentifier"],
							   [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
							   [[NSLocale currentLocale] objectForKey:NSLocaleLanguageCode],
							   [[UIDevice currentDevice] model],
							   _applicationsPlistVersion
							   ];
	
	urlParameters = [urlParameters stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
	NSString *urlPath = [_applicationsRemoteBaseURL stringByAppendingString:urlParameters];
	
	NSURL *url = [NSURL URLWithString:urlPath];
	NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:20];
	[NSURLConnection sendAsynchronousRequest:request
									   queue:[NSOperationQueue new]
						   completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
							   if (error == nil)
							   {
								   // Response received: update request date
								   [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kApplicationsRemoteLastCheckDateKey];
								   
								   // Check if data or old content. Server should return statusCode 204 if update is not necessary
								   NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
								   
								   // Check the content-type header
								   NSString *contentTypeValue = nil;
								   NSDictionary *headers = [(NSHTTPURLResponse *)response allHeaderFields];
								   for (NSString *headerKey in [headers allKeys])
								   {
									   if ([@"content-type" caseInsensitiveCompare:headerKey] == NSOrderedSame)
									   {
										   contentTypeValue = [[headers valueForKey:headerKey] lowercaseString];
									   }
								   }
								   
								   if (data != nil && statusCode == 200 && [contentTypeValue isEqualToString:@"application/zip"])
								   {
									   [self unzipData:data];
									   [self updateApplications];
								   }
							   }
							   else
							   {
								   //NSLog(@"Error: %@", [error localizedDescription]);
							   }
						   }];
}

- (void)unzipData:(NSData *)zipData
{
	//write temporary the data to disk
	NSString *tempZipDataPath = [[self privateDataPath] stringByAppendingPathComponent:kApplicationsTempZipFilename];
	[zipData writeToFile:tempZipDataPath atomically:YES];
	
	ZZArchive *unzipFile = nil;
	@try
	{
		//open the zip file
		unzipFile = [ZZArchive archiveWithContentsOfURL:[NSURL fileURLWithPath:tempZipDataPath]];
	}
	@catch (NSException *exception)
	{
		//something went wrong and the file is not a zip, leave this method
		return;
	}
	
	NSArray *files = unzipFile.entries;
	for (ZZArchiveEntry *file in files)
	{
		if (![file.fileName hasPrefix:@"_"])
		{
			NSLog(@"%@", file.fileName);
			NSString *filePath = [[self privateDataPath] stringByAppendingPathComponent:file.fileName];
			[file.data writeToFile:filePath atomically:YES];
		}
	}
	
	//delete the temporary data on disk
	[[NSFileManager defaultManager] removeItemAtPath:tempZipDataPath error:nil];
}

- (NSString *)localZipContentFilePath
{
    return [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:kApplicationsLocalZipFilename];
}

- (NSString *)privateDataPath
{
	//application support folder
	NSString *folder = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject];
	
	//create the folder if it doesn't exist
	if (![[NSFileManager defaultManager] fileExistsAtPath:folder])
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
	}
	
	return folder;
}

#pragma mark - Application notifications

- (void)applicationLaunched:(NSNotification *)notification
{
	if ([self shouldLoadApplicationsRemoteData])
	{
		[self loadApplicationsRemoteData];
	}
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
	if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground)
	{
		if ([self shouldLoadApplicationsRemoteData])
		{
			[self loadApplicationsRemoteData];
		}
		// This control checks if the panel is displayed when coming back from background
		// and in this case it refresh the content
		if ([self.view superview])
		{
			// Refresh view if it's displayed on screen
			[self layout];
		}
	}
}

#pragma mark - Force Remote update - Public method

- (void)forceRemoteUpdate
{
	if ([self shouldLoadApplicationsRemoteData])
	{
		[self loadApplicationsRemoteData];
	}
}

#pragma mark - App Store Affiliate links utilities

- (void)openReferralURL:(NSURL *)referralURL
{
	_iTunesConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:referralURL] delegate:self startImmediately:YES];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

// Save the most recent URL in case multiple redirects occur
// "iTunesURL" is an NSURL property in your class declaration
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
	_iTunesURL = [response URL];
	if( [_iTunesURL.host hasSuffix:@"itunes.apple.com"])
	{
		[self cancelConnection:connection];
		[self connectionDidFinishLoading:connection];
		return nil;
	}
	else
	{
		return request;
	}
}

// No more redirects; use the last URL saved
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[[UIApplication sharedApplication] openURL:_iTunesURL];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSString *alertTitle = _textPanelAppsAlertNoConnection;
	NSString *alertMessage = nil;
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMessage delegate:nil cancelButtonTitle:_textPanelAppsAlertDismiss otherButtonTitles:nil];
	[alertView show];
	[self cancelConnection:connection];
}

- (void)cancelConnection:(NSURLConnection *)connection
{
	[connection cancel];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
}

#pragma mark Page Control

- (IBAction)didTapPageControl:(id)sender
{
	NSInteger currentPage = _pageControl.currentPage;
	CGRect rect = _appsScrollView.bounds;
	rect.origin.x = _appsScrollView.bounds.size.width * currentPage;
	[_appsScrollView scrollRectToVisible:rect animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	CGFloat width = scrollView.bounds.size.width;
	int currentPage = floor((scrollView.contentOffset.x - width * 0.5) / width) + 1;
	_pageControl.currentPage = currentPage;
}

#pragma mark - ChimpKit Delegate Methods

- (void)showSubscribeError {
	UIAlertView *errorAlertView = [[UIAlertView alloc] initWithTitle:_textNewsletterFailAlertTitle
															 message:_textNewsletterFailAlertMessage
															delegate:nil
												   cancelButtonTitle:_textNewsletterFailAlertDismiss
												   otherButtonTitles:nil];
	[errorAlertView show];
}

- (void)ckRequestSucceeded:(ChimpKit *)ckRequest {
	if (![ckRequest.responseString isEqualToString:@"true"]) {
		[self showSubscribeError];
	}
}

- (void)ckRequestFailed:(NSError *)error {
	[self showSubscribeError];
}

#pragma mark - Mail Delegate

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error
{
	[controller dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - ChimpKit

- (void)chimpKitSubscribe
{
	NSMutableDictionary *params = [NSMutableDictionary dictionary];
	[params setValue:@"true" forKey:@"update_existing"];
	[params setValue:_newsletterListID forKey:@"id"];
	[params setValue:_newsletterSignupTextField.text forKey:@"email_address"];
	[params setValue:(_newsletterDoubleOptIn ? @"true" : @"false") forKey:@"double_optin"];
	if (_newsletterListGroup && _newsletterListGroupOption)
	{
		NSArray *grouping = [NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
													  _newsletterListGroup, @"name",
													  _newsletterListGroupOption, @"groups", nil]
							 ];
		
		NSMutableDictionary *mergeVars = [NSMutableDictionary dictionary];
		[mergeVars setValue:grouping forKey:@"GROUPINGS"];
		
		[params setValue:mergeVars forKey:@"merge_vars"];
		[params setValue:@"false" forKey:@"replace_interests"];
	}
	ChimpKit *chimpKit = [[ChimpKit alloc] initWithDelegate:self andApiKey:_newsletterApiKey];
	[chimpKit callApiMethod:@"listSubscribe" withParams:params];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView == _newsletterSignupAlertView && buttonIndex == 1)
	{
		// Subscribe pressed
		[self chimpKitSubscribe];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)aTextField
{
	if (aTextField == _newsletterSignupTextField)
	{        
		[_newsletterSignupAlertView dismissWithClickedButtonIndex:1 animated:YES];
		return NO;
	}
	return YES;
}

#pragma mark - Localization

- (NSString *)localizedStringForKey:(NSString *)key
{
    return [self localizedStringForKey:key withDefault:key];
}

- (NSString *)localizedStringForKey:(NSString *)key withDefault:(NSString *)defaultString
{
    static NSBundle *bundle = nil;
    if (bundle == nil)
    {
        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:NSStringFromClass([self class]) ofType:@"bundle"];
        bundle = [NSBundle bundleWithPath:bundlePath] ?: [NSBundle mainBundle];
//        if (self.useAllAvailableLanguages)
//        {
//            //manually select the desired lproj folder
//            for (NSString *language in [NSLocale preferredLanguages])
//            {
//                if ([[bundle localizations] containsObject:language])
//                {
//                    bundlePath = [bundle pathForResource:language ofType:@"lproj"];
//                    bundle = [NSBundle bundleWithPath:bundlePath];
//                    break;
//                }
//            }
//        }
    }
    defaultString = [bundle localizedStringForKey:key value:defaultString table:nil];
    return [[NSBundle mainBundle] localizedStringForKey:key value:defaultString table:nil];
}

@end
