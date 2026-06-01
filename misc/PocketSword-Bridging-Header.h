#import "globals.h"
#import "PSWebView.h"
#import "PSInfoPopupViewController.h"
#import "SwordModuleTextEntry.h"
#import "VerseEnumerator.h"
// Sword*.h clean facades, sanitized in 0e (all C++ moved to per-class +Cpp.h
// imported only by .mm files). Adding the two top-level facades transitively
// pulls in the clean SwordModule.h / SwordVerseKey.h / SwordKey.h /
// SwordDictionary.h chain — all now Foundation-only and Swift-importable.
#import "SwordManager.h"
#import "SwordModule.h"
// PSModuleController.h is C++-clean (its only #import is the SwordModule.h facade
// above; every method signature is Foundation-typed). The Swift PSHistoryItem
// (migration step 1.2) calls +[PSModuleController getFirstRefAvailable] on its
// legacy empty-array seed path, so its declaration must be visible here.
#import "PSModuleController.h"
