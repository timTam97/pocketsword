//
//  AppConstants.swift
//  PocketSword
//
//  Swift mirror of Classes/globals.h (migration step 0b).
//
//  IMPORTANT: globals.h remains the Obj-C source of truth during the mixed
//  migration phase. This file mirrors every wire string / format BYTE-FOR-BYTE
//  for Swift ergonomics and interop. The persisted key string frequently
//  differs from the Obj-C macro name (e.g. DefaultsLastRef -> "lastRef"), so do
//  NOT "fix" these to match the Swift symbol names — they are load-bearing
//  persisted keys and changing them corrupts user data.
//
//  This is intentional dual-maintenance: when an Obj-C @"literal" or macro value
//  here changes in globals.h, mirror it here too (and vice versa) until Obj-C
//  is fully gone.
//

import Foundation

// MARK: - Defaults keys (mirror of the Defaults*/* @"literal" #defines)
//
// Caseless namespace of static-let String constants. RIGHT-hand value is the
// PERSISTED wire string (== the @"..." literal in globals.h), which is often
// NOT the same as the macro name on the LEFT.

enum Defaults {
    static let moduleCipherKeysKey         = "DefaultsModuleCipherKeysKey"
    static let lastRef                     = "lastRef"                 // macro DefaultsLastRef
    static let lastBible                   = "lastBible"               // macro DefaultsLastBible
    static let lastCommentary              = "lastCommentary"          // macro DefaultsLastCommentary
    static let lastDictionary              = "lastDictionary"          // macro DefaultsLastDictionary

    static let lastMultiListTab            = "DefaultsLastMultiListTab"
    static let lastSearchFuzzy             = "DefaultsLastSearchFuzzy"
    static let lastSearchType              = "DefaultsLastSearchType"
    static let lastSearchRange             = "DefaultsLastSearchRange"
    static let pendingSearchIndexModule    = "PendingSearchIndexModule"
    static let luceneSwept                 = "DefaultsLuceneSwept"
    static let simplifiedCleanupDone       = "DefaultsSimplifiedCleanupDone"
    static let moduleChoiceRetired         = "DefaultsModuleChoiceRetired"
    static let globalFontOnly              = "DefaultsGlobalFontOnly"
    static let lastRefValidated            = "DefaultsLastRefValidated"
    static let dictKeyCaseFixed            = "DefaultsDictKeyCaseFixed"
    /// One-shot: delete the Documents/ trees the SWORD era left behind
    /// (mods.d / modules / locales.d / unused) plus <Caches>/InstallMgr.
    /// SWORD_REMOVAL_PLAN.md Phase 5 step 9. Swift-only — no globals.h macro,
    /// because no Obj-C reads it.
    static let swordRetired = "DefaultsSwordRetired"

    static let bibleVersePosition          = "bibleVersePosition"      // macro DefaultsBibleVersePosition
    static let commentaryVersePosition     = "commentaryVersePosition" // macro DefaultsCommentaryVersePosition

    // Default modules
    //
    // RETIRED: these "the user deleted this bundled module, don't re-seed it" flags
    // are no longer written — there is no removal UI, so a set flag could never be
    // cleared and would suppress a bundled module forever. The `moduleChoiceRetired`
    // migration clears any that are already set. Kept so the names are not reused.
    static let kjvRemoved                  = "DefaultsKJVRemoved"
    static let mhccRemoved                 = "DefaultsMHCCRemoved"
    static let strongsRealHebrewRemoved    = "DefaultsStrongsRealHebrewRemoved"
    static let robinsonRemoved             = "DefaultsRobinsonRemoved"
    static let strongsRealGreekRemoved     = "DefaultsStrongsRealGreekRemoved"

    /// All five retired `Defaults*Removed` flags, for the one-shot migration.
    static let bundledModuleRemovedFlags = [kjvRemoved, mhccRemoved,
                                           strongsRealHebrewRemoved,
                                           robinsonRemoved,
                                           strongsRealGreekRemoved]

    // Preferences - general
    //
    // RETIRED, NOT REUSABLE: the three lexicon-role keys are no longer read or
    // written — the roles are hardcoded (see `BundledModules`). A persisted value can
    // legitimately be the localized string "None" (written by the old
    // removeModule), so honouring a stale one would break Strong's / morph lookups.
    static let strongsHebrewModule         = "DefaultsStrongsHebrewModule"
    static let strongsGreekModule          = "DefaultsStrongsGreekModule"
    static let morphHebrewModule           = "DefaultsMorphHebrewModule"
    static let morphGreekModule            = "DefaultsMorphGreekModule"

    /// The four retired lexicon-role keys, for the one-shot migration.
    static let retiredLexiconKeys = [strongsHebrewModule, strongsGreekModule,
                                     morphHebrewModule, morphGreekModule]
    static let fullscreenModePreference    = "fullscreenModePreference"      // macro DefaultsFullscreenModePreference
    static let insomniaPreference          = "insomniaPreference"            // macro DefaultsInsomniaPreference

    // Feature flags (see PSFeatureFlags) - absent means off
    static let voiceRefEnabledPreference   = "voiceRefEnabled"          // macro DefaultsVoiceRefEnabledPreference
    // **RETIRED** (Phase 5 step 1). Was the Phase-3 kill switch for reading through
    // PSContentReader instead of the SWORD engine. The engine is gone, so the flag
    // is gone with it; the key stays declared and unread so it is not reused, and a
    // device still holding `swiftContentReader = NO` from the Phase-3/4 era is
    // unaffected because nothing consults it. Swift-only: there was never a
    // globals.h macro, because no Obj-C read it.
    static let swiftContentReaderPreference = "swiftContentReader"

    // from createHTMLString:
    static let fontNamePreference          = "fontNamePreference"
    static let fontSizePreference          = "fontSizePreference"
    static let fontDefaultsPreference      = "fontDefaultsPreference"

    // from attributeValueForEntryData: && getChapter:
    static let strongsPreference           = "strongsPreference"
    static let morphPreference             = "morphPreference"
    static let scriptRefsPreference        = "scriptRefsPreference"
    static let footnotesPreference         = "footnotesPreference"
    static let headingsPreference          = "headingsPreference"
    static let redLetterPreference         = "redLetterPreference"
    static let vplPreference               = "vplPreference"
    static let greekAccentsPreference      = "greekAccentsPreference"
    static let hvpPreference               = "hvpPreference"
    static let hebrewCantillationPreference = "hebrewCantillationPreference"
    static let glossesPreference           = "glossesPreference"

    static let rotationLockPosition        = "rotationLockedPosition"        // macro ROTATION_LOCK_POSITION
}

// MARK: - Bundled modules
//
// The app ships exactly these five modules (unpacked from the zips in Resources/
// on first launch) and there is no UI to add, remove, or pick a different one.
// The three lexicon ROLES are fixed by their .conf features and are NOT
// interchangeable: StrongsRealGreek is `Feature=GreekDef`, StrongsRealHebrew is
// `HebrewDef`, Robinson is `GreekParse`.
//
// These replace the former DefaultsStrongsGreekModule / DefaultsStrongsHebrew
// Module / DefaultsMorphGreekModule persisted keys, which are retired (see the
// note next to their declarations above).

enum BundledModules {
    static let bible = "KJV"
    static let commentary = "MHCC"
    static let strongsGreek = "StrongsRealGreek"
    static let strongsHebrew = "StrongsRealHebrew"
    static let morphGreek = "Robinson"

    /// The three fixed-role lexicons, in Dictionary-tab menu order.
    static let lexicons = [strongsGreek, strongsHebrew, morphGreek]

    /// All five bundled modules.
    static let all = [bible, commentary, strongsGreek, strongsHebrew, morphGreek]
}

// MARK: - Font names + misc string / int constants

enum AppConstants {
    static let strongsFontName        = "Times New Roman"   // macro StrongsFontName
    static let greekStrongsFontName   = "Gentium Plus"      // macro PSGreekStrongsFontName
    static let hebrewStrongsFontName  = "Ezra SIL"          // macro PSHebrewStrongsFontName
    static let defaultFontName        = "Helvetica Neue"    // macro PSDefaultFontName
    /// The reading font size used when `fontSizePreference` is absent. Swift-only:
    /// there is no `globals.h` macro and it is not a wire string. ONE constant on
    /// purpose — `SettingsStore` said 12 (and materializes it for the Settings
    /// slider) while `ChapterTextRenderer.Style.current()` said 14, the deleted HTML
    /// shell's own fallback, so after `LaunchCoordinator.resetPreferences()` removed
    /// the key the chapter rendered at 14pt while the slider read 12.
    static let defaultFontSize        = 12
    static let folderSeparatorString  = ":::"               // macro PSFolderSeparatorString
    static let historyMaxEntries      = 100                 // macro PSHistoryMaxEntries (Int)
    static let historyName            = "bibleHistory"      // macro PSHistoryName

    static let bookNameString         = "BookNameString"
    static let chapterString          = "ChapterString"
    static let verseString            = "VerseString"

    static let bibleTabTitleString    = "BibleTabTitleString"
    static let commentaryTabTitleString = "CommentaryTabTitleString"
}

// MARK: - Notification names
//
// rawValue MUST equal the existing @"..." literal in globals.h so that Obj-C and
// Swift observers/posters interoperate during the mixed phase. All of these match
// their macro name. (The one former wire-string mismatch,
// moduleMaintainerModeChanged -> "ModuleMaintainerModeChanged", went away with
// Module Maintainer Mode.)

extension Notification.Name {
    static let bibleSwipeRight              = Notification.Name("NotificationBibleSwipeRight")
    static let bibleSwipeLeft               = Notification.Name("NotificationBibleSwipeLeft")
    static let commentarySwipeRight         = Notification.Name("NotificationCommentarySwipeRight")
    static let commentarySwipeLeft          = Notification.Name("NotificationCommentarySwipeLeft")

    static let refSelectorResetBooks        = Notification.Name("NotificationRefSelectorResetBooks")
    static let newPrimaryBible              = Notification.Name("NotificationNewPrimaryBible")
    static let newPrimaryCommentary         = Notification.Name("NotificationNewPrimaryCommentary")
    static let newPrimaryDictionary         = Notification.Name("NotificationNewPrimaryDictionary")
    static let reloadDictionaryData         = Notification.Name("NotificationReloadDictionaryData")
    static let resetBibleAndCommentaryView  = Notification.Name("NotificationResetBibleAndCommentaryView")

    static let redisplayPrimaryBible        = Notification.Name("NotificationRedisplayPrimaryBible")
    static let redisplayPrimaryCommentary   = Notification.Name("NotificationRedisplayPrimaryCommentary")
    static let bookmarksChanged             = Notification.Name("NotificationBookmarksChanged")
    static let historyChanged               = Notification.Name("NotificationHistoryChanged")

    static let toggleMultiList              = Notification.Name("NotificationToggleMultiList")
    static let toggleNavigation             = Notification.Name("NotificationToggleNavigation")

    static let hideInfoPane                 = Notification.Name("NotificationHideInfoPane")
    static let showInfoPane                 = Notification.Name("NotificationShowInfoPane")
    static let rotateInfoPane               = Notification.Name("NotificationRotateInfoPane")

    static let showCommentaryTab            = Notification.Name("NotificationShowCommentaryTab")
    static let showBibleTab                 = Notification.Name("NotificationShowBibleTab")

    static let addBookmarkInFolder          = Notification.Name("NotificationAddBookmarkInFolder")

    static let updateSelectedReference      = Notification.Name("NotificationUpdateSelectedReference")

    // SwiftUI migration bridge only. Posted after the legacy reset routine clears
    // defaults so observable models can reload without re-persisting old values.
    static let appStateDidReset             = Notification.Name("PocketSwordAppStateDidReset")
}

// MARK: - Per-module preference accessors
//
// ONE canonical implementation of the composite-key format used by the 7 Obj-C
// function-like macros (GetBool/GetString/GetInteger/SetBool/SetObject/
// SetInteger/RemovePrefForMod). The key is built via
//   [NSString stringWithFormat:@"%@_%@", Pref, Mod]
// i.e. pref first, mod second, joined by a single underscore. This MUST stay
// byte-identical to the Obj-C macros or per-module prefs silently break / leak.

extension UserDefaults {
    /// Composite key "<pref>_<mod>" — exact reproduction of "%@_%@" (pref, mod).
    func psModuleKey(_ pref: String, _ mod: String) -> String { "\(pref)_\(mod)" }

    func psBool(_ pref: String, forModule mod: String) -> Bool {
        bool(forKey: psModuleKey(pref, mod))
    }

    func psString(_ pref: String, forModule mod: String) -> String? {
        string(forKey: psModuleKey(pref, mod))
    }

    func psInteger(_ pref: String, forModule mod: String) -> Int {
        integer(forKey: psModuleKey(pref, mod))
    }

    func psSet(_ value: Bool, forPref pref: String, module mod: String) {
        set(value, forKey: psModuleKey(pref, mod))
    }

    func psSet(_ value: Any?, forPref pref: String, module mod: String) {
        set(value, forKey: psModuleKey(pref, mod))
    }

    func psSet(_ value: Int, forPref pref: String, module mod: String) {
        set(value, forKey: psModuleKey(pref, mod))
    }

    func psRemove(_ pref: String, forModule mod: String) {
        removeObject(forKey: psModuleKey(pref, mod))
    }
}

// MARK: - Application paths
//
// Mirror of the DEFAULT_*_PATH expression macros. These re-run
// NSSearchPathForDirectoriesInDomains on EVERY expansion, so they are exposed
// as COMPUTED static vars (never captured `let`s).
//
// The domain split is load-bearing — Documents (module/builtin/bookmarks) vs
// Caches (old/appsupport/installer) vs Temporary (MMM) drives the one-time
// module migration and the iCloud-backup-skip attribute. The first six macros
// concatenate a literal "/" (stringByAppendingString:); MMM uses path-component
// append (stringByAppendingPathComponent:) with NO trailing slash.

enum AppPaths {
    private static func documentsDirectory() -> String {
        NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    }

    private static func cachesDirectory() -> String {
        NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
    }

    /// DEFAULT_MODULE_PATH — Documents + "/"
    static var modulePath: String { documentsDirectory() + "/" }

    /// DEFAULT_MODULE_PATH_OLD — Caches + "/"
    static var modulePathOld: String { cachesDirectory() + "/" }

    /// DEFAULT_BUILTIN_MODULE_PATH — Documents + "/Built-in/"
    static var builtinModulePath: String { documentsDirectory() + "/Built-in/" }

    /// DEFAULT_APPSUPPORT_PATH — Caches + "/"
    static var appSupportPath: String { cachesDirectory() + "/" }

    /// DEFAULT_BOOKMARKS_PATH — Documents + "/"
    static var bookmarksPath: String { documentsDirectory() + "/" }

    /// DEFAULT_INSTALLER_PATH — Caches + "/InstallMgr/"
    static var installerPath: String { cachesDirectory() + "/InstallMgr/" }

    /// DEFAULT_MMM_PATH — Temporary dir, path-component "MMM" (NO trailing slash)
    static var mmmPath: String { (NSTemporaryDirectory() as NSString).appendingPathComponent("MMM") }

    /// The FTS search index for a module: `<Caches>/search/<module>.db`.
    ///
    /// SWORD_REMOVAL_PLAN.md Phase 5 step 6. The index used to live at
    /// `<AbsoluteDataPath>/search/fts.db`, a path that came out of SWORD's own conf
    /// munging (`swmgr.cpp:1110` strips the trailing component for RawLD / RawLD4 /
    /// zLD) and therefore cannot survive the module zips going away. Derived data
    /// belongs in Caches regardless: it is rebuildable, and Caches is the directory
    /// the OS is allowed to purge.
    ///
    /// Keyed by module **name** rather than one file per directory, so two modules
    /// can share the directory — only KJV and MHCC are ever indexed, but nothing
    /// here assumes that.
    static func searchIndexPath(for module: String) -> String {
        (searchIndexDirectory as NSString).appendingPathComponent("\(module).db")
    }

    /// The directory holding every module's search index.
    static var searchIndexDirectory: String {
        (cachesDirectory() as NSString).appendingPathComponent("search")
    }
}

// The `@objc(PSPaths)` shim that used to sit here is DELETED (SWORD_REMOVAL_PLAN.md
// Phase 5 step 8). `AppPaths` is an `enum` namespace and `@objc` cannot be applied
// to an enum's members, so the two search-index paths were re-exposed on a class for
// the one commit-range where `PSSearchEngine` was still Obj-C. The engine is Swift
// now and calls `AppPaths` directly.

// MARK: - Logging shims
//
// DLog/ALog live in misc/PocketSword_Prefix.pch and are invisible to Swift
// (Swift ignores GCC_PREFIX_HEADER). DLog is a DEBUG-only NSLog wrapper; ALog
// always fires. These Swift shims mirror that behaviour.

/// DEBUG-only logging shim mirroring the Obj-C `DLog` macro.
func dlog(_ message: String, file: String = #file, line: Int = #line) {
    #if DEBUG
    NSLog("%@ [Line %d] %@", (file as NSString).lastPathComponent, line, message)
    #endif
}

/// Always-on logging shim mirroring the Obj-C `ALog` macro.
func alog(_ message: String, file: String = #file, line: Int = #line) {
    NSLog("%@ [Line %d] %@", (file as NSString).lastPathComponent, line, message)
}

// MARK: - Reference-string helpers
//
// Migration step 1.1 extracts the two thin Foundation-only SWORD seams that the
// bookmark store (PSBookmarks.swift) depends on out of PSModuleController, per
// the plan's "eliminate thin SWORD seams" guidance (§3 PR 1.1). Both are pure
// string / NSUserDefaults logic — no sword:: / C++ — so they live in the Swift
// helper layer rather than reaching back into the (SwordModule.h-importing)
// PSModuleController header. Behaviour is byte-for-byte identical to the Obj-C
// originals in PSModuleController.mm (+createRefString: / +getCurrentBibleRef);
// those Obj-C methods remain for the many other Obj-C callers during the mixed
// phase.

enum PSRefHelper {

    /// Mirror of +[PSModuleController createRefString:] — normalises the leading
    /// roman-numeral book prefixes to arabic and strips " of John ".
    static func createRefString(_ ref: String) -> String {
        return ref
            .replacingOccurrences(of: "III ", with: "3 ")
            .replacingOccurrences(of: "II ", with: "2 ")
            .replacingOccurrences(of: "I ", with: "1 ")
            .replacingOccurrences(of: " of John ", with: " ")
    }

    /// Mirror of +[PSModuleController getCurrentBibleRef] — reads DefaultsLastRef,
    /// seeding "Genesis 1" the first time.
    static func getCurrentBibleRef() -> String {
        let defaults = UserDefaults.standard
        if let lastRef = defaults.string(forKey: Defaults.lastRef) {
            return lastRef
        }
        defaults.set("Genesis 1", forKey: Defaults.lastRef)
        defaults.synchronize()
        return "Genesis 1"
    }
}
