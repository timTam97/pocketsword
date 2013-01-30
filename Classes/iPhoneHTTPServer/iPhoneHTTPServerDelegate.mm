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
#import "ViewController.h"

@implementation iPhoneHTTPServerDelegate


- (void)viewDidLoad {
	[super viewDidLoad];
	self.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;//UIModalTransitionStyleCrossDissolve;
}


- (void)startServer
{
	//DLog(@"");
	helpInfo.text = NSLocalizedString(@"manualInstallHelp", @"");
	//NSString *root = DEFAULT_MMM_PATH;//[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	
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
	//[self displayInfoUpdate:nil];
	bonjourInfo.text = NSLocalizedString(@"MMMBonjourLoading", @"Bonjour Loading...");
	ipInfo.text = NSLocalizedString(@"MMMIPLoading", @"IP Loading...");
	[doneButton setTitle:NSLocalizedString(@"Done", @"Done") forState:UIControlStateNormal]; 
	[doneButton setTitle:NSLocalizedString(@"Done", @"Done") forState:UIControlStateHighlighted];
}

-(void)relistAddresses:(NSNotification *) notification
{
	[localhostAddresses performSelectorInBackground:@selector(list) withObject:nil];
}

-(IBAction)done:(id)sender
{
	[httpServer stop];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"LocalhostAdressesResolved" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"NewFileUploaded" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"BonjourServicePublished" object:nil];
	[httpServer release];
	//now remove ourselves from the current view...
	[navigatorSources.tabController dismissModalViewControllerAnimated:YES];
//    [UIView beginAnimations:nil context:nil];
//    [UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight
//                           forView:self.view.superview
//                             cache:YES];
//	
//    [UIView setAnimationDuration:1];
//	[self.view removeFromSuperview];
//    [UIView commitAnimations];
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

// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    if([PSResizing iPad]) {
        return [PSResizing shouldAutorotateToInterfaceOrientation:interfaceOrientation];
    } else {
        return (interfaceOrientation == UIInterfaceOrientationPortrait);
    }
}

@end
