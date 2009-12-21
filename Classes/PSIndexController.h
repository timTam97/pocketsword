//
//  PSIndexController.h
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSModuleController.h"
#import "SwordModule.h"

@interface PSIndexController : UIViewController {
	PSModuleController *moduleManager;

	NSArray *downloadableIndices;
	NSArray *installedIndices;
	NSArray *unavailableIndices;
	
	NSMutableData *responseData;
	NSInteger responseDataExpectedLength;
	NSInteger responseDataCurrentLength;
	float installationProgress;
	NSString *moduleName;
	
	IBOutlet UIBarButtonItem *closeButton;
	IBOutlet UITableView *indicesTable;
	IBOutlet UINavigationItem *navItem;
}

@property (retain, readwrite) NSArray *downloadableIndices;
@property (retain, readwrite) NSArray *installedIndices;
@property (retain, readwrite) NSArray *unavailableIndices;

- (void)viewDidLoad;
- (void)dealloc;
- (void)setModuleManager:(PSModuleController *)mm;

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
