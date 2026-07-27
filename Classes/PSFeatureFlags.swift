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
    /// Off by default until the differential gate has been run exhaustively; the
    /// flip to default-on is its own commit so it is revertible by itself, and the
    /// flag is removed in Phase 5 when SWORD goes.
    ///
    /// The flag gates *intent*; `PSContentReader.isAvailable` gates *capability*,
    /// and every call site also falls back to SWORD if a specific read returns nil.
    ///
    ///     xcrun simctl spawn booted defaults write org.timsams.PocketSword swiftContentReader -bool YES
    ///
    /// (bundle id differs per configuration — see CLAUDE.md.)
    static var swiftContentReader: Bool {
        UserDefaults.standard.bool(forKey: Defaults.swiftContentReaderPreference)
    }
}
