//
//  PSRefLinkRouter.swift
//  PocketSword
//
//  Where an `action=showRef` link goes, as a pure function a test can drive over
//  every baked link. `PSModuleController.data(forLink:)` cannot answer this: it
//  only decodes a URL and stamps `type="scriptRef"`, `action="showRef"` on any
//  `sword://` host.
//
//  PSRefSemanticsTests uses it to prove all 14,989 baked `sword://Strongs*` links
//  (the only `sword://` links in the content) take the **dictionary** arm. The
//  module type comes from `content_meta` (`module.<name>.type`), which is
//  "Lexicons / Dictionaries" for all three lexicons.
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

    /// The module-type strings (`SWMOD_CATEGORY_*`, and the `module.<name>.type`
    /// values in `content_meta`).
    static let typeBible = "Biblical Texts"
    static let typeCommentary = "Commentaries"
    static let typeDictionary = "Lexicons / Dictionaries"
    static let typeGenbook = "Generic Books"

    /// Map a type string to the arm it selects — including the **bible default**,
    /// which a naive `type == "Biblical Texts" || type == "Commentaries"`
    /// comparison gets wrong: an *unrecognised* type string takes the bible arm,
    /// not the dictionary arm. All five bundled modules are recognised, so this
    /// only matters for a hypothetical sixth.
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
    ///     not installed**. Both nils route to `.bibleRef`.
    ///
    ///     if mod == nil { bibleRef }                           // no module named
    ///     else if not installed || type == bible
    ///          || type == commentary { bibleRef }
    ///     else { dictionary }
    static func destination(forModuleName moduleName: String?,
                            moduleType: String?) -> Destination {
        guard let moduleName = moduleName, !moduleName.isEmpty else {
            // No module component: it is one of our own refs.
            return .bibleRef
        }
        guard let moduleType = moduleType else {
            // Named but not installed: the bible arm. Any "not installed" placeholder
            // is the caller's business.
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
