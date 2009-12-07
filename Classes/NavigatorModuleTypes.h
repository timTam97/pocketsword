//
//  NavigatorLevel2.h
//  PocketSword
//
//  Created by Nic Carter on 9/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSModuleController.h"
#import "NavigatorSources.h"

@interface NavigatorModuleTypes : UIViewController <UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource> {
	IBOutlet id table;
	IBOutlet id navigatorModuleLanguages;
	NSArray *dataArray;
	IBOutlet NavigatorSources *navigatorSources;
	//IBOutlet UITabBarController *tabController;
	//IBOutlet id moduleManager;

	// Status view
	IBOutlet id statusController;
	IBOutlet id statusTitle;
	IBOutlet id statusText;
	IBOutlet id statusOverallText;
	IBOutlet id statusBar;
	IBOutlet id statusOverallBar;
	
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
- (void)runRefreshDownloadSource;
- (void)showRefreshStatus;
- (void)updateRefreshStatus;
- (void)hideOperationStatus;

- (void)dealloc;

@end
