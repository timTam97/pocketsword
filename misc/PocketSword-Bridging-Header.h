#import <MessageUI/MessageUI.h>  // system framework umbrella (NOT a project
// header). The Swift PSAboutScreenController (Wave 2) conforms to
// MFMailComposeViewControllerDelegate for the feedback-email flow, so the
// generated PocketSword-Swift.h declares that protocol in PSAboutScreenController's
// @interface conformance list. The bridging header is #imported into the generated
// header, so importing the MessageUI umbrella here makes MFMailComposeViewControllerDelegate
// resolvable in every .mm that consumes PocketSword-Swift.h — Obj-C++ TUs do not
// honour the generated header's `@import MessageUI;` (clang module-import is off
// for c++0x).
#import <WebKit/WebKit.h>  // system framework umbrella, same rationale as MessageUI
// above. After Wave 4 (FINAL) the @objc(PSTabBarControllerDelegate) coordinator
// conforms to WKNavigationDelegate and exposes -webView:decidePolicyForNavigationAction:
// decisionHandler:, so the generated PocketSword-Swift.h now declares WKNavigationDelegate /
// WKNavigationActionPolicy / WKWebView / WKNavigationAction at the class level. WebKit
// previously reached the generated header transitively via PSWebView.h, but PSWebView
// went Swift in Wave 4 and its header was deleted — so the umbrella must be imported
// here directly. Obj-C++ TUs (PSSearchEngine.mm / SwordManager.mm / SwordModule.mm)
// consume the generated header and do not honour its `@import WebKit;` under c++0x.
// globals.h MUST stay ahead of the Sword*.h chain below. As of
// SWORD_REMOVAL_PLAN.md Phase 5 step 2 it carries the shared constants that used to
// live only in SwordModule.h / SwordManager.h (the ATTRTYPE_* / SW_OUTPUT_*_KEY
// keys, the SWMOD_CONF_FEATURE_* strings, and `ModuleType`), because surviving Swift
// files read them and those headers are deleted in step 7. Both copies are guarded,
// so whichever is seen first wins — and it should be this one, so the eventual
// deletion changes nothing about which definition Swift compiled against.
#import "globals.h"
// PocketSwordAppDelegate (+ main.m) was migrated to Swift in Wave 4 (FINAL) —
// PocketSwordAppDelegate.swift is now the @main entry point and main.m is deleted.
// Its former PocketSwordAppDelegate.{h,mm} are removed, so this line is gone. The
// Swift @objc(PocketSwordAppDelegate) class lives in the same module; Swift callers
// (PocketSwordSceneDelegate.swift) reference it directly, and the one Obj-C++ caller
// (PSTabBarControllerDelegate.mm: [PocketSwordAppDelegate sharedAppDelegate].urlToOpen)
// reaches it via the generated PocketSword-Swift.h. Do NOT re-import a
// PocketSwordAppDelegate.h here.
// MBProgressHUD.h is a vendored Foundation/UIKit/CoreGraphics-only Obj-C class
// (externals/MBProgressHUD) — no C++. Its remaining Swift consumer is
// PSTabBarControllerDelegate.displayTitle:. PSDictionaryViewController used to show
// one while caching dictionary keys and conformed to MBProgressHUDDelegate, but the
// baked store made the whole cache dance unnecessary and Phase 5 step 1 deleted it,
// so only the class (not the delegate protocol) is still needed. MBProgressHUD
// itself stays Obj-C, and survives the phase.
#import "MBProgressHUD.h"
// PSWebView was migrated to Swift in Wave 4 (render-path cluster) — its former
// PSWebView.{h,mm} are deleted. The Swift @objc(PSWebView) class and the @objc
// PSWebViewDelegate protocol live in the same module, so Swift callers (the render
// VC base PSModuleViewController.swift) reference them directly; the Obj-C++
// coordinator (PSTabBarControllerDelegate.mm) reaches them via the generated
// PocketSword-Swift.h. Do NOT re-import PSWebView.h here.
// (PSTabBarControllerDelegate was migrated to Swift in Wave 4 (FINAL) — it is the
// LAST app-layer file ported. Its former PSTabBarControllerDelegate.{h,mm} are
// deleted. The Swift @objc(PSTabBarControllerDelegate) class — plus the
// @objc(PSLoadingViewController) sidecar and the RestorePositionType / PollingType
// enums that rode along in the old translation unit — live in the same module, so
// Swift callers (PocketSwordSceneDelegate, PocketSwordAppDelegate, the render-path
// VC base PSModuleViewController) reference them directly. No Obj-C++ caller of the
// coordinator remains, so this line is gone. Do NOT re-import a
// PSTabBarControllerDelegate.h here.)
// The SWORD BRIDGE IS GONE (SWORD_REMOVAL_PLAN.md Phase 5 step 7).
//
// This block used to import SwordModuleTextEntry.h, VerseEnumerator.h,
// SwordManager.h, SwordModule.h, SwordDictionary.h and SSZipArchive.h — the
// Foundation-only facades over the Obj-C++ bridge, plus the vendored unzip. All of
// those files are deleted:
//
//  * The Sword*.{h,mm,+Cpp.h} chain, VerseEnumerator and utils.h went with the
//    engine. Everything they provided now comes from the baked
//    Resources/PSContent.sqlite via the pure-Swift PSContentStore / PSContentReader
//    / PSBookOSISResolver.
//  * SwordModuleTextEntry (the one clean Obj-C DTO) became the Swift
//    PSVerseTextEntry — there is no Swift/Obj-C++ boundary left for a DTO to cross.
//  * SSZipArchive's only two callers were the module-seeding paths, deleted in
//    step 9 along with the zips they unpacked.
//
// Do NOT re-add any of them. The whole reason this header was carefully curated —
// keeping C++ out of Swift's import graph — no longer applies, because there is no
// C++ in the target.
#import "PSSearchEngine.h"
// (PSHistoryController was migrated to Swift in Wave 3 — its former
// PSHistoryController.{h,mm} are deleted. The Swift @objc(PSHistoryController)
// class lives in the same module, so Swift callers (PSModuleSearchController,
// PSBookmarksNavigatorController) reference it directly; the Obj-C++ callers
// (PocketSwordAppDelegate.mm, PSModuleViewController.mm, PSTabBarControllerDelegate.mm)
// reach it via the generated PocketSword-Swift.h.)
// (PSPreferencesFontTableViewController was migrated to Swift in Wave 3; its members
// live in that .swift file, visible to Swift callers in the same module and to any
// Obj-C TU via the generated PocketSword-Swift.h. The prefs cluster —
// PSPreferencesController / PSBasePreferencesController — is also Swift.)
