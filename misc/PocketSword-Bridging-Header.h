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
