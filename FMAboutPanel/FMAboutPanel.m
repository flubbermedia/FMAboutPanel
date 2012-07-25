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
static NSString * const kApplicationsRemoteRequestFormat = @"?appid=%@&appversion=%@&applocale=%@&contentversion=%@";
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

@property (strong, nonatomic) NSOperationQueue *queue;
@property (strong, nonatomic) NSURLConnection *iTunesConnection;
@property (strong, nonatomic) NSURL *iTunesURL;
@property (strong, nonatomic) NSArray *applications;
@property (strong, nonatomic) NSString *applicationsPlistVersion;

@end

@implementation FMAboutPanel

@synthesize logEvent;

@synthesize box;
@synthesize darkView;
@synthesize logoImageView;
@synthesize followUsLabel;
@synthesize ourAppsLabel;
@synthesize appVersionLabel;
@synthesize infoLabel;
@synthesize facebookButton;
@synthesize twitterButton;
@synthesize websiteButton;
@synthesize newsletterButton;
@synthesize appsScrollView;
@synthesize pageControl;

@synthesize debug;
@synthesize applicationsUpdatePeriod;
@synthesize applicationsRemoteBaseURL;
@synthesize logoImageName;
@synthesize facebookWebURL;
@synthesize facebookNativeURL;
@synthesize twitterWebURL;
@synthesize twitterNativeURL;
@synthesize websiteURL;
@synthesize copyrightString;
@synthesize trackingPrefix;

@synthesize queue;
@synthesize iTunesConnection;
@synthesize iTunesURL;
@synthesize applications;
@synthesize applicationsPlistVersion;


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
		self.debug = NO;
		self.applicationsUpdatePeriod = kApplicationsUpdatePeriod;
		self.applicationsRemoteBaseURL = kApplicationsRemoteBaseURL;
		self.logoImageName = kLogoImageName;
		self.facebookWebURL = kFacebookWebURL;
		self.facebookNativeURL = kFacebookNativeURL;
		self.twitterWebURL = kTwitterWebURL;
		self.twitterNativeURL = kTwitterNativeURL;
		self.websiteURL = kWebsiteURL;
		self.copyrightString = kCopyrightText;
		self.trackingPrefix = kTrackingPrefix;
		self.logEvent = ^(NSString *event, NSDictionary *parameters)
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
	
	self.logoImageView.image = [UIImage imageNamed:self.logoImageName];

    self.followUsLabel.text = NSLocalizedString(@"Follow us", @"Flubber Panel: social title");
    self.ourAppsLabel.text = NSLocalizedString(@"Our Apps", @"Flubber Panel: our apps section title");
	
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
	self.appVersionLabel.text = versionLabelText;
	self.infoLabel.text = self.copyrightString;

    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(dismiss)];
    [self.darkView addGestureRecognizer:tapGesture];
	
	//////////////////////////////////////////////////////////////////////////////
	// Temporary disable Newsletter icon
	//
	CGAffineTransform buttonTransform = CGAffineTransformMakeTranslation(40., 0.);
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		buttonTransform = CGAffineTransformMakeTranslation(80., 0.);
	}
	self.newsletterButton.hidden = YES;
	self.facebookButton.transform = buttonTransform;
	self.twitterButton.transform = buttonTransform;
	//
	// Remove the above block to re-enable the Newsletter icon
	//////////////////////////////////////////////////////////////////////////////
}

- (void)viewDidUnload
{
    self.box = nil;
    self.darkView = nil;
    self.followUsLabel = nil;
    self.ourAppsLabel = nil;
    self.infoLabel = nil;
    self.facebookButton = nil;
    self.twitterButton = nil;
	self.websiteButton = nil;
    self.newsletterButton = nil;
    self.appsScrollView = nil;
    [super viewDidUnload];
}

- (void)viewWillAppear:(BOOL)animated
{
	[self layout];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[self cancelConnection:self.iTunesConnection];
}

- (void)layout
{
	// Clear up appsScrollView
	[[self.appsScrollView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	
	// Add updated apps icons
	CGFloat totalApps = [self.applications count];
	CGFloat appsPerPage = 4.;
	CGFloat totalPages = ceil(totalApps / appsPerPage);
	CGSize pageSize = self.appsScrollView.bounds.size;
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
	
    self.appsScrollView.contentSize = CGSizeMake(totalPages * pageSize.width, pageSize.height);
    self.pageControl.numberOfPages = totalPages;
	
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
        [self.appsScrollView addSubview:appBoxView];    
		
		if (currentIndex < totalApps)
		{
			NSDictionary *app = [self.applications objectAtIndex:currentIndex];
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
	NSString *eventString = [self.trackingPrefix lowercaseString];
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:self.applicationsPlistVersion, @"plistVersion", nil];
	self.logEvent(eventString, parameters);
	
	UIViewController *viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
	[self viewWillAppear:animated];
    [viewController.view addSubview:self.view];
	self.box.center = self.darkView.center;

	void (^animations) (void) = ^{
		self.darkView.alpha = 1.;
		self.box.transform = CGAffineTransformIdentity;
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

	self.darkView.alpha = 0.;
	NSLog(@"%@", NSStringFromCGRect(self.view.frame));
	self.box.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0., self.view.frame.size.height);
	
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
		self.darkView.alpha = 0.;
		self.box.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0., self.view.frame.size.height);
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
    NSDictionary *app = index < self.applications.count ? [self.applications objectAtIndex:index] : nil;
    	
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
	
	NSString *eventString = [NSString stringWithFormat:@"%@.apps", [self.trackingPrefix lowercaseString]];
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:[app objectForKey:kFPName], @"appName", [NSNumber numberWithBool:found], @"installed", nil];
	self.logEvent(eventString, parameters);
	
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
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.facebook", [self.trackingPrefix lowercaseString]];
	self.logEvent(eventString, nil);

    NSURL *url = [NSURL URLWithString:self.facebookNativeURL];
	if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
    {
        url = [NSURL URLWithString:self.facebookWebURL];
    }
	[[UIApplication sharedApplication] openURL:url];

}

- (IBAction)didTapTwitter:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.twitter", [self.trackingPrefix lowercaseString]];
	self.logEvent(eventString, nil);
	
	NSURL *url = [NSURL URLWithString:self.twitterNativeURL];
    if ([[UIApplication sharedApplication] canOpenURL:url] == NO)
    {
        url = [NSURL URLWithString:self.twitterWebURL];
	}
	[[UIApplication sharedApplication] openURL:url];
}

- (IBAction)didTapWebsite:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.website", [self.trackingPrefix lowercaseString]];
	self.logEvent(eventString, nil);
	
	NSURL *url = [NSURL URLWithString:self.websiteURL];
    [[UIApplication sharedApplication] openURL:url];
	
}

- (IBAction)didTapNewsletter:(id)sender
{
	NSString *eventString = [NSString stringWithFormat:@"%@.follow.newsletter", [self.trackingPrefix lowercaseString]];
	self.logEvent(eventString, nil);	
}

#pragma mark - Applications method

- (void)updateApplications
{
    NSString *appsFilePath = [[self privateDataPath] stringByAppendingPathComponent:kApplicationsLocalPlistFilename];
    NSDictionary *content = [NSDictionary dictionaryWithContentsOfFile:appsFilePath];
    self.applications = [content objectForKey:kPlistApplicationsKey];
    self.applicationsPlistVersion = [content objectForKey:@"version"];
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
	BOOL isWaitingPeriod = [[NSDate date] timeIntervalSinceDate:lastCheckDate] < self.applicationsUpdatePeriod * kSecondsInADay;
	if (debug == NO && isWaitingPeriod == YES)
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
                               self.applicationsPlistVersion
                               ];
    
    NSString *urlPath = [self.applicationsRemoteBaseURL stringByAppendingString:urlParameters];
    
    self.queue = [NSOperationQueue new];
    NSURL *url = [NSURL URLWithString:urlPath];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:self.queue 
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {                               
                               if (error == nil)
							   {
								   // Response received: update request date
								   [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kApplicationsRemoteLastCheckDateKey];
								   
								   // Check if data or old content. Server should return statusCode 204 if update is not necessary
								   NSInteger statusCode = [(NSHTTPURLResponse *)response statusCode];
								   if (data != nil && statusCode == 200)
								   {
									   [self unzipData:data];
									   [self updateApplications];
//									   dispatch_async(dispatch_get_main_queue(), ^{
//										   if ([self.view superview])
//										   {
//											   [self layout];
//										   }
//									   });
								   }
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
    self.iTunesConnection = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:referralURL] delegate:self startImmediately:YES];
	[[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
}

// Save the most recent URL in case multiple redirects occur
// "iTunesURL" is an NSURL property in your class declaration
- (NSURLRequest *)connection:(NSURLConnection *)connection willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)response
{
    self.iTunesURL = [response URL];
    if( [self.iTunesURL.host hasSuffix:@"itunes.apple.com"])
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
    [[UIApplication sharedApplication] openURL:self.iTunesURL];
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
    int currentPage = self.pageControl.currentPage;
	CGRect rect = self.appsScrollView.bounds;
	rect.origin.x = self.appsScrollView.bounds.size.width * currentPage;
	[self.appsScrollView scrollRectToVisible:rect animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    CGFloat width = scrollView.bounds.size.width;
    int currentPage = floor((scrollView.contentOffset.x - width * 0.5) / width) + 1;
	self.pageControl.currentPage = currentPage;
}


@end
