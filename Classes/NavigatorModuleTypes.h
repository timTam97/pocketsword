//
//  NavigatorLevel2.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "NavigatorSources.h"

@interface NavigatorModuleTypes : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorModuleLanguages;
	NSArray *dataArray;
	IBOutlet NavigatorSources *navigatorSources;
	//IBOutlet UITabBarController *tabController;

	// Status view
	IBOutlet UIViewController *statusController;
	IBOutlet UILabel *statusTitle;
	IBOutlet UILabel *statusText;
	IBOutlet UILabel *statusOverallText;
	IBOutlet UIProgressView *statusBar;
	IBOutlet UIProgressView *statusOverallBar;
	IBOutlet UIButton *cancelButton;
	
}
@property (retain, readwrite) NSArray *dataArray;

- (void)viewWillAppear:(BOOL)animated;
- (void)reloadTable;
- (void)viewDidAppear:(BOOL)animated;
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

- (IBAction)refreshDownloadSource:(id)sender;
- (IBAction)cancelRefreshDownloadSource;
//- (void)runRefreshDownloadSource;
- (void)showRefreshStatus;
- (void)updateRefreshStatus;
- (void)hideOperationStatus;

- (void)dealloc;

@end
