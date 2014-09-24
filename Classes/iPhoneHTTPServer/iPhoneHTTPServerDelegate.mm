//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "iPhoneHTTPServerDelegate.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import "localhostAddresses.h"
#import "ZipArchive.h"

#import "PSModuleController.h"
#import "PSTabBarControllerDelegate.h"

@implementation iPhoneHTTPServerDelegate

- (void)loadView {
	
	//Calculate Screensize. based on http://stackoverflow.com/a/13068718
	BOOL statusBarHidden = [[UIApplication sharedApplication] isStatusBarHidden ];
	
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	
	//check if you should rotate the view, e.g. change width and height of the frame
	BOOL rotate = NO;
	if ( UIInterfaceOrientationIsLandscape( [UIApplication sharedApplication].statusBarOrientation ) ) {
		if (frame.size.width < frame.size.height) {
			rotate = YES;
		}
	}
	
	if ( UIInterfaceOrientationIsPortrait( [UIApplication sharedApplication].statusBarOrientation ) ) {
		if (frame.size.width > frame.size.height) {
			rotate = YES;
		}
	}
	
	if (rotate) {
		CGFloat tmp = frame.size.height;
		frame.size.height = frame.size.width;
		frame.size.width = tmp;
	}
	
	
	if (statusBarHidden) {
		frame.size.height -= [[UIApplication sharedApplication] statusBarFrame].size.height;
	}
	
	UIView *v = [[UIView alloc] initWithFrame: frame];
	v.backgroundColor = [UIColor lightGrayColor];
	v.autoresizingMask  = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	// help UILabel
	UILabel *helpInfo = [[UILabel alloc] initWithFrame:CGRectMake(20,20,(frame.size.width-40),248)];
	helpInfo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	helpInfo.numberOfLines = 15;
	helpInfo.font = [UIFont systemFontOfSize:14];
	helpInfo.text = NSLocalizedString(@"manualInstallHelp", @"");
	helpInfo.backgroundColor = [UIColor clearColor];
	[v addSubview:helpInfo];
	[helpInfo release];
	
	// bonjourInfo UILabel
	bonjourInfo = [[UILabel alloc] initWithFrame:CGRectMake(20,276,(frame.size.width-40),27)];
	bonjourInfo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	bonjourInfo.font = [UIFont systemFontOfSize:15];
	bonjourInfo.text = NSLocalizedString(@"MMMBonjourLoading", @"Bonjour Loading...");
	bonjourInfo.backgroundColor = [UIColor clearColor];
	[v addSubview:bonjourInfo];
	
	// ipInfo UILabel
	ipInfo = [[UILabel alloc] initWithFrame:CGRectMake(20,311,(frame.size.width-40),27)];
	ipInfo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	ipInfo.font = [UIFont systemFontOfSize:15];
	ipInfo.text = NSLocalizedString(@"MMMIPLoading", @"IP Loading...");
	ipInfo.backgroundColor = [UIColor clearColor];
	[v addSubview:ipInfo];
	
	// wwwInfo UILabel
	wwwInfo = [[UILabel alloc] initWithFrame:CGRectMake(20,346,(frame.size.width-40),27)];
	wwwInfo.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	wwwInfo.font = [UIFont systemFontOfSize:15];
	wwwInfo.backgroundColor = [UIColor clearColor];
	[v addSubview:wwwInfo];
	
	// add toolbar with the title
	UIToolbar *tbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,0,frame.size.width,44)];
	tbar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	tbar.barStyle = UIBarStyleBlack;
	UIBarButtonItem *titleButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"PreferencesModuleMaintainerModeTitle", @"") style:UIBarButtonItemStylePlain target:nil action:nil];
	UIBarButtonItem *flexLeft = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *flexRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	
	NSArray *tbarButtons = [NSArray arrayWithObjects: flexLeft, titleButton, flexRight, nil];
	[titleButton release];
	[flexLeft release];
	[flexRight release];
	tbar.items = tbarButtons;
	[v addSubview:tbar];
	[tbar release];
	
	// add toolbar to bottom, with close button.
	CGFloat yy = frame.size.height - 44;
	tbar = [[UIToolbar alloc] initWithFrame:CGRectMake(0,yy,frame.size.width,44)];
	tbar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
	tbar.barStyle = UIBarStyleBlack;
	flexLeft = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	flexRight = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"CloseButtonTitle", @"") style:UIBarButtonItemStyleBordered target:self action:@selector(doneButtonPressed)];
	tbarButtons = [NSArray arrayWithObjects: flexLeft, closeButton, flexRight, nil];
	[closeButton release];
	[flexRight release];
	[flexLeft release];
	tbar.items = tbarButtons;
	[v addSubview:tbar];
	[tbar release];
	
	self.view = v;
	[v release];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
}

- (void)startServer
{
	[[NSFileManager defaultManager] createDirectoryAtPath: DEFAULT_MMM_PATH withIntermediateDirectories: YES attributes: NULL error: NULL];
	if (![[NSFileManager defaultManager] fileExistsAtPath: DEFAULT_MMM_PATH]) {
		ALog(@"Couldn't create MMM folder: %@", DEFAULT_MMM_PATH);
	}
	httpServer = [HTTPServer new];
	[httpServer setType:@"_http._tcp."];
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:DEFAULT_MMM_PATH]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNewModule:) name:@"NewFileUploaded" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(relistAddresses:) name:@"BonjourServicePublished" object:nil];

	//start the server...
	NSError *error;
	if(![httpServer start:&error])
	{
		ALog(@"Error starting HTTP Server: %@", error);
	}
}

-(void)relistAddresses:(NSNotification *) notification
{
	[localhostAddresses performSelectorInBackground:@selector(list) withObject:nil];
}

-(void)doneButtonPressed
{
	[httpServer stop];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[httpServer release];
	httpServer = nil;
	
	//now remove ourselves from the current view...
	[self dismissModalViewControllerAnimated:YES];
}

- (void)displayInfoUpdate:(NSNotification *) notification
{
	[self performSelectorOnMainThread: @selector(_displayInfoUpdate:) withObject: notification waitUntilDone: NO];
}

- (void)_displayInfoUpdate:(NSNotification *) notification {

	if(notification) {
		[addresses release];
		addresses = [[notification object] copy];
		DLog(@"addresses: %@", addresses);
	}

	if(!addresses) {
		return;
	}
	
	UInt16 port = [httpServer port];
	
	NSString *localIP = nil;
	
	localIP = [addresses objectForKey:@"en0"];
	
	if(!localIP) {
		localIP = [addresses objectForKey:@"en1"];
	}
	
	if(!localIP) {
		localIP = [addresses objectForKey:@"en2"];
	}

	if(!localIP) {
		bonjourInfo.text = NSLocalizedString(@"WiFiNoConnection", @"");
		ipInfo.text = NSLocalizedString(@"WiFiNoConnection", @"");
	}
	else {
		bonjourInfo.text = [NSString stringWithFormat:@"Bonjour: http://%@.local:%d", [httpServer name], port];
		ipInfo.text = [NSString stringWithFormat:@"IP: http://%@:%d\n", localIP, port];
	}
	

	NSString *wwwIP = [addresses objectForKey:@"www"];

	if(wwwIP) {
		wwwInfo.text = [NSString stringWithFormat:@"Web: http://%@:%d\n", wwwIP, port];
	} else {
		wwwInfo.text = NSLocalizedString(@"WebNoIP", @"");
	}

}

- (void)viewDidUnload {
	[bonjourInfo release];
	bonjourInfo = nil;
	[ipInfo release];
	ipInfo = nil;
	[wwwInfo release];
	wwwInfo = nil;
	[super viewDidUnload];
}

- (void)dealloc {
	if(addresses)
		[addresses release];
	if(httpServer)
		[httpServer release];
    [super dealloc];
}


- (void)handleNewModule:(NSNotification *)notification {
	DLog(@"%@", [notification object]);
	//NSString *root = DEFAULT_MMM_PATH;//[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	NSString *file = [DEFAULT_MMM_PATH stringByAppendingPathComponent:[notification object]];

	[[PSModuleController defaultModuleController] installModulesFromZip:file ofType:unknown_type removeZip:YES internalModule:NO];
	
}

@end
