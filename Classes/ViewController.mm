/*
	PocketSword - a frontend for viewing SWORD project modules on the iPhone and iPod Touch
	Copyright (C) 2008-2009 Ian Wagner

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 2 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program; if not, write to the Free Software Foundation, Inc.,
	51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/

#import "ViewController.h"

@implementation ViewController

int percent;
bool initialized = false, waitingForInstall = false;

NSTimer *timer;
NSString *installModule;

- (IBOutlet id)getTextView {
	return textView;
}

- (IBOutlet id)getNavBtn {
	return navBtn;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[searchBar resignFirstResponder];
	
	// Check if we have a lucene search framework
	SWModule *primaryText = [moduleManager getPrimaryText];
	SWBuf dir = primaryText->getConfigEntry("AbsoluteDataPath");
	char ch = dir.c_str()[strlen(dir.c_str())-1];
	if ((ch != '/') && (ch != '\\'))
		dir.append('/');
	dir.append("lucene");
	char isIndexed = FileMgr::existsFile(dir.c_str(), "segments");
	if (isIndexed != 1) {
		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"You must download an index before you can search this module. Would you like to download it it now?"
								   delegate: self cancelButtonTitle: @"No" otherButtonTitles: @"Yes", nil] show];
		
	}
	[dataController performSearch: [searchBar text]];
	[resultsTable reloadData];
	[pool release];
}

- (void)confirmInstall:(NSString *)name {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	NSString *message = [NSString stringWithFormat: @"Would you like to install this module: %@?", name];
	[[[UIAlertView alloc] initWithTitle: @"Confirm" message: message
							   delegate: self cancelButtonTitle: @"No" otherButtonTitles: @"Yes", nil] show];
	
	installModule = name;
	waitingForInstall = true;
	[pool release];
}

- (void)showDownloadStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[statusTitle setText: @"Module Download"];
	[statusText setText: @"Installing..."];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	[navController setNavigationBarHidden: YES];
	
	[tabController presentModalViewController: navController animated: YES];
	
	[pool release];
}

- (void)runInstallation {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[self performSelectorInBackground: @selector(showDownloadStatus) withObject: nil];
	
	[moduleManager performSelectorInBackground: @selector(installModule:) withObject: installModule];
	[self updateInstallationStatus];
	
	[pool release];
}

- (void)updateInstallationStatus {
	float progress = [moduleManager getInstallationProgress];
	[statusBar setProgress: progress];
	
	NSLog(@"Progress: %f", progress);
	
	if (progress == 1.0) {
		[dataController reloadModuleList];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		[moduleManager init];
		[moduleTable reloadData];
	}
	else if (progress == -1.0) {
		[dataController reloadModuleList];
		[self performSelectorInBackground: @selector(hideOperationStatus) withObject: nil];
		[moduleTable reloadData];
		[[[UIAlertView alloc] initWithTitle: @"Error" message: @"A problem occurred during the installation."
								   delegate: self cancelButtonTitle: @"Ok" otherButtonTitles: nil] show];
	}
}

- (void)hideOperationStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[tabController dismissModalViewControllerAnimated: YES];
	[timer invalidate];
	
	[pool release];
}

- (void)installIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[self performSelectorInBackground: @selector(showDownloadStatus) withObject: nil];
	
	[moduleManager performSelectorInBackground: @selector(installSearchIndex) withObject: nil];
	[self updateInstallationStatus];
	
	[pool release];
}

- (void)showIndexStatus {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	[statusTitle setText: @"Index Download"];
	[statusText setText: @"Installing..."];
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController: statusController];
	[navController setNavigationBarHidden: YES];
	
	[tabController presentModalViewController: navController animated: YES];
	
	[pool release];
}

//
// UIAlertView delegate method
//
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	NSLog(@"Clicked button %d", buttonIndex);
	if (buttonIndex == 1 && waitingForInstall) {
		waitingForInstall = false;
		[self performSelectorInBackground: @selector(runInstallation) withObject: nil];
		
		SEL method = @selector(updateInstallationStatus);
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: method];
		
		timer = [NSTimer scheduledTimerWithTimeInterval: 1 invocation: invocation repeats: YES];
	}
	else if (buttonIndex == 1) {
		percent = 0;
		[self performSelectorInBackground: @selector(installIndex) withObject: nil];
		
		SEL method = @selector(updateInstallationStatus);
		NSMethodSignature* sig = [[self class] instanceMethodSignatureForSelector: method];
		NSInvocation* invocation = [NSInvocation invocationWithMethodSignature: sig];
		[invocation setTarget: self];
		[invocation setSelector: method];
		
		timer = [NSTimer scheduledTimerWithTimeInterval: 1 invocation: invocation repeats: YES];
	}
	
	[pool release];
}

- (void)awakeFromNib {
	if (!initialized) {
		NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		
		NSString *lastRef = [defaults stringForKey: @"lastRef"];
		if (lastRef == nil) {
			[defaults setPersistentDomain: [NSDictionary dictionaryWithObject: @"gen 1" forKey: @"lastRef"] forName: [[NSBundle mainBundle] bundleIdentifier]];
			lastRef = @"Genesis 1";
		}
		
		NSString *text = [moduleManager getChapter: lastRef];
		[textView loadHTMLString: text baseURL: nil];
		
		SWModule *primaryText = [moduleManager getPrimaryText];
		if (primaryText) {
			NSString *ref = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
			[navBtn setTitle: [[[ref stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] stringByReplacingOccurrencesOfString: @"I " withString: @"1 "]
							   stringByReplacingOccurrencesOfString: @" of John " withString: @" "]];		}
		else {
			[navBtn setTitle: @"PocketSword"];
		}
		
		if ([defaults boolForKey: @"insomnia_preference"]) {
			UIApplication *thisApp = [UIApplication sharedApplication];
			thisApp.idleTimerDisabled = YES;
		}
		
		[pool release];
		initialized = true;
	}
}

// Loads the next chapter into the Web View
- (IBAction)nextChapter:(id)sender {
	if ([[navBtn title] isEqualToString: @"PocketSword"]) {
		return;
	}
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	SWModule *primaryText = [moduleManager getPrimaryText];
	primaryText->RenderText();
	SWKey curKey;
	SWKey lastKey;
	NSString *ch = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	// Advance to the next chapter
	do {
		curKey = primaryText->Key();
		lastKey = primaryText->Key()++;
		primaryText->RenderText();
		ref = [[[NSString stringWithUTF8String: curKey.getText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	} while ([ref isEqualToString: ch] /*&& (lastKey != curKey)*/);
	
	NSString *text = [moduleManager getChapter: ref];
	[textView loadHTMLString: text baseURL: nil];	// Get the chapter text
	[navBtn setTitle: [[[ref stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] stringByReplacingOccurrencesOfString: @"I " withString: @"1 "]
					   stringByReplacingOccurrencesOfString: @" of John " withString: @" "]];	
	[pool release];
}

// Loads the previous chapter into the Web View
- (IBAction)prevChapter:(id)sender {
	if ([[navBtn title] isEqualToString: @"PocketSword"]) {
		return;
	}
	
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	SWModule *primaryText = [moduleManager getPrimaryText];
	primaryText->RenderText();
	SWKey curKey;
	SWKey lastKey;
	NSString *ch = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	NSString *ref = [NSString stringWithString: ch];
	
	// Move to the previous chapter
	do {
		curKey = primaryText->Key();
		lastKey = primaryText->Key()--;
		primaryText->RenderText();
		ref = [[[NSString stringWithUTF8String: curKey.getText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	} while ([ref isEqualToString: ch] /*&& (lastKey != curKey)*/);
	
	NSString *text = [moduleManager getChapter: ref];
	[textView loadHTMLString: text baseURL: nil];	// Get the chapter text
	[navBtn setTitle: [[[ref stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] stringByReplacingOccurrencesOfString: @"I " withString: @"1 "]
					   stringByReplacingOccurrencesOfString: @" of John " withString: @" "]];	
	[pool release];
}

// Toggles the reference picker display
- (IBAction)toggleNavigation:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	if ([[navBtn title] isEqualToString: @"PocketSword"]) {
		return;
	}
	
	[refSelector setHidden: ![refSelector isHidden]];
	
	if (![refSelector isHidden]) {
		[prevBtn setTitle: @"Cancel"];
		[prevBtn setAction: @selector(toggleNavigation:)];
		[nextBtn setTitle: @"Ok"];
		[nextBtn setStyle: UIBarButtonItemStyleDone];
		[nextBtn setAction: @selector(updateViewWithSelectedChapter:)];
		NSLog(@"%@", [navBtn title]);
		NSRange range = [[navBtn title] rangeOfCharacterFromSet: [NSCharacterSet whitespaceCharacterSet] options: NSBackwardsSearch];
		NSUInteger book = [BOOKS indexOfObject: [[navBtn title] substringToIndex: range.location]];
		int chapter = 1;
		sscanf([[[[navBtn title] componentsSeparatedByString: @" "] lastObject] UTF8String], "%d", &chapter);
		--chapter;
		if (book != NSNotFound) {
			[refSelector selectRow: book inComponent: 0 animated: YES];
			[dataController pickerView: refSelector didSelectRow: book inComponent: 0];
		}
		[refSelector reloadAllComponents];
		[refSelector selectRow: chapter inComponent: 1 animated: YES];
	} else {
		[prevBtn setTitle: @"Previous"];
		[prevBtn setAction: @selector(prevChapter:)];
		[nextBtn setTitle: @"Next"];
		[nextBtn setStyle: UIBarButtonItemStyleBordered];
		[nextBtn setAction: @selector(nextChapter:)];
	}
	
	[pool release];
}

// Loads the chapter selected from the picker into the Web View
- (IBAction)updateViewWithSelectedChapter:(id)sender {
	NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
	
	SWModule *primaryText = [moduleManager getPrimaryText];
	NSInteger book = [refSelector selectedRowInComponent: 0];
	NSInteger chapter = [refSelector selectedRowInComponent: 1] + 1;
	NSString *text = [moduleManager getChapter: [[BOOKS objectAtIndex: book] stringByAppendingFormat: @" %d", chapter]];
	NSString *ref = [[[NSString stringWithUTF8String: primaryText->getKeyText()] componentsSeparatedByString: @":"] objectAtIndex: 0];
	[textView loadHTMLString: text baseURL: nil];
	[navBtn setTitle: [[[ref stringByReplacingOccurrencesOfString: @"II " withString: @"2 "] stringByReplacingOccurrencesOfString: @"I " withString: @"1 "]
					stringByReplacingOccurrencesOfString: @" of John " withString: @" "]];
	[self toggleNavigation: sender];
	
	[pool release];
}

- (IBAction)toggleModuleTableEditing:(id)sender {
	if ([moduleTable isEditing]) {
		[moduleTable setEditing: NO];
	}
	else {
		[moduleTable setEditing: YES];
	}
}

- (IBAction)toggleBookmarksTableEditing:(id)sender {
	if ([bookmarksTable isEditing]) {
		[bookmarksTable setEditing: NO];
	}
	else {
		[bookmarksTable setEditing: YES];
	}
}

- (IBAction)addBookmark:(id)sender {
	[dataController addBookmark: [navBtn title]];
}

- (void)getRemoteModuleList {
	[moduleManager reloadRepositoryModuleList];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    //return (interfaceOrientation == UIInterfaceOrientationPortrait);
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
	//[textView reload];
	NSLog(@"Rotating");
	NSString *text = [textView stringByEvaluatingJavaScriptFromString:@"document.documentElement.textContent"];
	[textView loadHTMLString: @"foo" baseURL: nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
    // Release anything that's not essential, such as cached data
}


- (void)dealloc {
    [super dealloc];
}

@end
