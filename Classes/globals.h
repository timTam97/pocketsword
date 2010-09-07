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
	DictionaryTab,
	DevotionalTab,
	DownloadsTab
} ShownTab;

#define DefaultsModuleCipherKeysKey					@"DefaultsModuleCipherKeysKey"
#define DefaultsLastRef								@"lastRef"
#define DefaultsLastBible							@"lastBible"
#define DefaultsLastCommentary						@"lastCommentary"
#define DefaultsLastDictionary						@"lastDictionary"
#define DefaultsLastDevotional						@"lastDevotional"

#define DefaultsBibleVersePosition					@"bibleVersePosition"
#define DefaultsCommentaryVersePosition				@"commentaryVersePosition"

//#define DEFAULT_MODULE_PATH         [@"~/Library/Application Support/Sword" stringByExpandingTildeInPath]  
#define DEFAULT_MODULE_PATH_OLD         [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_MODULE_PATH         [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_APPSUPPORT_PATH     [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]

#define DEFAULT_INSTALLER_PATH		[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/InstallMgr/"]
// define for userdefaults
#define userDefaults [NSUserDefaults standardUserDefaults]
// define for default SwordManager
#define defSwordManager [SwordManager defaultManager]


#define DefaultsStrongsHebrewModule                 @"DefaultsStrongsHebrewModule"
#define DefaultsStrongsGreekModule                  @"DefaultsStrongsGreekModule"
#define DefaultsMorphHebrewModule                   @"DefaultsMorphHebrewModule"
#define DefaultsMorphGreekModule                    @"DefaultsMorphGreekModule"

#define StrongsFontName								@"Times New Roman"


// Notification identifiers
#define NotificationModulesChanged				@"NotificationModulesChanged"
#define SendNotifyModulesChanged(X) [[NSNotificationCenter defaultCenter] postNotificationName:NotificationModulesChanged object:X];
#define NotificationBibleSwipeRight				@"NotificationBibleSwipeRight"
#define NotificationBibleSwipeLeft				@"NotificationBibleSwipeLeft"
#define NotificationCommentarySwipeRight		@"NotificationCommentarySwipeRight"
#define NotificationCommentarySwipeLeft			@"NotificationCommentarySwipeLeft"

#define NotificationDevotionalChanged			@"NotificationDevotionalChanged"
#define NotificationRefSelectorResetBooks		@"NotificationRefSelectorResetBooks"
#define NotificationNewPrimaryBible				@"NotificationNewPrimaryBible"
#define NotificationNewPrimaryCommentary		@"NotificationNewPrimaryCommentary"
#define NotificationNewPrimaryDictionary		@"NotificationNewPrimaryDictionary"
#define NotificationReloadDictionaryData		@"NotificationReloadDictionaryData"
#define NotificationResetBibleAndCommentaryView @"NotificationResetBibleAndCommentaryView"

#define NotificationRedisplayPrimaryBible		@"NotificationRedisplayPrimaryBible"
#define NotificationRedisplayPrimaryCommentary	@"NotificationRedisplayPrimaryCommentary"
#define NotificationPrimaryDictionaryChanged	@"NotificationPrimaryDictionaryChanged"

//#define NotificationAddBibleHistoryItem			@"NotificationAddBibleHistoryItem"
//#define NotificationAddCommentaryHistoryItem	@"NotificationAddCommentaryHistoryItem"

#define NotificationToggleMultiList				@"NotificationToggleMultiList"
#define NotificationToggleModuleList			@"NotificationToggleModuleList"

#define NotificationHideInfoPane				@"NotificationHideInfoPane"
#define NotificationShowInfoPane				@"NotificationShowInfoPane"

#define NotificationDisplayBusyIndicator		@"NotificationDisplayBusyIndicator"
#define NotificationHideBusyIndicator			@"NotificationHideBusyIndicator"

#define NotificationShowDownloadsTab			@"NotificationShowDownloadsTab"
#define NotificationShowCommentaryTab			@"NotificationShowCommentaryTab"
