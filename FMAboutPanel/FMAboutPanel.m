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
#import "ObjectiveZip.h"
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

static NSString * const kLogoImageName = @"flubber-panel-logo.png";
static NSString * const kFacebookWebURL = @"https://www.facebook.com/flubbermedia";
static NSString * const kFacebookNativeURL = @"fb://page/327002840656323";
static NSString * const kTwitterWebURL = @"https://twitter.com/#!/flubbermedia";
static NSString * const kTwitterNativeURL = @"twitter://user?screen_name=flubbermedia";
static NSString * const kWebsiteURL = @"http://flubbermedia.com";
static NSString * const kCopyrightText = @"Copyright © Flubber Media Ltd\nAll rights reserved";


@interface FMAboutPanel ()

@property (strong, nonatomic) NSURLConnection *iTunesConnection;
@property (strong, nonatomic) NSURL *iTunesURL;
@property (strong, nonatomic) NSArray *applications;
@property (strong, nonatomic) NSString *applicationsPlistVersion;
@property (strong, nonatomic) UIAlertView *newsletterSignupAlertView;
@property (strong, nonatomic) UITextField *newsletterSignupTextField;

@end

@implementation FMAboutPanel

+ (FMAboutPanel *)sharedInstance
{
    static FMAboutPanel *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [FMAboutPanel new];
    });
    return sharedInstance;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    // Force the nib name
    nibNameOrNil = @"FMAboutPanel~iphone";
    if (UI_USER_INTERFACE_IDIOM()==UIUserInterfaceIdiomPad)
    {
        nibNameOrNil = @"FMAboutPanel~ipad";
    }
    
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
		_newsletterEnabled = NO;
		_newsletterDoubleOptIn = NO;
		_applicationsUpdatePeriod = kApplicationsUpdatePeriod;
		_applicationsRemoteBaseURL = kApplicationsRemoteBaseURL;
		_logoImageName = kLogoImageName;
		_facebookWebURL = kFacebookWebURL;
		_facebookNativeURL = kFacebookNativeURL;
		_twitterWebURL = kTwitterWebURL;
		_twitterNativeURL = kTwitterNativeURL;
		_websiteURL = kWebsiteURL;
		_newsletterApiKey = nil;
		_newsletterListID = nil;
		_newsletterListGroup = nil;
		_newsletterListGroupOption = nil;
		_copyrightString = kCopyrightText;
		_trackingPrefix = kTrackingPrefix;
		_logEvent = ^(NSString *event, NSDictionary *parameters)
		{
			NSLog(@"Warning: Tracking Block Missing for event: %@ and parameters: %@", event, parameters);
		};
		
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
	
	_logoImageView.image = [UIImage imageNamed:_logoImageName];

	_followUsLabel.text = NSLocalizedString(@"Follow us", @"Flubber Panel: social title");
    _ourAppsLabel.text = NSLocalizedString(@"Our Apps", @"Flubber Panel: our apps section title");
	
    NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleDisplayName"];
	NSString *shortVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"];
	NSString *versionLabelText = nil;
	if (shortVersion)
	{
		versionLabelText = [NSString stringWithFormat:@"%@ v%@ (%@)", appName, shortVersion, version];
	}
	else 
	{
		versionLabelText = [NSString stringWithFormat:@"%@ v%@", appName, version];
	}
	_appVersionLabel.text = versionLabelText;
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
}

- (void)viewDidUnload
{
    _box = nil;
    _darkView = nil;
    _followUsLabel = nil;
    _ourAppsLabel = nil;
    _infoLabel = nil;
    _facebookButton = nil;
    _twitterButton = nil;
	_websiteButton = nil;
    _newsletterButton = nil;
    _appsScrollView = nil;
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
					appCover.image = [UIImage imageNamed:@"cover-launch.png"];
					break;
				}
			}
			if (appCover.image == nil)
			{
				appCover.image = [UIImage imageNamed:@"cover-download.png"];
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
	NSString *eventString = [_trackingPrefix lowercaseString];
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:_applicationsPlistVersion, @"plistVersion", nil];
	_logEvent(eventString, parameters);
	
	UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    [viewController.view addSubview:self.view];
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
	
	NSString *eventString = [NSString stringWithFormat:@"%@.apps", [_trackingPrefix lowercaseString]];
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:[app objectForKey:kFPName], @"appName", [NSNumber numberWithBool:found], @"installed", nil];
	_logEvent(eventString, parameters);
	
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
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.facebook", [_trackingPrefix lowercaseString]];
	_logEvent(eventString, nil);

    NSURL *url = [NSURL URLWithString:_facebookNativeURL];
	if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
    {
        url = [NSURL URLWithString:_facebookWebURL];
    }
	[[UIApplication sharedApplication] openURL:url];

}

- (IBAction)didTapTwitter:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.twitter", [_trackingPrefix lowercaseString]];
	_logEvent(eventString, nil);
	
	NSURL *url = [NSURL URLWithString:_twitterNativeURL];
    if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
    {
        url = [NSURL URLWithString:_twitterWebURL];
	}
	[[UIApplication sharedApplication] openURL:url];
}

- (IBAction)didTapWebsite:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.website", [_trackingPrefix lowercaseString]];
	_logEvent(eventString, nil);
	
	NSURL *url = [NSURL URLWithString:_websiteURL];
    [[UIApplication sharedApplication] openURL:url];
	
}

- (IBAction)didTapNewsletter:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.newsletter", [_trackingPrefix lowercaseString]];
	_logEvent(eventString, nil);
	
	if (!_newsletterApiKey || !_newsletterListID)
	{
		NSLog(@"Warning: Newsletter ApiKey or ListID missing");
		return;
	}
	_newsletterSignupAlertView = [[UIAlertView alloc] initWithTitle:@"Subscribe"
																message:@"Enter your email address to subscribe to our mailing list."
															   delegate:self
													  cancelButtonTitle:@"Cancel"
													  otherButtonTitles:@"Subscribe", nil ];

	_newsletterSignupAlertView.alertViewStyle = UIAlertViewStylePlainTextInput;
	
	_newsletterSignupTextField = [_newsletterSignupAlertView textFieldAtIndex:0];
	
	// Common text field properties
	_newsletterSignupTextField.delegate = self;
	_newsletterSignupTextField.placeholder = @"Email Address";
	_newsletterSignupTextField.keyboardType = UIKeyboardTypeEmailAddress;
	_newsletterSignupTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	_newsletterSignupTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	
	[_newsletterSignupAlertView show];
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
	NSString *zipContentFilePath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:kApplicationsLocalZipFilename];
	NSData *contentData = [NSData dataWithContentsOfFile:zipContentFilePath];
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
    
    ZipFile *unzipFile = nil;
    @try
    {
        //open the zip file
        unzipFile = [[ZipFile alloc] initWithFileName:tempZipDataPath mode:ZipFileModeUnzip];
    }
    @catch (NSException *exception)
    {
        //something went wrong and the file is not a zip, leave this method
        return;
    }
    
    //list the files in the zip file
    NSArray *infos = [unzipFile listFileInZipInfos];
    for (FileInZipInfo *info in infos) {
        if (![info.name hasPrefix:@"_"])
        {
            // Locate the file in the zip
            [unzipFile locateFileInZip:info.name];
            
            // Expand the file in memory
            ZipReadStream *read = [unzipFile readCurrentFileInZip];
            NSMutableData *data = [[NSMutableData alloc] initWithLength:info.length];
            [read readDataWithBuffer:data];
            [read finishedReading];
            
            // Write the file to disk
            NSString *filePath = [[self privateDataPath] stringByAppendingPathComponent:info.name];
            [data writeToFile:filePath atomically:YES];
        }
    }
    
    //close the zip file
    [unzipFile close];
    
    //delete the temporary data on disk
    [[NSFileManager defaultManager] removeItemAtPath:tempZipDataPath error:nil];
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
	NSString *alertTitle = @"You need an Internet connection to download this App";
	NSString *alertMessage = nil;
	UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle message:alertMessage delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
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
    int currentPage = _pageControl.currentPage;
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
    UIAlertView *errorAlertView = [[UIAlertView alloc] initWithTitle:@"Subscription Failed"
                                                             message:@"We couldn't subscribe you to the list. Please check your email address and try again."
                                                            delegate:nil
                                                   cancelButtonTitle:@"OK"
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

@end
