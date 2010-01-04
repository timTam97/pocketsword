//
//  PSIndexController.mm
//  PocketSword
//
//  Created by Nic Carter on 5/12/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "PSIndexController.h"
#import "ZipArchive.h"
#import "ViewController.h"

@implementation PSIndexController

@synthesize downloadableIndices;
@synthesize installedIndices;
@synthesize unavailableIndices;
@synthesize files;

int tableSections;
BOOL installedShown;
BOOL unavailableShown;
BOOL downloadableShown;

- (void)viewDidLoad {
	//i18n of title
	navItem.title = NSLocalizedString(@"SearchDownloaderTitle", @"Search Downloader");
	//i18n of close button
	closeButton.title = NSLocalizedString(@"CloseButtonTitle", @"Close");
	tableSections = 0;
	installedShown = NO;
	unavailableShown = NO;
	downloadableShown = NO;
}

- (void)setModuleManager:(PSModuleController *)mm {
	moduleManager = mm;
	[moduleManager retain];
	//[self updateInstalledIndexList];
}

- (void)setSearchController:(PSSearchController *)sc {
	searchController = sc;
	[searchController retain];
}

- (void)viewWillAppear:(BOOL)animated {
	if(downloadableShown)
		[self updateInstalledIndexList];
	else
		[self updateInstalledIndexListWithRemoteIndices:nil];
	[super viewWillAppear:animated];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return tableSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return [installedIndices count];
		case 1:
			if(downloadableShown)
				return [downloadableIndices count];
			else
				return [unavailableIndices count];
	}
	//case 2:
	return [unavailableIndices count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	switch (section) {
		case 0:
			return NSLocalizedString(@"IndexControllerInstalled", @"Installed search index for:");
		case 1:
			if(downloadableShown)
				return NSLocalizedString(@"IndexControllerDownloadable", @"Downloadable search index for:");
			else
				return NSLocalizedString(@"IndexControllerNone", @"No available search index for:");
	}
	//case 2:
	return NSLocalizedString(@"IndexControllerNoneRemote", @"No remote search index for:");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"indexCell"];
	if (!cell)
	{
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"indexCell"] autorelease];
	}
	switch (indexPath.section) {
		case 0:
			cell.textLabel.text = [(SwordModule*)[installedIndices objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [(SwordModule*)[installedIndices objectAtIndex:indexPath.row] descr];
			break;
		case 1:
			if(downloadableShown) {
				cell.textLabel.text = [(SwordModule*)[downloadableIndices objectAtIndex:indexPath.row] name];
				cell.detailTextLabel.text = [(SwordModule*)[downloadableIndices objectAtIndex:indexPath.row] descr];
			} else {
				cell.textLabel.text = [(SwordModule*)[unavailableIndices objectAtIndex:indexPath.row] name];
				cell.detailTextLabel.text = [(SwordModule*)[unavailableIndices objectAtIndex:indexPath.row] descr];
			}
			break;
		case 2:default:
			cell.textLabel.text = [(SwordModule*)[unavailableIndices objectAtIndex:indexPath.row] name];
			cell.detailTextLabel.text = [(SwordModule*)[unavailableIndices objectAtIndex:indexPath.row] descr];
			break;
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if(downloadableShown && (indexPath.section == 1)) {
		ViewController *mm = [moduleManager viewController];
		[mm performSelectorInBackground: @selector(showIndexStatus) withObject: nil];
		[self installSearchIndexForModule: (SwordModule*)[downloadableIndices objectAtIndex:indexPath.row]];
	}
}

- (IBAction)updateInstalledIndexListWithRemoteIndices:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;

	NSString *remoteDir = @"http://pocketsword.net/indices/";
	
	// Get the index directory listing
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: remoteDir]
											 cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	NSData *data = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
	if (!data) {
		DLog(@"Couldn't list remote directory");
		//as a fallback, call the local version:
		[self updateInstalledIndexList];
		[pool release];
		return;
	}
	
	NSString *dataString = [[NSString alloc] initWithData: data encoding: [NSString defaultCStringEncoding]];
	self.files = [NSMutableArray arrayWithObjects: nil];
	NSRange dataRange;
	
	while ((dataRange = [dataString rangeOfString: @"<a href=\""]).location != NSNotFound) {
		dataString = [dataString substringFromIndex: dataRange.location + dataRange.length];
		dataRange = [dataString rangeOfString: @"\""];
		if (dataRange.location != NSNotFound) {
			NSString *link = [dataString substringToIndex: dataRange.location];
			//if ([item UTF8String][0] != '/') {
			//if (![item hasPrefix:@"/"] && ![item hasSuffix:@"/"]) {
			if ([link hasSuffix:@".zip"]) {
				link = [link substringToIndex: ([link length] - 4)];
				[files addObject: link];
				//NSLog(@"found a file: %@", item);
			}
		}
	}
	
	[self updateInstalledIndexList];

	application.networkActivityIndicatorVisible = NO;
	//[indicesTable reloadData];
	[pool release];
}

- (IBAction)closeButtonPressed:(id)sender {
	[searchController refreshView];
	[ViewController hideModal:self.view withTiming:0.3];
}

- (void)updateInstalledIndexList {
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSMutableArray *modules = [[[[moduleManager swordManager] listModules] mutableCopy] autorelease];
	NSMutableArray *ii = [NSMutableArray arrayWithObjects: nil];
	NSMutableArray *di = [NSMutableArray arrayWithObjects: nil];
	NSMutableArray *nai = [NSMutableArray arrayWithObjects: nil];
	
	NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
	NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
	[modules sortUsingDescriptors:sortDescriptors];
	[sortDescriptor release];
	
	for(SwordModule *mod in modules) {
		if([mod hasSearchIndex]) {
			[ii addObject: mod];
			//NSLog(@"installed index for: %@", [mod name]);
		} else if(self.files && [files containsObject: [[mod name] lowercaseString]]) {
			[di addObject: mod];
			//NSLog(@"downloadable index for: %@", [mod name]);
		} else {
			[nai addObject: mod];
			//NSLog(@"no available index for: %@", [mod name]);
		}
	}
	
	self.installedIndices = ii;
	self.downloadableIndices = di;
	self.unavailableIndices = nai;
	
	//[modules release];
	
	tableSections = 1;
	installedShown = YES;
	
	if([downloadableIndices count] > 0) {
		tableSections++;
		downloadableShown = YES;
	} else {
		downloadableShown = NO;
	}
	
	if([unavailableIndices count] > 0) {
		tableSections++;
		unavailableShown = YES;
	} else {
		unavailableShown = NO;
	}
	[indicesTable reloadData];
	[pool release];
}

// Installs the search index for the primary text
- (void)installSearchIndexForModule:(SwordModule *)mod {
	//SwordModule *mod = [[moduleManager swordManager] moduleWithName:module];
	if (!mod) {
		return;
	}
	moduleName = [mod name];
	NSString *filename = [NSString stringWithFormat: @"http://pocketsword.net/indices/%@.zip", [[mod name] lowercaseString]];
	
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;

	// Download the data file
	NSURLRequest *request = [NSURLRequest requestWithURL: [NSURL URLWithString: filename] cachePolicy: NSURLRequestReloadIgnoringLocalCacheData timeoutInterval: 15.0];
	[[NSURLConnection alloc] initWithRequest:request delegate:self];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    responseData = [[NSMutableData alloc] init];
	responseDataExpectedLength = [response expectedContentLength];
	responseDataCurrentLength = 0;
	installationProgress = 0.01;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [responseData appendData:data];
	responseDataCurrentLength = [responseData length];
	installationProgress = (float) responseDataCurrentLength / (float) responseDataExpectedLength;
	if(installationProgress >= 1.0)
		installationProgress = 0.9999;//1.0 is a reserved special value that shouldn't be set here.
	ViewController *mm = [moduleManager viewController];
	NSString *p = [NSString stringWithFormat: @"%f", installationProgress];
	[mm performSelectorInBackground: @selector(updateIndexInstallationStatus:) withObject: p];
	//[[moduleManager viewController] updateIndexInstallationStatus:installationProgress];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [responseData release];
    [connection release];
    // Show error message
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = NO;

	ALog(@"Couldn't retrieve search index for: %@", moduleName);
	installationProgress = -1.0;
	ViewController *mm = [moduleManager viewController];
	[mm performSelectorInBackground: @selector(hideIndexStatus) withObject: nil];
	//[[moduleManager viewController] hideOperationStatus];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [connection release];
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = NO;

    // Use responseData
	SwordModule *mod = [[moduleManager swordManager] moduleWithName:moduleName];
	NSString *outfileDir = [mod configEntryForKey:@"AbsoluteDataPath"];
	NSString *zippedIndex = [outfileDir stringByAppendingPathComponent: [NSString stringWithFormat: @"%@.zip", moduleName]];
	NSString *cluceneDir = [outfileDir stringByAppendingPathComponent: @"lucene"];
	if (![responseData writeToFile: zippedIndex atomically: NO]) {
		ALog(@"Couldn't write file: %@", zippedIndex);
		installationProgress = -1.0;
		[responseData release];
		return;
	}
    [responseData release];

	ZipArchive *arch = [[ZipArchive alloc] init];
	[arch UnzipOpenFile:zippedIndex];
	[arch UnzipFileTo:cluceneDir overWrite:YES];
	[arch UnzipCloseFile];
	[arch release];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	[fileManager removeItemAtPath:zippedIndex error:NULL];
	
	DLog(@"Index (%@) installed successfully", moduleName);
	
	installationProgress = 1.0;
	[self updateInstalledIndexList];
	 //[indicesTable reloadData];
	ViewController *mm = [moduleManager viewController];
	[mm performSelectorInBackground: @selector(hideIndexStatus) withObject: nil];
	//[[moduleManager viewController] hideOperationStatus];
}

- (float)getInstallationProgress {
	return installationProgress;
}

//	NSData *responseData = [NSURLConnection sendSynchronousRequest: request returningResponse: NULL error: NULL];
//	if (!responseData) {
//		ALog(@"Couldn't retrieve file: %@", filename);
////		installationProgress = -1.0;
//		[pool release];
//		return NO;
//	}
//	
//	if (![responseData writeToFile: zippedIndex atomically: NO]) {
//		ALog(@"Couldn't write file: %@", zippedIndex);
////		installationProgress = -1.0;
//		[pool release];
//		return NO;
//	}
//	
//	ZipArchive *arch = [[ZipArchive alloc] init];
//	[arch UnzipOpenFile:zippedIndex];
//	[arch UnzipFileTo:cluceneDir overWrite:YES];
//	[arch UnzipCloseFile];
//	[arch release];
//	
//	NSFileManager *fileManager = [NSFileManager defaultManager];
//	[fileManager removeItemAtPath:zippedIndex error:NULL];
//	
//	DLog(@"Index (%@) installed successfully", module);
//	
////	installationProgress = 1.0;
//	[pool release];
//	return YES;
//}

- (void)dealloc {
	//NSLog(@"PSIndexController: dealloc");
	self.downloadableIndices = nil;
	self.installedIndices = nil;
	self.unavailableIndices = nil;
	self.files = nil;
	[moduleManager release];
	[searchController release];
	[super dealloc];
}

@end
