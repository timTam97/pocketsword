/*
 *  globals.h
 *  MacSword2
 *
 *  Created by Manfred Bergmann on 03.06.05.
 *  Copyright 2007 mabe. All rights reserved.
 *
 */

// $Author: $
// $HeadURL: $
// $LastChangedBy: $
// $LastChangedDate: $
// $Rev: $

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// we can add more to this enum as we're required to dynamically show those tabs
typedef enum {
    BibleTab = 1,
    CommentaryTab,
	DictionaryTab
} ShownTab;

#define DefaultsModuleCipherKeysKey                 @"DefaultsModuleCipherKeysKey"
//#define DEFAULT_MODULE_PATH         [@"~/Library/Application Support/Sword" stringByExpandingTildeInPath]
#define DEFAULT_MODULE_PATH         [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_APPSUPPORT_PATH     [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]

#define DEFAULT_INSTALLER_PATH		[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/InstallMgr/"]
//#define FTP_TMP_FILE				[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/InstallMgr/swftplib.tmp"]
// define for userdefaults
#define userDefaults [NSUserDefaults standardUserDefaults]
// define for default SwordManager
#define defSwordManager [SwordManager defaultManager]


/**
 \brief this notification is send, when the modules have changed (updated, added, removed)
 */
#define NotificationModulesChanged			@"NotificationModulesChanged"
#define SendNotifyModulesChanged(X) [[NSNotificationCenter defaultCenter] postNotificationName:NotificationModulesChanged object:X];
#define NotificationBibleSwipeRight			@"NotificationBibleSwipeRight"
#define NotificationBibleSwipeLeft			@"NotificationBibleSwipeLeft"
#define NotificationCommentarySwipeRight	@"NotificationCommentarySwipeRight"
#define NotificationCommentarySwipeLeft		@"NotificationCommentarySwipeLeft"


#define RUBY_CSS @"ruby\n\
			{\n\
				display: inline-table;\n\
				text-align: center;\n\
				white-space: nowrap;\n\
				text-indent: 0;\n\
				margin: 0;\n\
				vertical-align: -10%%;\n\
			}\n\
			\n\
			ruby > rb, ruby > rbc\n\
			{\n\
				display: table-row-group;\n\
				line-height: 110%%;\n\
			}\n\
			\n\
			ruby > rt, ruby > rbc + rtc\n\
			{\n\
				display: table-header-group;\n\
				valign: top;\n\
				font-size: 60%%;\n\
				line-height: 40%%;\n\
				letter-spacing: 0;\n\
			}\n\
			\n\
			ruby > rbc + rtc + rtc\n\
			{\n\
				display: table-footer-group;\n\
				font-size: 60%%;\n\
				line-height: 40%%;\n\
				letter-spacing: 0;\n\
			}\n\
			\n\
			rbc > rb, rtc > rt\n\
			{\n\
				display: table-cell;\n\
				letter-spacing: 0;\n\
			}\n\
			\n\
			rtc > rt[rbspan] { display: table-caption; }\n\
			\n\
			rp { display: none; }\n"


/*
#define BUNDLEVERSION               CFBundleGetVersionNumber(CFBundleGetMainBundle())
#define BUNDLEVERSIONSTRING         CFBundleGetValueForInfoDictionaryKey(CFBundleGetMainBundle(), kCFBundleVersionKey)
#define APPNAME                     @"MacSword"
#define OLD_BOOKMARK_PATH           [@"~/Library/Application Support/MacSword/Bookmarks.plist" stringByExpandingTildeInPath]
#define DEFAULT_BOOKMARK_PATH       [@"~/Library/Application Support/MacSword/Bookmarklist.plist" stringByExpandingTildeInPath]
#define DEFAULT_SESSION_PATH        [@"~/Library/Application Support/MacSword/DefaultSession.plist" stringByExpandingTildeInPath]
#define DEFAULT_SEARCHBOOKSET_PATH  [@"~/Library/Application Support/MacSword/DefaultSearchBookSets.plist" stringByExpandingTildeInPath]
#define SWINSTALLMGR_NAME           @"InstallMgr"
#define LOGFILE                     [@"~/Library/Logs/MacSword2.log" stringByExpandingTildeInPath]
#define TMPFOLDER                   [@"~/Library/Caches/MacSword" stringByExpandingTildeInPath]

// OS version
#define OSVERSION [[NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"] objectForKey:@"ProductVersion"]
*/

// table and outlineview fonts
/*#define FontTiny [UIFont fontWithName: @"Lucida Grande" size:9]
#define FontSmall [UIFont fontWithName: @"Lucida Grande" size:10]
#define FontStd [UIFont fontWithName: @"Lucida Grande" size: 11]
#define FontStdBold [UIFont fontWithName: @"Lucida Grande Bold" size: 11]
#define FontLarge [UIFont fontWithName: @"Lucida Grande" size: 12]
#define FontLargeBold [UIFont fontWithName: @"Lucida Grande Bold" size: 12]
#define FontMoreLarge [UIFont fontWithName: @"Lucida Grande" size: 14]
#define FontMoreLargeBold [UIFont fontWithName: @"Lucida Grande Bold" size: 14]*/



// Notification identifiers


/**
 \brief this notification is send when the user clicks on a link in ExtTextView or the tooltip sows up
 */
//#define NotificationShowPreviewData @"NotificationShowPreviewData"
//#define SendNotifyShowPreviewData(X) [[NSNotificationCenter defaultCenter] postNotificationName:NotificationShowPreviewData object:X];

/**
 \brief this notification is send when among the currently displayed and active modules is a dictionary or genbook
 */
//#define NotificationSetHUDContentView @"NotificationSetHUDContentView"
//#define SendNotifySetHUDContentView(X) [[NSNotificationCenter defaultCenter] postNotificationName:NotificationSetHUDContentView object:X];
