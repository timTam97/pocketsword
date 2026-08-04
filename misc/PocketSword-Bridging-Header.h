//
//  PocketSword-Bridging-Header.h
//  PocketSword
//
//  The app target's window from Swift onto Objective-C. It is down to TWO project
//  imports, and there is nothing else it could usefully import: as of
//  SWORD_REMOVAL_PLAN.md Phase 5 the target is pure Swift apart from
//  Classes/globals.h and the vendored externals/MBProgressHUD.
//
//  ── What this header used to be for, and why that is over ──────────────────
//
//  This was the load-bearing artifact of the whole Swift migration. A Swift bridging
//  header is parsed in **Objective-C mode, not Obj-C++**, so it can never see a
//  `sword::` type — and the entire interop scheme (clean Foundation-only `Sword*.h`
//  facades with all C++ quarantined in sibling `Sword*+Cpp.h` headers imported only
//  by `.mm` files) existed to keep C++ out of anything Swift imported. Every import
//  below carried a comment explaining why it was safe; a wrong add re-tainted the
//  whole Swift import graph.
//
//  None of that applies now. Phase 5 deleted externals/sword, the Sword*.{h,mm,+Cpp.h}
//  bridge, VerseEnumerator, SwordModuleTextEntry, utils.h, externals/ZipArchive, and
//  finally PSSearchEngine.{h,mm} (ported to Swift in step 8) — so there is no C++ in
//  the target to keep out. Step 11 then removed the build settings that supported it:
//  CLANG_CXX_LANGUAGE_STANDARD (`c++0x`), OTHER_LDFLAGS (`-licucore`),
//  HEADER_SEARCH_PATHS (externals/sword/include + the long-dead externals/clucene),
//  and SWIFT_OBJC_INTERFACE_HEADER_NAME.
//
//  That last one is why the two system-framework umbrellas below are also gone.
//  They were not here for Swift — Swift imports UIKit/WebKit/MessageUI itself. They
//  were here for the **generated** header, PocketSword-Swift.h: Obj-C++ TUs under
//  `c++0x` do not honour its `@import Foundation;`-style module imports, so any
//  system protocol an @objc Swift class conformed to (MFMailComposeViewControllerDelegate,
//  WKNavigationDelegate) had to be resolvable by the time a `.mm` consumed the
//  generated header, and pre-importing the umbrella here was how that happened. With
//  no `.mm` left there is no consumer, so SWIFT_OBJC_INTERFACE_HEADER_NAME is unset
//  and the generated header is no longer produced.
//
//  Do NOT re-add any of it. If a future change needs a Swift class visible to Obj-C,
//  the thing to reconsider is whether that Obj-C should exist at all.
//

// globals.h — the Obj-C source of truth for the Defaults* / notification-name /
// ShownTab / PSSearch* constants and enums. Swift needs it for the NS_ENUMs it still
// uses by their bare cases (PSSearchType / PSSearchRange / ShownTab / ModuleType) and
// for the ATTRTYPE_* / SW_OUTPUT_*_KEY / SWMOD_* literals that Phase 5 step 2 moved
// here out of the (now deleted) SwordModule.h and SwordManager.h.
//
// Classes/AppConstants.swift mirrors every wire string in it BYTE-FOR-BYTE and the
// two are dual-maintained — change a literal in one, change it in the other, or
// persisted data breaks. The test bundle's bridging header imports this same file,
// and it is the ONLY thing either of them imports from the project.
#import "globals.h"

// MBProgressHUD.h — vendored Foundation/UIKit/CoreGraphics-only Obj-C (no C++), and
// the last Objective-C source file in the target. Its one Swift consumer is
// PSTabBarControllerDelegate.displayTitle:. PSDictionaryViewController used to show
// one while caching dictionary keys and conformed to MBProgressHUDDelegate, but the
// baked store made that cache dance unnecessary and Phase 5 step 1 deleted it — so
// only the class, not the delegate protocol, is still needed.
#import "MBProgressHUD.h"
