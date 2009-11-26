//
//  This class was created by Nonnus,
//  who graciously decided to share it with the CocoaHTTPServer community.
//

#import <UIKit/UIKit.h>
@class   HTTPServer;

@interface iPhoneHTTPServerDelegate : UIViewController
{
	HTTPServer *httpServer;
	NSDictionary *addresses;
	
	IBOutlet UILabel *helpInfo;
	IBOutlet UILabel *bonjourInfo;
	IBOutlet UILabel *ipInfo;
	IBOutlet UILabel *wwwInfo;
	IBOutlet id moduleTable;
	
	IBOutlet id moduleManager;
	
}

- (void)startServer;
- (void)displayInfoUpdate:(NSNotification *) notification;

//-(IBAction) startStopServer:(id)sender;

-(IBAction)done:(id)sender;
@end

