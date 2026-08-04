//
//  PSRefLinkRouter.swift
//  PocketSword
//
//  Where an `action=showRef` link goes. Extracted verbatim from the inline
//  predicate at the top of `PSTabBarControllerDelegate`'s
//  `webView(_:decidePolicyFor:decisionHandler:)` (Phase 4 of
//  SWORD_REMOVAL_PLAN.md, step 3).
//
//  ## Why this exists
//
//  Phase 4 step 8 deletes `-[SwordModule attributeValueForEntryData:]`'s
//  `scriptRef` branch on the finding that no shipped content can reach it. Three
//  parts of that finding are pure data assertions over the baked store, but the
//  fourth is a *routing* claim: that all 14,989 baked `sword://Strongs*` links —
//  the only `sword://` links anywhere in the content — take the **dictionary** arm
//  rather than the bible-ref arm that leads to `scriptRef`.
//
//  `PSModuleController.data(forLink:)` cannot answer that. It only decodes a URL,
//  and it unconditionally stamps `type="scriptRef"`, `action="showRef"` on any
//  `sword://` host; it knows nothing about where the link goes. Asserting on it
//  would prove nothing, which would leave the deletion resting on simulator
//  evidence alone. The decision actually lived inline in the web delegate, so it
//  is lifted here as a pure function that a test can drive over every baked link.
//
//  This is a refactor with **no behaviour change**: `destination(for:moduleType:)`
//  is the original three-way `if` transcribed, and the delegate now calls it.
//
//  ## Module type without SWORD
//
//  The caller passes the module's type string. In production that comes from
//  `SwordManager`; the test reads `module.<name>.type` out of the store's
//  `content_meta` (`PSContentStore.moduleMeta(_:key:)`), which is
//  "Lexicons / Dictionaries" for all three lexicons — so the assertion needs
//  neither the engine nor a live `SwordManager`, and survives Phase 5.
//

import Foundation

enum PSRefLinkRouter {

    /// The three arms of the `showRef` branch.
    enum Destination: Equatable {
        /// A bible/commentary reference: display it, via the `scriptRef` lookup.
        /// Reached when the link names no module, or a module that is a bible or a
        /// commentary, **or one that is not installed at all**.
        case bibleRef
        /// A dictionary entry: render the lexicon entry into the info popup.
        case dictionary
    }

    /// The module-type strings (`SWMOD_CATEGORY_*` in `SwordManager.h`, and the
    /// `module.<name>.type` values in `content_meta`). Mirrored as literals because
    /// Obj-C `@"…"` #defines do not import into Swift — same approach as
    /// `PSModuleController`'s `SW` enum.
    static let typeBible = "Biblical Texts"
    static let typeCommentary = "Commentaries"
    static let typeDictionary = "Lexicons / Dictionaries"
    static let typeGenbook = "Generic Books"

    /// Map a type string to the arm it selects, reproducing
    /// `+[SwordModule moduleTypeForModuleTypeString:]` exactly — including its
    /// **`ModuleType ret = bible` default**, which is the part a naive
    /// `type == "Biblical Texts" || type == "Commentaries"` string comparison gets
    /// wrong. That default means an *unrecognised* type string (anything that is
    /// not one of the four categories) has `module.type == bible` and therefore
    /// takes the bible arm, not the dictionary arm.
    ///
    /// All five bundled modules are recognised (`content_meta` holds "Biblical
    /// Texts", "Commentaries" and three "Lexicons / Dictionaries"), so this only
    /// matters for a hypothetical sixth — but it is the difference between a
    /// transcription and a rewrite.
    private static func isBibleOrCommentaryType(_ typeString: String) -> Bool {
        switch typeString {
        case typeDictionary, typeGenbook:
            return false
        default:
            // typeBible, typeCommentary, and anything unrecognised (which
            // moduleTypeForModuleTypeString maps to `bible`).
            return true
        }
    }

    /// Where an `action=showRef` link goes.
    ///
    /// - Parameters:
    ///   - moduleName: the link's `modulename` attribute — `data(forLink:)` sets
    ///     this from the URL host, so it is nil for `sword:///Gen+1:1` (no host).
    ///   - moduleType: the named module's type string, or **nil if the module is
    ///     not installed**. Those two nils mean different things to the caller but
    ///     the same thing here, which is why the original `if` reads the way it
    ///     does.
    ///
    /// Transcribed from `PSTabBarControllerDelegate`:
    ///
    ///     if mod == nil { isABibleRef = true }                 // no module named
    ///     else if modToUse == nil                              // not installed
    ///          || modToUse.type == bible
    ///          || modToUse.type == commentary { isABibleRef = true }
    ///     else { /* dictionary arm */ }
    static func destination(forModuleName moduleName: String?,
                            moduleType: String?) -> Destination {
        guard let moduleName = moduleName, !moduleName.isEmpty else {
            // No module component: it is one of our own refs.
            return .bibleRef
        }
        guard let moduleType = moduleType else {
            // Named but not installed. The delegate still takes the bible arm and
            // then substitutes its "not installed" placeholder, so the routing
            // answer here is .bibleRef — the placeholder is the caller's business.
            return .bibleRef
        }
        return isBibleOrCommentaryType(moduleType) ? .bibleRef : .dictionary
    }

    /// Convenience over a `data(forLink:)` dictionary, so the delegate and the test
    /// both read the module name out of it the same way.
    static func destination(forLinkData data: [AnyHashable: Any],
                            moduleType: String?) -> Destination {
        // `data(forLink:)` stores NSNull for a hostless sword:// URL, not nil, so
        // the `as? String` is what turns that back into "no module named".
        let name = data[ATTRTYPE_MODULE] as? String
        return destination(forModuleName: name, moduleType: moduleType)
    }
}
