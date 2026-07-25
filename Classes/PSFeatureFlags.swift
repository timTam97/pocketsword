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
}
