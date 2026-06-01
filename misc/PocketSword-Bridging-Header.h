#import <MessageUI/MessageUI.h>  // system framework umbrella (NOT a project
// header). The Swift PSAboutScreenController (Wave 2) conforms to
// MFMailComposeViewControllerDelegate for the feedback-email flow, so the
// generated PocketSword-Swift.h declares that protocol in PSAboutScreenController's
// @interface conformance list. The bridging header is #imported into the generated
// header, so importing the MessageUI umbrella here makes MFMailComposeViewControllerDelegate
// resolvable in every .mm that consumes PocketSword-Swift.h — Obj-C++ TUs do not
// honour the generated header's `@import MessageUI;` (clang module-import is off
// for c++0x). This mirrors how WebKit reaches the generated header via PSWebView.h.
#import "globals.h"
// PocketSwordAppDelegate.h is a Foundation+UIKit-only @objc facade (no C++ leak —
// it forward-@class-references PSResizing / PSTabBarControllerDelegate only). The
// Swift PocketSwordSceneDelegate (Wave 4) reaches the app delegate via
// +sharedAppDelegate, sets .tabBarControllerDelegate, and replays the launch URL
// through -application:handleOpenURL:options:, so the app-delegate class must be a
// visible Swift type here. PocketSwordAppDelegate itself stays Obj-C++ (it is part
// of the launch path and migrates after the scene delegate).
#import "PocketSwordAppDelegate.h"
// MBProgressHUD.h is a vendored Foundation/UIKit/CoreGraphics-only Obj-C class
// (externals/MBProgressHUD) — no C++. The Swift PSDictionaryViewController (Wave
// 3) shows an MBProgressHUD while caching dictionary keys and conforms to
// MBProgressHUDDelegate, so both the class and its delegate protocol must be
// Swift-visible here. MBProgressHUD itself stays Obj-C.
#import "MBProgressHUD.h"
// PSWebView was migrated to Swift in Wave 4 (render-path cluster) — its former
// PSWebView.{h,mm} are deleted. The Swift @objc(PSWebView) class and the @objc
// PSWebViewDelegate protocol live in the same module, so Swift callers (the render
// VC base PSModuleViewController.swift) reference them directly; the Obj-C++
// coordinator (PSTabBarControllerDelegate.mm) reaches them via the generated
// PocketSword-Swift.h. Do NOT re-import PSWebView.h here.
// PSTabBarControllerDelegate.h is the central coordinator's PUBLIC header. It was
// de-tainted in Wave 0e (all <swmgr.h>/<swmodule.h>/<localemgr.h>/etc. removed —
// the one sword::LocaleMgr use moved behind +[SwordManager translate...]) so it is
// now Foundation+WebKit-only and Swift-importable. The Swift render-path VC base
// (PSModuleViewController.swift, Wave 4) holds a `PSTabBarControllerDelegate`
// back-reference, calls its -displayChapter:.../-toggleNavigation and the class
// method +displayTitle:, and uses the PollingType / RestorePositionType enums
// declared here — so the coordinator type + those enums must be Swift-visible.
// The coordinator itself stays Obj-C++ (it is the LAST file migrated). Its header
// only forward-@class/@protocol-references the already-Swift types it touches
// (PSBibleViewController / PSCommentaryViewController / PSModuleSearchControllerDelegate /
// PSDictionaryViewControllerDelegate), which forward decls satisfy during the
// bridging-header parse.
#import "PSTabBarControllerDelegate.h"
#import "SwordModuleTextEntry.h"
#import "VerseEnumerator.h"
// Sword*.h clean facades, sanitized in 0e (all C++ moved to per-class +Cpp.h
// imported only by .mm files). Adding the two top-level facades transitively
// pulls in the clean SwordModule.h / SwordVerseKey.h / SwordKey.h /
// SwordDictionary.h chain — all now Foundation-only and Swift-importable.
#import "SwordManager.h"
#import "SwordModule.h"
// SwordDictionary.h is a clean Foundation-only @objc facade (subclass of
// SwordModule) after Wave 0e — its only leak (-initWithSWModule:swordManager:)
// moved to SwordDictionary+Cpp.h, imported only by .mm files; the header now just
// #imports the clean SwordModule.h facade. PSModuleController.h only @class-
// forward-declares SwordDictionary (never #imports it), so without this the
// generated Swift interface DROPS PSModuleController.primaryDictionary (its type
// is an incomplete Obj-C class to Swift). The Wave-3 Swift PSModuleSelectorController
// reads/compares primaryDictionary, so SwordDictionary must be a visible Swift type
// here. SwordDictionary itself stays Obj-C++.
#import "SwordDictionary.h"
// SwordBook.h is a clean Foundation-only @objc facade (subclass of SwordModule)
// after Wave 0e — its C++ (the versificationmgr include, the
// const sword::VersificationMgr::Book * ivar, -initWithBook:) lives in
// SwordBook+Cpp.h, imported only by .mm files. The Swift chapter/verse
// reference selectors (PSChapterSelectorController / PSVerseSelectorController,
// Wave 2) hold a `SwordBook *book` property, so SwordBook must be a visible
// Swift type here.
#import "SwordBook.h"
// SSZipArchive.h is the clean Foundation-only @objc facade of the vendored
// ZipArchive (externals/ZipArchive) — no C++ leaks. The Swift PSModuleController
// (Wave 4) calls +[SSZipArchive unzipFileAtPath:toDestination:] in
// -installModulesFromZip:..., so the class must be Swift-visible here. ZipArchive
// itself stays Obj-C.
#import "SSZipArchive.h"
// (PSModuleController was migrated to Swift in Wave 4 — its former
// PSModuleController.{h,mm} are deleted. The Swift @objc(PSModuleController) class
// lives in the same module, so Swift callers reference it directly; every Obj-C++
// caller (PSTabBarControllerDelegate.mm, the render cluster, PSLaunchViewController.mm,
// PocketSwordAppDelegate.mm, SwordModule.mm) reaches it via the generated
// PocketSword-Swift.h. The 9 sword:: seams it used were extracted to Foundation
// @objc methods on SwordManager / SwordModule, so no C++ crosses into Swift.)
// (PSDictionaryViewController was migrated to Swift in Wave 3 — its former
// PSDictionaryViewController.h is deleted. The Swift class and the @objc
// PSDictionaryViewControllerDelegate protocol live in the same module, so the
// Swift PSDictionaryOverlayViewController references them directly; any Obj-C++
// TU (PSTabBarControllerDelegate.mm) reaches them via the generated
// PocketSword-Swift.h.)
// (PSBookmarksNavigatorController was migrated to Swift in Wave 3 — its former
// PSBookmarksNavigatorController.{h,mm} are deleted. The Swift @objc class lives
// in the same module, so the Swift PSBookmarkAddViewController references it
// directly; the Obj-C++ PSTabBarControllerDelegate.mm reaches it via the
// generated PocketSword-Swift.h.)
// PSSearchEngine.h is C++-clean (Foundation + globals.h + `@class SwordModule;`
// `@class PSSearchResult;` — all the sword:: / sqlite3 / FTS5 index-build code
// lives in PSSearchEngine.mm, which STAYS Obj-C++ permanently per the plan).
// Its public query-side surface (+engineForModule:/-runQuery:.../-buildWithProgress:/
// -indexIsFresh/-dropIndex) is all Foundation-typed, and every referenced type is
// already Swift-visible: SwordModule (via SwordModule.h above), PSSearchResult (a
// Swift @objc final class), and PSSearchType/PSSearchRange (NS_ENUM in globals.h).
// Exposing it here lets the Wave-3 Swift query-side caller PSModuleSearchController
// drive the engine directly; the engine itself is never rewritten in Swift.
#import "PSSearchEngine.h"
// (PSHistoryController was migrated to Swift in Wave 3 — its former
// PSHistoryController.{h,mm} are deleted. The Swift @objc(PSHistoryController)
// class lives in the same module, so Swift callers (PSModuleSearchController,
// PSBookmarksNavigatorController) reference it directly; the Obj-C++ callers
// (PocketSwordAppDelegate.mm, PSModuleViewController.mm, PSTabBarControllerDelegate.mm)
// reach it via the generated PocketSword-Swift.h.)
// (PSPreferencesFontTableViewController and PSPreferencesModuleSelectorTableViewController
// were migrated to Swift in Wave 3; their members live in the respective .swift files,
// visible to Swift callers in the same module and to any Obj-C TU via the generated
// PocketSword-Swift.h. The Wave-3 prefs cluster — PSPreferencesController /
// PSModulePreferencesController / PSBasePreferencesController — is also Swift.)
