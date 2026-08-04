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
typedef NS_ENUM(NSInteger, ShownTab) {
    BibleTab = 1,
    CommentaryTab,
	DictionaryTab,
	// DevotionalTab and DownloadsTab are dead placeholders kept so that the
	// enum ordinals do not shift (they may be persisted in NSUserDefaults).
	// The devotional and in-app download features have both been removed.
	DevotionalTab,
	DownloadsTab,
	PreferencesTab
};

typedef NS_ENUM(NSInteger, ShownMultiListTab) {
	HistoryTab = 0,
	SearchTab
};

typedef NS_ENUM(NSInteger, PSSearchType) {
	AndSearch = 0,
	OrSearch,
	ExactSearch
};

typedef NS_ENUM(NSInteger, PSSearchRange) {
	AllRange = 0,
	OTRange,
	NTRange,
	BookRange
};

#pragma mark - Constants migrated out of the SWORD headers (Phase 5 step 2)

// SWORD_REMOVAL_PLAN.md Phase 5 step 2. These lived in SwordModule.h /
// SwordManager.h, which step 7 deletes — but SURVIVING files read them, so they
// have to be somewhere Swift can still see afterwards. globals.h is that place:
// both bridging headers already import it, so test and app code follow
// automatically with no other change.
//
// This commit adds them here and does NOT remove the originals, because the
// SWORD headers are still in the tree and a duplicate `#define` of an identical
// string is a warning at best. The `#ifndef` guards make the two definitions
// coexist for exactly as long as step 7 takes: while SwordModule.h is present it
// wins (it is imported first via the bridging header chain), and once it is gone
// these take over unchanged. The bodies are byte-identical to the originals —
// verified against SwordModule.h:23-32,36-48 and SwordManager.h:85-92 — which is
// what makes the handover a no-op rather than a behaviour change.
//
// What deliberately did NOT move, having no surviving consumer:
//   * ATTRTYPE_NOTENUMBER — zero references anywhere in the tree.
//   * ModuleCategory — only ever read by SwordManager.mm's own
//     +moduleCategoryAllowed:, which dies with it.
//   * TextPullType — its one Swift caller (PSModuleSearchController:816) is
//     replaced by the store reader in step 5, so it dies with the bridge rather
//     than needing a home. Moving it would have been carrying a corpse.
//   * SWMOD_CONFENTRY_* / SWMOD_CATEGORY_* / SW_OPTION_* — no *surviving* Swift
//     file reads them as macros. The two Swift files that need those values
//     already mirror them as Swift literals (`PSModuleController`'s private
//     `SW` enum and `PSRefLinkRouter`'s type strings), which is the pattern the
//     plan prefers for a Swift-only consumer, and `SwordOracleCaptureTests` —
//     the only reader of the SW_OPTION_* macros — is deleted in step 12.

// Keys in the dictionary -[SwordModule attributeValueForEntryData:] takes, and
// the ones it returns for a reference list. Read by PSContentReader,
// PSDictionaryEntryViewController, PSTabBarControllerDelegate and PSRefLinkRouter.
#ifndef SW_OUTPUT_TEXT_KEY
#define SW_OUTPUT_TEXT_KEY  @"OutputTextKey"
#endif
#ifndef SW_OUTPUT_REF_KEY
#define SW_OUTPUT_REF_KEY   @"OutputRefKey"
#endif

#ifndef ATTRTYPE_TYPE
#define ATTRTYPE_TYPE       @"type"
#endif
#ifndef ATTRTYPE_PASSAGE
#define ATTRTYPE_PASSAGE    @"passage"
#endif
#ifndef ATTRTYPE_MODULE
#define ATTRTYPE_MODULE     @"modulename"
#endif
#ifndef ATTRTYPE_ACTION
#define ATTRTYPE_ACTION     @"action"
#endif
#ifndef ATTRTYPE_VALUE
#define ATTRTYPE_VALUE      @"value"
#endif

// Feature strings -[SwordModule hasFeature:] answers on. Step 5 moves the
// *answers* into content_meta, but the strings themselves stay: they are the keys
// the baked feature set is queried with.
#ifndef SWMOD_CONF_FEATURE_STRONGS
#define SWMOD_CONF_FEATURE_STRONGS       @"StrongsNumbers"
#endif
#ifndef SWMOD_CONF_FEATURE_GREEKDEF
#define SWMOD_CONF_FEATURE_GREEKDEF      @"GreekDef"
#endif
#ifndef SWMOD_CONF_FEATURE_HEBREWDEF
#define SWMOD_CONF_FEATURE_HEBREWDEF     @"HebrewDef"
#endif
#ifndef SWMOD_CONF_FEATURE_GREEKPARSE
#define SWMOD_CONF_FEATURE_GREEKPARSE    @"GreekParse"
#endif
#ifndef SWMOD_CONF_FEATURE_IMAGES
#define SWMOD_CONF_FEATURE_IMAGES        @"Images"
#endif

// `ModuleType` stays an Obj-C enum rather than becoming a Swift one.
//
// Two Swift files use its bare cases — PSModuleViewController:434's
// `module.type == bible` (the verse-per-line gate) and PSLaunchViewController:256's
// seed table — and converting those to a Swift enum means changing the
// `-[SwordModule type]` signature they read it from, which is a bigger change than
// this phase needs and would land in the same commit as a header deletion. The
// values and case names below are the ORIGINAL enum's, so it is the same type by
// any observable measure.
//
// Unlike the string macros above this canNOT lean on `#ifndef <its own name>`: an
// identical object-like macro redefinition is legal C, but a duplicate
// `typedef enum` re-declaring the same enumerators is a hard error. So both this
// header and SwordModule.h wrap their copy in `PS_MODULETYPE_DEFINED` and set it —
// whichever the translation unit sees first defines the type and the other skips.
// When step 7 deletes SwordModule.h, this becomes the only copy with no edit here.
#ifndef PS_MODULETYPE_DEFINED
#define PS_MODULETYPE_DEFINED
typedef enum {
	unknown_type = -1,
	bible       = 0x0001,
	commentary  = 0x0002,
	dictionary  = 0x0004,
	genbook     = 0x0008
}ModuleType;
#endif

#define DefaultsModuleCipherKeysKey					@"DefaultsModuleCipherKeysKey"
#define DefaultsLastRef								@"lastRef"
#define DefaultsLastBible							@"lastBible"
#define DefaultsLastCommentary						@"lastCommentary"
#define DefaultsLastDictionary						@"lastDictionary"

#define DefaultsLastMultiListTab					@"DefaultsLastMultiListTab"
#define DefaultsLastSearchFuzzy						@"DefaultsLastSearchFuzzy"
#define DefaultsLastSearchType						@"DefaultsLastSearchType"
#define DefaultsLastSearchRange						@"DefaultsLastSearchRange"
#define DefaultsLuceneSwept							@"DefaultsLuceneSwept"
#define DefaultsSimplifiedCleanupDone				@"DefaultsSimplifiedCleanupDone"
#define DefaultsModuleChoiceRetired					@"DefaultsModuleChoiceRetired"
#define DefaultsGlobalFontOnly						@"DefaultsGlobalFontOnly"
#define DefaultsLastRefValidated					@"DefaultsLastRefValidated"
#define DefaultsDictKeyCaseFixed					@"DefaultsDictKeyCaseFixed"

#define DefaultsBibleVersePosition					@"bibleVersePosition"
#define DefaultsCommentaryVersePosition				@"commentaryVersePosition"

#define DEFAULT_MODULE_PATH_OLD     [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_MODULE_PATH         [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_BUILTIN_MODULE_PATH	[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/Built-in/"]
#define DEFAULT_APPSUPPORT_PATH     [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]
#define DEFAULT_BOOKMARKS_PATH		[[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/"]

#define DEFAULT_INSTALLER_PATH		[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex: 0] stringByAppendingString: @"/InstallMgr/"]
#define DEFAULT_MMM_PATH			[NSTemporaryDirectory() stringByAppendingPathComponent:@"MMM"]


// define for userdefaults
#define userDefaults [NSUserDefaults standardUserDefaults]

// Default Modules
// RETIRED: these "the user deleted this bundled module, don't re-seed it" flags are
// no longer written — there is no removal UI, so a set flag could never be cleared
// and would suppress a bundled module forever. The DefaultsModuleChoiceRetired
// migration clears any that are already set. Declarations kept so the names are not
// reused.
#define DefaultsKJVRemoved							@"DefaultsKJVRemoved"
#define DefaultsMHCCRemoved							@"DefaultsMHCCRemoved"
#define DefaultsStrongsRealHebrewRemoved			@"DefaultsStrongsRealHebrewRemoved"
#define DefaultsRobinsonRemoved						@"DefaultsRobinsonRemoved"
#define DefaultsStrongsRealGreekRemoved				@"DefaultsStrongsRealGreekRemoved"

// Preferences - general
// RETIRED, NOT REUSABLE: the three lexicon-role keys are no longer read or written —
// the roles are hardcoded (BundledModules in AppConstants.swift). A persisted value
// can legitimately be the localized string "None", so honouring a stale one would
// break Strong's / morph lookups.
#define DefaultsStrongsHebrewModule                 @"DefaultsStrongsHebrewModule"
#define DefaultsStrongsGreekModule                  @"DefaultsStrongsGreekModule"
#define DefaultsMorphHebrewModule                   @"DefaultsMorphHebrewModule"
#define DefaultsMorphGreekModule                    @"DefaultsMorphGreekModule"
#define DefaultsFullscreenModePreference			@"fullscreenModePreference"
#define DefaultsInsomniaPreference					@"insomniaPreference"

// Feature flags (see PSFeatureFlags.swift) - absent means off
#define DefaultsVoiceRefEnabledPreference			@"voiceRefEnabled"

// Preferences - per module
#define GetBoolPrefForMod(Pref,Mod)			[[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define GetStringPrefForMod(Pref,Mod)		[[NSUserDefaults standardUserDefaults] stringForKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define GetIntegerPrefForMod(Pref,Mod)		[[NSUserDefaults standardUserDefaults] integerForKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define SetBoolPrefForMod(b,Pref,Mod)		[[NSUserDefaults standardUserDefaults] setBool:b forKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define SetObjectPrefForMod(o,Pref,Mod)		[[NSUserDefaults standardUserDefaults] setObject:o forKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define SetIntegerPrefForMod(i,Pref,Mod)	[[NSUserDefaults standardUserDefaults] setInteger:i forKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]
#define RemovePrefForMod(Pref,Mod)			[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_%@", Pref, Mod]]

		// from createHTMLString:
#define DefaultsFontNamePreference					@"fontNamePreference"
#define DefaultsFontSizePreference					@"fontSizePreference"
#define DefaultsFontDefaultsPreference				@"fontDefaultsPreference"

		// from attributeValueForEntryData: && getChapter:
#define DefaultsStrongsPreference					@"strongsPreference"
#define DefaultsMorphPreference						@"morphPreference"
#define DefaultsScriptRefsPreference				@"scriptRefsPreference"
#define DefaultsFootnotesPreference					@"footnotesPreference"
#define DefaultsHeadingsPreference					@"headingsPreference"
#define DefaultsRedLetterPreference					@"redLetterPreference"
#define DefaultsVPLPreference						@"vplPreference"
#define DefaultsGreekAccentsPreference				@"greekAccentsPreference"
#define DefaultsHVPPreference						@"hvpPreference"
#define DefaultsHebrewCantillationPreference		@"hebrewCantillationPreference"
#define DefaultsGlossesPreference					@"glossesPreference"

#define StrongsFontName								@"Times New Roman"
#define PSGreekStrongsFontName						@"Gentium Plus"
#define PSHebrewStrongsFontName						@"Ezra SIL"
#define PSDefaultFontName							@"Helvetica Neue"
#define PSFolderSeparatorString						@":::"
#define PSHistoryMaxEntries							100
#define PSHistoryName								@"bibleHistory"

#define BookNameString								@"BookNameString"
#define ChapterString								@"ChapterString"
#define VerseString									@"VerseString"

#define BibleTabTitleString							@"BibleTabTitleString"
#define CommentaryTabTitleString					@"CommentaryTabTitleString"

// Notification identifiers
#define NotificationBibleSwipeRight				@"NotificationBibleSwipeRight"
#define NotificationBibleSwipeLeft				@"NotificationBibleSwipeLeft"
#define NotificationCommentarySwipeRight		@"NotificationCommentarySwipeRight"
#define NotificationCommentarySwipeLeft			@"NotificationCommentarySwipeLeft"

#define NotificationRefSelectorResetBooks		@"NotificationRefSelectorResetBooks"
#define NotificationNewPrimaryBible				@"NotificationNewPrimaryBible"
#define NotificationNewPrimaryCommentary		@"NotificationNewPrimaryCommentary"
#define NotificationNewPrimaryDictionary		@"NotificationNewPrimaryDictionary"
#define NotificationReloadDictionaryData		@"NotificationReloadDictionaryData"
#define NotificationResetBibleAndCommentaryView @"NotificationResetBibleAndCommentaryView"

#define NotificationRedisplayPrimaryBible		@"NotificationRedisplayPrimaryBible"
#define NotificationRedisplayPrimaryCommentary	@"NotificationRedisplayPrimaryCommentary"
#define NotificationBookmarksChanged			@"NotificationBookmarksChanged"
#define NotificationHistoryChanged				@"NotificationHistoryChanged"

#define NotificationToggleMultiList				@"NotificationToggleMultiList"
#define NotificationToggleNavigation            @"NotificationToggleNavigation"

#define NotificationHideInfoPane				@"NotificationHideInfoPane"
#define NotificationShowInfoPane				@"NotificationShowInfoPane"
#define NotificationRotateInfoPane				@"NotificationRotateInfoPane"

#define NotificationShowCommentaryTab			@"NotificationShowCommentaryTab"
#define NotificationShowBibleTab				@"NotificationShowBibleTab"

#define NotificationAddBookmarkInFolder			@"NotificationAddBookmarkInFolder"

#define NotificationUpdateSelectedReference		@"NotificationUpdateSelectedReference"

#define ROTATION_LOCK_POSITION					@"rotationLockedPosition"

typedef NS_ENUM(NSInteger, RotationPosition) {
	RotationEnabled,
	RotationLockedInPortrait,
	RotationLockedInLandscape
};


