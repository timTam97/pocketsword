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
#import "PSWebView.h"
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
// PSModuleController.h is C++-clean (its only #import is the SwordModule.h facade
// above; every method signature is Foundation-typed). The Swift PSHistoryItem
// (migration step 1.2) calls +[PSModuleController getFirstRefAvailable] on its
// legacy empty-array seed path, so its declaration must be visible here.
#import "PSModuleController.h"
// PSDictionaryViewController.h is C++-clean (its only #import is the UIKit-only
// MBProgressHUD.h). The Swift PSDictionaryOverlayViewController (Wave 2) holds a
// `PSDictionaryViewController *dictionaryViewController` property faithful to the
// original Obj-C surface, so the type must be a visible Swift type here. (The
// header's `@class PSDictionaryOverlayViewController;` forward decl is satisfied
// by the generated PocketSword-Swift.h at compile of the .mm importers.)
#import "PSDictionaryViewController.h"
// PSBookmarksNavigatorController.h is Foundation/UIKit-only (no #import lines, no
// C++; just a `@class PSBookmarkFolder;` forward decl). The Swift
// PSBookmarksAddTableViewController (Wave 2) pushes a PSBookmarksNavigatorController
// when the user taps the folder row, so the type must be a visible Swift type
// here. PSBookmarksNavigatorController itself stays Obj-C++ and consumes the Swift
// add-bookmark VC via the generated PocketSword-Swift.h in its .mm (no cycle: the
// .h imports nothing).
#import "PSBookmarksNavigatorController.h"
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
// PSHistoryController.h is C++-clean (its only #import is globals.h; it is a
// UITableViewController with Foundation-typed methods). The Wave-3 Swift
// PSModuleSearchController calls +[PSHistoryController addHistoryItem:] when the
// user taps a search result, so the type must be Swift-visible here.
// PSHistoryController itself stays Obj-C++ during Wave 3.
#import "PSHistoryController.h"
// (PSPreferencesFontTableViewController and PSPreferencesModuleSelectorTableViewController
// were migrated to Swift in Wave 3; their members live in the respective .swift files,
// visible to Swift callers in the same module and to any Obj-C TU via the generated
// PocketSword-Swift.h. The Wave-3 prefs cluster — PSPreferencesController /
// PSModulePreferencesController / PSBasePreferencesController — is also Swift.)
