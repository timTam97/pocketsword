//
//  PSAboutScreenController.mm
//  PocketSword
//
//  Created by Nic Carter on 12/11/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSAboutScreenController.h"
#import "PSModuleController.h"


@implementation PSAboutScreenController

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        // Custom initialization
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

+ (NSString*)generateAboutHTML
{

	//										

	NSString *body = [NSString stringWithFormat:
							 @"<div id=\"header\">\n\
								 <div class=\"title\">PocketSword</div>\n\
								 <div class=\"version\"> Version %@</div>\n\
								 <center><i><a href=\"http://crosswire.org/pocketsword\">http://crosswire.org/pocketsword</a></i><br />\n\
									<i><a href=\"http://www.crosswire.org/forums/mvnforum/listthreads?forum=16\">User Forums</a></i><br />\n\
									<i>@<a href=\"http://twitter.com/PocketSword\">PocketSword</a> on Twitter</i></center>\n\
							 </div>\n\
							 <div id=\"main\">\n\
								<p><b>Developed by: </b><br />\n\
									 Nic Carter<br />\n\
									 and the CrossWire team\n\
								</p>\n\
								 <p><b>With help from: </b><br />\n\
					  David Bell, \
					  Manfred Bergmann, \
					  Christoffer Björkskog, \
					  Jan Bubík, \
					  Vincenzo Carrubba, \
					  Cheree Lynley Designs, \
					  Dominique Corbex, \
					  Bruno Gätjens González, \
					  Grace Community Church (HK), \
					  Yiguang Hu, \
					  John Huss, \
					  Nakamaru Kunio, \
					  Vitaliy, \
					  Ian Wagner, \
					  Henko van de Weerd\
					  \n\
					  <br />\n\
					  &amp; all the PocketSword beta testers!\n\
							  </p>\n\
							  <p><b>Special thanks to: </b><br />\n\
										David Crowder*Band <i>(<a href=\"http://www.davidcrowderband.com/\">http://www.davidcrowderband.com/</a>)</i><br />\n\
										Pablo and Rusty's, Gordon <i>(<a href=\"http://www.pabloandrustys.com.au/\">http://www.pabloandrustys.com.au/</a>)</i>\n\
								</p>\n\
							</div>\n\
								<p>If you would like to use these same Bible & Commentary modules on another platform, check out the following apps:<br />\n\
										&bull; <i><a href=\"http://xiphos.org/\">Xiphos (Windows, Linux/Unix)</a></i><br />\n\
										&bull; <i><a href=\"https://code.google.com/p/and-bible/\">AndBible (Android)</a></i><br />\n\
										&bull; <i><a href=\"http://www.macsword.com/\">Eloquent/MacSword</a></i><br />\n\
										&bull; <i><a href=\"http://www.bibletime.info/\">BibleTime (Linux/Unix and Windows)</a></i><br />\n\
									</p>\n\
								<p>If you would like to see PocketSword in your language and are willing to help translate it, please Email Us using the button in the top right corner &amp; we would love your help!</p>\
					  \
					  \n\
					  \n\
					  <p>PocketSword takes advantage of different Open Source projects, including:<br />\n\
					  &bull; <i><a href=\"http://www.crosswire.org/sword/index.jsp\">The SWORD Project</a></i><br />\n\
					  &bull; <i><a href=\"http://code.google.com/p/cocoahttpserver/\">CocoaHTTPServer</a></i><br />\n\
					  &bull; <i><a href=\"https://github.com/zbyhoo/EGOTableViewPullRefresh\">zbyhoo's fork of EGOTableViewPullRefresh</a></i><br />\n\
					  &bull; <i><a href=\"http://code.google.com/p/ziparchive/\">ZipArchive</a></i><br />\n\
					  </p>\
					  <br />\n\
					  <br />\n\
					  <div class=\"crosswire\">\n\
					  <h2 class=\"headbar\">CrossWire Bible Society</h2>\n\
					  <p> &nbsp; &nbsp; &nbsp;The CrossWire Bible Society is an organization with the purpose to sponsor and provide a place for engineers and others to come and collaborate on free, open-source projects aimed at furthering the Kingdom of our God.  We are also a resource pool to other Bible societies and Christian organizations that can't afford-- or don't feel it's their place-- to maintain a quality programming staff in house.  We provide them with a number of tools that assist them with reaching their domain with Christ.  CrossWire is a non-income organization, which means that not only do we offer our services for free, but we also do not solicit donations to exist.  We exist because we, as a community come together and offer our services and time freely.</p>\n\
\n\
					  <p> &nbsp; &nbsp; &nbsp;The name was a pun of sorts, with the original idea that the Cross of Christ is our wire to God.  Over the years, the meaning has grown into one more appropriate to what a Bible society is.  The main purpose of a Bible Society is to distribute Scripture to as many people within a domain as possible.  Some examples are the American Bible Society, the German Bible Society, the Canadian Bible Society, the United Bible Societies-- under which most of the Bible societies of the world collaborate-- and many others.  You can view most of their stats of Scripture distribution to their region by visiting <a href=\"http://www.biblesociety.org/bs-find.htm\">http://www.biblesociety.org/bs-find.htm</a>, then selecting a region and the Bible Society that serves that region.  Instead of having a geographic domain, CrossWire's domain is software users-- predominantly the global Internet-- or anyone we can reach across the wire.  Our Scripture distribution compares with the largest of the Bible Societies listed.</p>\n\
\n\
					  <p> &nbsp; &nbsp; &nbsp;Some examples of recent collaboration include traveling to Wycliffe Bible Translators to present and counsel on strategies to open source their software, participation with the American Bible Society to realize and promote the Bible Technologies Conference (<a href=\"http://www.bibletechnologies.org\">http://www.bibletechnologies.org</a>), and subsequently, the OSIS initiative (of which the newsgroups and listservs for the working groups are hosted on our servers at <a href=\"news://bibletechnologieswg.org\">news://bibletechnologieswg.org</a>).<br /> </p>\n\
					  </div><br />&nbsp;<br />", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"]];//CFBundleShortVersionString
	
	
	return [NSString stringWithFormat: @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
			<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n\
			\"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n\
			<html dir=\"ltr\" xmlns=\"http://www.w3.org/1999/xhtml\"\n\
			xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n\
			xsi:schemaLocation=\"http://www.w3.org/MarkUp/SCHEMA/xhtml11.xsd\"\n\
			xml:lang=\"en\" >\n\
			<meta name='viewport' content='width=device-width' />\n\
			<head>\n\
			<style type=\"text/css\">\n\
			html {\n\
				-webkit-text-size-adjust: none; /* Never autoresize text */\n\
			}\n\
			body {\n\
				color: black;\n\
				background-color: white;\n\
				font-size: 11pt;\n\
				font-family: Helvetica Neue;\n\
				line-height: 130%%;\n\
			}\n\
			#header {\n\
				font-weight: bold;\n\
				border-bottom: solid 1px gray;\n\
				padding: 5px;\n\
				background-color: #D5EEF9;\n\
			}\n\
			#main {\n\
				padding: 10px;\n\
				text-align: center;\n\
			}\n\
			div.version {\n\
				font-size: 9pt;\n\
				text-align: center;\n\
			}\n\
			div.title {\n\
				font-size: 14pt;\n\
				text-align: center;\n\
			}\n\
			i {\n\
				font-size: 9pt;\n\
				font-weight: lighter;\n\
			}\n\
			div.crosswire {\n\
				font-size: 9pt;\n\
				font-weight: lighter;\n\
			}\n\
			h2.headbar {\n\
				background-color : #660000;\n\
				color : #dddddd;\n\
				font-weight : bold;\n\
				font-size:1em;\n\
				padding-left:1em;\n\
			}\n\
			</style>\n\
			</head>\n\
			<body><div>%@</div></body></html>", 
			body];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	self.navigationItem.title = NSLocalizedString(@"AboutTitle", @"About");
	self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
	[aboutWebView loadHTMLString:[PSAboutScreenController generateAboutHTML] baseURL:nil];
	aboutWebView.delegate = self;
	
	self.navigationItem.rightBarButtonItem = nil;
	//if([MFMailComposeViewController canSendMail]) {
		//UIBarButtonItem *emailUsBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refreshDownloadSource:)];
		UIBarButtonItem *emailUsBarButtonItem = [[UIBarButtonItem alloc] initWithTitle: NSLocalizedString(@"EmailUsButton", @"Email Us") style:UIBarButtonItemStyleBordered target:self action:@selector(emailFeedback:)];
		self.navigationItem.rightBarButtonItem = emailUsBarButtonItem;
		[emailUsBarButtonItem release];
	//} else {
		//what should I show here instead?
	//}
	
}

- (void)viewDidDisappear:(BOOL)animated {
	[super viewDidDisappear:animated];
	self.navigationItem.rightBarButtonItem = nil;
}

-(void)emailFeedback:(id)sender
{
    NSString *recipients = @"niccarter@mac.com";
	
	NSString *subject = [NSString stringWithFormat:@"PocketSword Feedback (v%@ - %@ %@ (%@))", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"], [[UIDevice currentDevice] systemName], [[UIDevice currentDevice] systemVersion], [[UIDevice currentDevice] model]];
	
	if([MFMailComposeViewController canSendMail]) {
		MFMailComposeViewController *mailComposeViewController = [[MFMailComposeViewController alloc] init];
		[mailComposeViewController setSubject:subject];
		[mailComposeViewController setToRecipients:[NSArray arrayWithObject:recipients]];
		mailComposeViewController.mailComposeDelegate = self;
		mailComposeViewController.navigationBar.barStyle = UIBarStyleBlack;
		[self.tabBarController presentModalViewController:mailComposeViewController animated:YES];
		[mailComposeViewController release];
		//NSString *email = [NSString stringWithFormat:@"mailto:%@?subject=%@", recipients, subject];
		 //email = [email stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
		 //[[UIApplication sharedApplication] openURL:[NSURL URLWithString:email]];
	}
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
	[self.tabBarController dismissModalViewControllerAnimated:YES];
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if(navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:[request URL]];
		return NO;
	}
	return YES;
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc {
    [super dealloc];
}


@end
