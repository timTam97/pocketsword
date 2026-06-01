//
//  PSInfoPopupViewController.mm
//  PocketSword
//

#import "PSInfoPopupViewController.h"
#import "PocketSword-Swift.h"
#import "globals.h"

@interface PSInfoPopupViewController ()
@property (nonatomic, strong, readwrite) WKWebView *webView;
@property (nonatomic, copy) NSString *pendingHTML;
@end

@implementation PSInfoPopupViewController

- (void)loadView {
	UIView *root = [[UIView alloc] initWithFrame:[PSResizing mainScreenBounds]];
	root.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	root.backgroundColor = [UIColor systemBackgroundColor];

	WKWebViewConfiguration *cfg = [[WKWebViewConfiguration alloc] init];
	WKWebView *wv = [[WKWebView alloc] initWithFrame:root.bounds configuration:cfg];
	wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	wv.backgroundColor = [UIColor systemBackgroundColor];
	wv.opaque = NO;
	// Push content below the sheet grabber so the first line of the
	// dictionary entry isn't crammed against the top edge.
	UIEdgeInsets insets = UIEdgeInsetsMake(20, 0, 0, 0);
	wv.scrollView.contentInset = insets;
	wv.scrollView.scrollIndicatorInsets = insets;
	[root addSubview:wv];

	self.webView = wv;
	self.view = root;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if(self.pendingHTML) {
		[self.webView loadHTMLString:self.pendingHTML baseURL:nil];
		self.pendingHTML = nil;
	}
}

- (void)loadHTML:(NSString *)html {
	if(!html) return;
	if(self.isViewLoaded) {
		[self.webView loadHTMLString:html baseURL:nil];
	} else {
		self.pendingHTML = html;
	}
}

@end
