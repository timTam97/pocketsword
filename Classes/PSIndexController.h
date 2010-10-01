//
//  PSIndexController.h
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 The CrossWire Bible Society. All rights reserved.
//

#import "PSModuleController.h"
#import "SwordModule.h"
#import "PSSearchController.h"

@interface PSIndexController : UIViewController {
	//IBOutlet PSModuleController *moduleManager;
	PSSearchController *searchController;

	NSArray *downloadableIndices;
	NSArray *installedIndices;
	NSArray *unavailableIndices;
	NSMutableArray *files;
	
	NSMutableData *responseData;
	NSInteger responseDataExpectedLength;
	NSInteger responseDataCurrentLength;
	float installationProgress;
	NSString *moduleName;
	
	IBOutlet UIBarButtonItem *closeButton;
	IBOutlet UITableView *indicesTable;
	IBOutlet UINavigationItem *navItem;

	// Status view
	IBOutlet UIViewController *statusController;
	IBOutlet UILabel *statusTitle;
	IBOutlet UILabel *statusText;
	IBOutlet UILabel *statusOverallText;
	IBOutlet UIProgressView *statusBar;
	IBOutlet UIProgressView *statusOverallBar;
}

@property (retain, readwrite) NSArray *downloadableIndices;
@property (retain, readwrite) NSArray *installedIndices;
@property (retain, readwrite) NSArray *unavailableIndices;
@property (retain, readwrite) NSMutableArray *files;

- (void)updateIndexInstallationStatus:(NSString*)arg;//needed, move to PSIndexController
- (void)showIndexStatus;//needed, move to PSIndexController
- (void)hideIndexStatus;//needed, move to PSIndexController

//- (void)setModuleManager:(PSModuleController *)mm;
- (void)setSearchController:(PSSearchController *)sc;

- (IBAction)closeButtonPressed:(id)sender;

- (IBAction)updateInstalledIndexListWithRemoteIndices:(id)sender;
- (void)updateInstalledIndexList;
- (void)installSearchIndexForModule:(SwordModule *)module;

- (float)getInstallationProgress;

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;

@end
