//
//  PSInfoPopupViewController.h
//  PocketSword
//
//  Hosts the WKWebView that shows Strong's entries, morph tags, footnotes,
//  cross-references and dictionary lookups in a native sheet. Replaces the
//  hand-rolled slide-up overlay that PSTabBarControllerDelegate used to build
//  in showInfo:.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface PSInfoPopupViewController : UIViewController

@property (nonatomic, strong, readonly) WKWebView *webView;

- (void)loadHTML:(NSString *)html;

@end

NS_ASSUME_NONNULL_END
