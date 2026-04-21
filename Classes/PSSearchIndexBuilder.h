//
//  PSSearchIndexBuilder.h
//  PocketSword
//
//  Modal sheet that builds the FTS5 search index for a module. Replaces the
//  crosswire.org-download flow that used to live in PSIndexController.
//

#import <UIKit/UIKit.h>

@class PSSearchIndexBuilder;
@class SwordModule;

NS_ASSUME_NONNULL_BEGIN

@protocol PSSearchIndexBuilderDelegate <NSObject>
- (void)indexBuilder:(PSSearchIndexBuilder *)builder didFinishWithSuccess:(BOOL)success cancelled:(BOOL)cancelled;
@end

@interface PSSearchIndexBuilder : UIViewController

@property (nonatomic, weak) id<PSSearchIndexBuilderDelegate> delegate;
@property (nonatomic, strong, readonly) SwordModule *module;

- (instancetype)initWithModule:(SwordModule *)module;

/// Presents the builder modally over `presenter` as a medium-detent sheet and
/// starts the background build.
- (void)presentFromViewController:(UIViewController *)presenter;

@end

NS_ASSUME_NONNULL_END
