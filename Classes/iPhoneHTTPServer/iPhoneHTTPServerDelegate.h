//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import "NavigatorSources.h"

@class   HTTPServer;

@interface iPhoneHTTPServerDelegate : UIViewController
{
	HTTPServer *httpServer;
	NSDictionary *addresses;
	
	UILabel *bonjourInfo;
	UILabel *ipInfo;
	UILabel *wwwInfo;
		
}

- (void)startServer;
- (void)displayInfoUpdate:(NSNotification *) notification;

- (void)doneButtonPressed;
@end

