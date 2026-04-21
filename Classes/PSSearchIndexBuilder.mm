//
//  PSSearchIndexBuilder.mm
//  PocketSword
//

#import "PSSearchIndexBuilder.h"
#import "PSSearchEngine.h"
#import "SwordModule.h"
#import "globals.h"

@interface PSSearchIndexBuilder () {
	volatile BOOL _cancelRequested;
	UIBackgroundTaskIdentifier _bgTask;
}
@property (nonatomic, strong, readwrite) SwordModule *module;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *moduleLabel;
@property (nonatomic, strong) UIProgressView *progressView;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, assign) BOOL buildFinished;
@end

@implementation PSSearchIndexBuilder

- (instancetype)initWithModule:(SwordModule *)module {
	self = [super init];
	if(self) {
		_module = module;
		_bgTask = UIBackgroundTaskInvalid;
		self.modalPresentationStyle = UIModalPresentationPageSheet;
		self.modalInPresentation = YES; // disallow pull-to-dismiss mid-build
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.view.backgroundColor = [UIColor systemBackgroundColor];

	UIStackView *stack = [[UIStackView alloc] init];
	stack.translatesAutoresizingMaskIntoConstraints = NO;
	stack.axis = UILayoutConstraintAxisVertical;
	stack.spacing = 16;
	stack.alignment = UIStackViewAlignmentFill;
	[self.view addSubview:stack];

	self.titleLabel = [[UILabel alloc] init];
	self.titleLabel.text = NSLocalizedString(@"SearchBuildingIndexTitle", @"Building search index…");
	self.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
	self.titleLabel.textAlignment = NSTextAlignmentCenter;
	[stack addArrangedSubview:self.titleLabel];

	self.moduleLabel = [[UILabel alloc] init];
	self.moduleLabel.text = self.module.name;
	self.moduleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
	self.moduleLabel.textColor = [UIColor secondaryLabelColor];
	self.moduleLabel.textAlignment = NSTextAlignmentCenter;
	[stack addArrangedSubview:self.moduleLabel];

	self.progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
	[stack addArrangedSubview:self.progressView];

	self.cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
	[self.cancelButton setTitle:NSLocalizedString(@"CancelButtonTitle", @"Cancel") forState:UIControlStateNormal];
	[self.cancelButton addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
	[stack addArrangedSubview:self.cancelButton];

	[NSLayoutConstraint activateConstraints:@[
		[stack.leadingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.leadingAnchor constant:8],
		[stack.trailingAnchor constraintEqualToAnchor:self.view.layoutMarginsGuide.trailingAnchor constant:-8],
		[stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
	]];
}

- (void)presentFromViewController:(UIViewController *)presenter {
	UISheetPresentationController *sheet = self.sheetPresentationController;
	if(sheet) {
		sheet.detents = @[[UISheetPresentationControllerDetent mediumDetent]];
		sheet.prefersGrabberVisible = NO;
	}
	[presenter presentViewController:self animated:YES completion:^{
		[self startBuild];
	}];
}

- (void)cancelTapped {
	_cancelRequested = YES;
	self.cancelButton.enabled = NO;
	self.titleLabel.text = NSLocalizedString(@"SearchBuildingCancellingLabel", @"Cancelling…");
}

- (void)startBuild {
	// Register a background task so iOS gives us ~30s to finish if the user
	// backgrounds the app mid-build. Expiration flips the cancel flag so we
	// tear down cleanly rather than getting killed with a half-written DB.
	_bgTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
		self->_cancelRequested = YES;
	}];

	SwordModule *mod = self.module;
	PSSearchEngine *engine = [PSSearchEngine engineForModule:mod];

	dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
		NSError *err = nil;
		BOOL ok = [engine buildWithProgress:^(float fraction, BOOL *cancel) {
			*cancel = self->_cancelRequested;
			dispatch_async(dispatch_get_main_queue(), ^{
				self.progressView.progress = fraction;
			});
		} error:&err];

		BOOL cancelled = self->_cancelRequested;
		dispatch_async(dispatch_get_main_queue(), ^{
			[self finishWithSuccess:ok cancelled:cancelled error:err];
		});
	});
}

- (void)finishWithSuccess:(BOOL)success cancelled:(BOOL)cancelled error:(NSError *)err {
	if(self.buildFinished) return;
	self.buildFinished = YES;

	if(_bgTask != UIBackgroundTaskInvalid) {
		[[UIApplication sharedApplication] endBackgroundTask:_bgTask];
		_bgTask = UIBackgroundTaskInvalid;
	}

	if(!success && !cancelled && err) {
		ALog(@"PSSearchIndexBuilder: build failed: %@", err);
	}

	id<PSSearchIndexBuilderDelegate> delegate = self.delegate;
	[self dismissViewControllerAnimated:YES completion:^{
		[delegate indexBuilder:self didFinishWithSuccess:success cancelled:cancelled];
	}];
}

@end
