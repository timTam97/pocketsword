//
//  PSFeatureFlags.swift
//  PocketSword
//
//  Kill switches for in-progress features. A flag here hides a feature's entry
//  points; the feature's own code stays compiled so it does not rot.
//

import Foundation

enum PSFeatureFlags {
    /// Voice reference ("say a reference to jump to it") is still being worked
    /// on, so the mic button is hidden and the action is inert.
    ///
    /// Off unless the user default is explicitly set. To try it without a
    /// rebuild, either add `-voiceRefEnabled YES` to the scheme's launch
    /// arguments, or on a simulator:
    ///
    ///     xcrun simctl spawn booted defaults write org.timsams.PocketSword voiceRefEnabled -bool YES
    ///
    /// (bundle id differs per configuration — see CLAUDE.md.)
    static var voiceReferenceEnabled: Bool {
        UserDefaults.standard.bool(forKey: Defaults.voiceRefEnabledPreference)
    }

    /// Route the chapter / lexicon / footnote read paths through the pure-Swift
    /// `PSContentReader` over the baked `PSContent.sqlite` instead of the SWORD
    /// engine (SWORD_REMOVAL_PLAN.md Phase 3).
    ///
    /// **Default ON** as of the Phase 3 flag flip, which was gated on the
    /// exhaustive differential run: all 1,189 chapters of both shipped modules at
    /// both option endpoints, plus all 31,102 search-source rows, byte-for-byte
    /// identical to the live engine (see PSDifferentialTests and the flip commit).
    ///
    /// The flag gates *intent*; `PSContentReader.isAvailable` gates *capability*,
    /// and every call site also falls back to SWORD if a specific read returns nil.
    /// So this being on is not a commitment that nothing can go wrong — it is the
    /// preferred path, with the engine still underneath it until Phase 5.
    ///
    /// To turn it OFF (i.e. read through SWORD again) without a rebuild:
    ///
    ///     xcrun simctl spawn booted defaults write org.timsams.PocketSword swiftContentReader -bool NO
    ///
    /// (bundle id differs per configuration — see CLAUDE.md.)
    ///
    /// Note the default-on inversion: `UserDefaults.bool(forKey:)` answers NO for a
    /// missing key, so this cannot read the raw value — an unset key must mean ON.
    /// `object(forKey:)` distinguishes "absent" from "explicitly false", and there
    /// is deliberately no `registerDefaults` anywhere in this app to lean on.
    /// Removed in Phase 5 with the SWORD engine.
    static var swiftContentReader: Bool {
        guard let value = UserDefaults.standard.object(forKey: Defaults.swiftContentReaderPreference) else {
            return true
        }
        return (value as? NSNumber)?.boolValue ?? true
    }
}
