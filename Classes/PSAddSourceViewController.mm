//
//  PSAddSourceViewController.m
//  PocketSword
//
//  Created by Nic Carter on 10/06/10.
//  Copyright 2010 CrossWire Bible Society. All rights reserved.
//

#import "PSAddSourceViewController.h"
#import "NavigatorSources.h"
#import "PSModuleController.h"


@implementation PSAddSourceViewController

@synthesize serverType;

#define CAPTION_SECTION	0
#define SERVER_SECTION	1
#define PATH_SECTION	2
#define SECTIONS		3


#pragma mark -
#pragma mark View lifecycle


- (void)viewDidLoad {
    [super viewDidLoad];
	
//	UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(saveButtonPressed)];
//	navBar.rightBarButtonItem = doneButton;
//	[doneButton release];

	captionTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,280,25)];
	[captionTextField setPlaceholder:@"e.g. CrossWire 1"];
	captionTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	captionTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	captionTextField.returnKeyType = UIReturnKeyNext;
	captionTextField.delegate = self;
	
	serverTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,280,25)];
	[serverTextField setPlaceholder:@"e.g. ftp.crosswire.org"];
	serverTextField.keyboardType = UIKeyboardTypeURL;
	serverTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	serverTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	serverTextField.returnKeyType = UIReturnKeyNext;
	serverTextField.delegate = self;
	
	pathTextField = [[UITextField alloc] initWithFrame:CGRectMake(20,12,280,25)];
	[pathTextField setPlaceholder:@"e.g. /pub/sword/raw"];
	pathTextField.keyboardType = UIKeyboardTypeURL;
	pathTextField.autocapitalizationType = UITextAutocapitalizationTypeNone;
	pathTextField.autocorrectionType = UITextAutocorrectionTypeNo;
	pathTextField.returnKeyType = UIReturnKeyDone;
	pathTextField.delegate = self;	

}

- (void)viewWillAppear:(BOOL)animated {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc addObserver:self selector:@selector(keyboardWillShow:) name: UIKeyboardWillShowNotification object:nil];
	[nc addObserver:self selector:@selector(keyboardDidShow:) name: UIKeyboardDidShowNotification object:nil];
	//[nc addObserver:self selector:@selector(keyboardWillHide:) name: UIKeyboardWillHideNotification object:nil];
	NSString *t = [NSString stringWithFormat:@"Add%@SourceTitle", serverType];
	navBar.title = NSLocalizedString(t, @"");
	[captionTextField becomeFirstResponder];
	[super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
	[nc removeObserver:self];
	[super viewWillDisappear:animated];
}

- (void)keyboardWillShow:(NSNotification *)note {
	//DLog(@"willShow");
    CGRect r  = addSourceTableView.frame, t;
    [[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];//use UIKeyboardFrameEndUserInfoKey in iOS4
    //[[note.userInfo valueForKey:UIKeyboardFrameEndUserInfoKey] getValue: &t];
	//UIWindow* mainWindow = (((PocketSwordAppDelegate*) [UIApplication sharedApplication].delegate).window);
	//t = [mainWindow convertRect:t fromWindow:nil];
    ////r.size.height -=  t.size.height;
    r.size.height = 416 - t.size.height;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    addSourceTableView.frame = r;
	[UIView commitAnimations];
}

- (void)keyboardDidShow:(NSNotification *)note {
	if([captionTextField isFirstResponder]) {
		//DLog(@"caption");
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:CAPTION_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([serverTextField isFirstResponder]) {
		//DLog(@"server");
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SERVER_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([pathTextField isFirstResponder]) {
		//DLog(@"path");
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:PATH_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	}
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if([captionTextField isFirstResponder]) {
		//DLog(@"caption");
		[serverTextField becomeFirstResponder];
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:SERVER_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([serverTextField isFirstResponder]) {
		//DLog(@"server");
		[pathTextField becomeFirstResponder];
		[addSourceTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:PATH_SECTION] atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
	} else if([pathTextField isFirstResponder]) {
		//DLog(@"path");
		[self saveButtonPressed];
	}
	//[textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
	[self keyboardDidShow:nil];
}
	   
- (void)keyboardWillHide:(NSNotification *)note {
	//DLog(@"willHide");
    CGRect r  = addSourceTableView.frame;
	//CGRect t;
    //[[note.userInfo valueForKey:UIKeyboardBoundsUserInfoKey] getValue: &t];
    //r.size.height +=  t.size.height;
	r.size.height = 416;
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    addSourceTableView.frame = r;
	//addSourceTableView.frame.size.height = 416;
	[UIView commitAnimations];
}

//- (void)viewDidAppear:(BOOL)animated {
//	[super viewDidAppear:animated];
//	[captionTextField becomeFirstResponder];
//}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex != [alertView cancelButtonIndex]) {
		[self addInstallSource:captionTextField.text withPath:pathTextField.text andServer:serverTextField.text];
	}
}

- (IBAction)cancelButtonPressed {
	[captionTextField resignFirstResponder];
	[serverTextField resignFirstResponder];
	[pathTextField resignFirstResponder];
	[navSources dismissModalViewControllerAnimated:YES];
}

- (IBAction)saveButtonPressed {
	NSString *caption = captionTextField.text;
	NSString *server = serverTextField.text;
	NSString *path = pathTextField.text;
	if(!caption || [caption isEqualToString:@""] || !server || [server isEqualToString:@""] || !path || [path isEqualToString:@""]) {
		//you must fill in all fields to add a new source
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"FillInAllFieldsMessage", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"Ok") otherButtonTitles: nil] show];
		return;
	}

	if(![PSModuleController checkNetworkConnection]) {
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Error", @"") message: NSLocalizedString(@"NoNetworkConnection", @"No network connection available.") delegate: self cancelButtonTitle: NSLocalizedString(@"Ok", @"") otherButtonTitles: nil] show];		
		return;
	}
	
	
	UIApplication *application = [UIApplication sharedApplication];
	application.networkActivityIndicatorVisible = YES;
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationDisplayBusyIndicator object:nil];
	//[[PSModuleController defaultModuleController] displayBusyIndicator];

	NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://%@%@/mods.d.tar.gz", [serverType lowercaseString], server, path]];
	NSData *data = nil;

	NSURLResponse *response = [[[NSURLResponse alloc] init] autorelease]; 
	NSURLRequest *request = [NSURLRequest requestWithURL:url];
	data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:nil];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:NotificationHideBusyIndicator object:nil];
	//[[PSModuleController defaultModuleController] hideBusyIndicator];

	application.networkActivityIndicatorVisible = NO;

	if(!data) {
		//perhaps dodgy, display a warning.
		[[[UIAlertView alloc] initWithTitle: NSLocalizedString(@"Warning", @"") message: NSLocalizedString(@"CannotVerifyInstallSourceWarning", @"") delegate: self cancelButtonTitle: NSLocalizedString(@"No", @"No") otherButtonTitles: NSLocalizedString(@"Yes", @"Yes"), nil] show];
		return;
	} else {
	}
	
	[self addInstallSource:caption withPath:path andServer:server];
}

- (void)addInstallSource:(NSString*)caption withPath:(NSString*)path andServer:(NSString*)server {
	SwordInstallSource *is = [[SwordInstallSource alloc] initWithType:serverType];
	
	[is setCaption:caption];
	[is setDirectory:path];
	[is setSource:server];
	[is setUID:[NSString stringWithFormat:@"%@-%@", server, caption]];
	
	[[[PSModuleController defaultModuleController] swordInstallManager] addInstallSource:is];
	[navSources resetTableSelection];
	
	[navSources dismissModalViewControllerAnimated:YES];
	captionTextField.text = @"";
	serverTextField.text = @"";
	pathTextField.text = @"";
}

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return SECTIONS;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	switch(indexPath.section) {
		case CAPTION_SECTION:
			[cell addSubview:captionTextField];
			break;
		case SERVER_SECTION:
			[cell addSubview:serverTextField];
			break;
		case PATH_SECTION:
			[cell addSubview:pathTextField];
			break;
	}
	
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch(section) {
		case CAPTION_SECTION:
			return NSLocalizedString(@"AddSourceCaptionTitle", @"");
		case SERVER_SECTION:
			return NSLocalizedString(@"AddSourceServerTitle", @"");
		case PATH_SECTION:
			return NSLocalizedString(@"AddSourcePathTitle", @"");
	}
	return @"";
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // Navigation logic may go here. Create and push another view controller.
	/*
	 <#DetailViewController#> *detailViewController = [[<#DetailViewController#> alloc] initWithNibName:@"<#Nib name#>" bundle:nil];
     // ...
     // Pass the selected object to the new view controller.
	 [self.navigationController pushViewController:detailViewController animated:YES];
	 [detailViewController release];
	 */
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
	[captionTextField release];
	[serverTextField release];
	[pathTextField release];
}


- (void)dealloc {
    [super dealloc];
}


@end

