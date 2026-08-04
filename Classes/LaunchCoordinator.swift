import Foundation

struct LaunchResult: Equatable {
    let shouldDisableIdleTimer: Bool
}

final class LaunchCoordinator {
    struct Paths {
        let moduleRoot: String
        let appSupportRoot: String
        let installerRoot: String
        let temporaryRoot: String

        static var live: Paths {
            Paths(
                moduleRoot: AppPaths.modulePath,
                appSupportRoot: AppPaths.appSupportPath,
                installerRoot: AppPaths.installerPath,
                temporaryRoot: AppPaths.mmmPath
            )
        }
    }

    private static let localesVersion = "loadedSWORDLocales-130708"

    private let defaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let fileManager: FileManager
    private let paths: Paths
    private let moduleControllerAvailable: () -> Bool
    private let resetModuleSelections: () -> Void
    private let currentReference: () -> String
    private let referenceResolves: (String) -> Bool
    private let moduleVersion: (String) -> String

    init(
        defaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        fileManager: FileManager = .default,
        paths: Paths = .live,
        moduleControllerAvailable: @escaping () -> Bool = {
            PSModuleController.default() != nil
        },
        resetModuleSelections: @escaping () -> Void = {
            guard let moduleController = PSModuleController.default() else {
                return
            }
            moduleController.primaryBibleName = nil
            moduleController.primaryCommentaryName = nil
            moduleController.primaryDictionaryName = nil
        },
        currentReference: @escaping () -> String = {
            PSModuleController.getCurrentBibleRef() ?? ""
        },
        referenceResolves: @escaping (String) -> Bool = {
            PSBookOSISResolver.shared?.resolve(ref: $0) != nil
        },
        moduleVersion: @escaping (String) -> String = {
            PSContentStore.shared?.moduleVersion($0) ?? "0.0"
        }
    ) {
        self.defaults = defaults
        self.notificationCenter = notificationCenter
        self.fileManager = fileManager
        self.paths = paths
        self.moduleControllerAvailable = moduleControllerAvailable
        self.resetModuleSelections = resetModuleSelections
        self.currentReference = currentReference
        self.referenceResolves = referenceResolves
        self.moduleVersion = moduleVersion
    }

    func prepare() -> LaunchResult? {
        guard moduleControllerAvailable() else {
            return nil
        }

        if defaults.bool(forKey: "reset_PocketSword") {
            resetPreferences()
        }

        retireModuleChoice()
        retirePerModuleFonts()
        validatePersistedReference()
        clearDictionaryKeyCaches()
        removeRetiredSwordFiles()
        try? fileManager.removeItem(atPath: paths.temporaryRoot)

        return LaunchResult(
            shouldDisableIdleTimer: defaults.bool(
                forKey: Defaults.insomniaPreference
            )
        )
    }

    @discardableResult
    func resetPreferences() -> Bool {
        guard moduleControllerAvailable() else {
            return false
        }

        dlog("\nResetting PocketSword")
        defaults.removeObject(forKey: "reset_PocketSword")
        defaults.removeObject(forKey: Defaults.lastRef)
        defaults.removeObject(forKey: Defaults.lastBible)
        defaults.removeObject(forKey: Defaults.lastCommentary)
        defaults.removeObject(forKey: Defaults.lastDictionary)
        defaults.removeObject(forKey: Defaults.fontNamePreference)
        defaults.removeObject(forKey: Defaults.fontSizePreference)
        defaults.removeObject(forKey: Defaults.vplPreference)
        defaults.removeObject(forKey: Defaults.redLetterPreference)
        defaults.removeObject(forKey: Defaults.insomniaPreference)
        defaults.removeObject(forKey: "bibleHistory")
        defaults.removeObject(forKey: "commentaryHistory")
        defaults.removeObject(forKey: Defaults.moduleCipherKeysKey)
        defaults.removeObject(forKey: Self.localesVersion)
        defaults.synchronize()

        let modulePreferences = [
            Defaults.redLetterPreference,
            Defaults.strongsPreference,
            Defaults.morphPreference,
            Defaults.greekAccentsPreference,
            Defaults.hvpPreference,
            Defaults.hebrewCantillationPreference,
            Defaults.scriptRefsPreference,
            Defaults.footnotesPreference,
            Defaults.headingsPreference,
            Defaults.glossesPreference,
            Defaults.fontSizePreference,
            Defaults.fontNamePreference,
        ]
        for module in BundledModules.all {
            for preference in modulePreferences {
                defaults.psRemove(preference, forModule: module)
            }
        }
        defaults.synchronize()

        resetModuleSelections()
        notificationCenter.post(name: .appStateDidReset, object: nil)
        notificationCenter.post(name: .redisplayPrimaryBible, object: nil)
        return true
    }

    private func retireModuleChoice() {
        guard !defaults.bool(forKey: Defaults.moduleChoiceRetired) else {
            return
        }

        for flag in Defaults.bundledModuleRemovedFlags {
            defaults.removeObject(forKey: flag)
        }
        for key in Defaults.retiredLexiconKeys {
            defaults.removeObject(forKey: key)
        }
        for key in defaults.dictionaryRepresentation().keys
            where key.hasSuffix("_") {
            dlog("Module-choice retirement: dropping orphaned pref key \(key)")
            defaults.removeObject(forKey: key)
        }
        defaults.set(true, forKey: Defaults.moduleChoiceRetired)
        defaults.synchronize()
    }

    private func retirePerModuleFonts() {
        guard !defaults.bool(forKey: Defaults.globalFontOnly) else {
            return
        }

        for module in BundledModules.all {
            defaults.psRemove(Defaults.fontNamePreference, forModule: module)
            defaults.psRemove(Defaults.fontSizePreference, forModule: module)
            defaults.psRemove(
                Defaults.fontDefaultsPreference,
                forModule: module
            )
        }
        defaults.removeObject(forKey: "moduleMaintainerModePreference")
        defaults.set(true, forKey: Defaults.globalFontOnly)
        defaults.synchronize()
    }

    private func validatePersistedReference() {
        guard !defaults.bool(forKey: Defaults.lastRefValidated) else {
            return
        }

        let reference = currentReference()
        if !referenceResolves(reference) {
            alog(
                "lastRef '\(reference)' does not resolve against the "
                    + "versification table; resetting to Genesis 1"
            )
            defaults.set("Genesis 1", forKey: Defaults.lastRef)
            defaults.set("1", forKey: Defaults.bibleVersePosition)
            defaults.set("1", forKey: Defaults.commentaryVersePosition)
        }
        defaults.set(true, forKey: Defaults.lastRefValidated)
        defaults.synchronize()
    }

    private func clearDictionaryKeyCaches() {
        guard !defaults.bool(forKey: Defaults.dictKeyCaseFixed) else {
            return
        }

        var deleted: [String] = []
        for module in [
            BundledModules.morphGreek,
            BundledModules.strongsGreek,
            BundledModules.strongsHebrew,
        ] {
            let filename = "cache-\(module)-\(moduleVersion(module))"
            let path = (paths.appSupportRoot as NSString)
                .appendingPathComponent(filename)
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
                deleted.append(filename)
            }
        }

        if let entries = try? fileManager.contentsOfDirectory(
            atPath: paths.appSupportRoot
        ) {
            for entry in entries where entry.hasPrefix("cache-") {
                let path = (paths.appSupportRoot as NSString)
                    .appendingPathComponent(entry)
                try? fileManager.removeItem(atPath: path)
                deleted.append(entry)
            }
        }
        if !deleted.isEmpty {
            dlog("Dictionary-key casing fix: cleared key caches \(deleted)")
        }
        defaults.set(true, forKey: Defaults.dictKeyCaseFixed)
        defaults.synchronize()
    }

    private func removeRetiredSwordFiles() {
        guard !defaults.bool(forKey: Defaults.swordRetired) else {
            return
        }

        for directory in ["mods.d", "modules", "locales.d", "unused"] {
            let path = (paths.moduleRoot as NSString)
                .appendingPathComponent(directory)
            guard fileManager.fileExists(atPath: path) else {
                continue
            }
            do {
                try fileManager.removeItem(atPath: path)
                dlog("SWORD retirement: removed Documents/\(directory)")
            } catch {
                alog(
                    "SWORD retirement: could not remove Documents/"
                        + "\(directory): \(error)"
                )
            }
        }
        try? fileManager.removeItem(atPath: paths.installerRoot)
        defaults.set(true, forKey: Defaults.swordRetired)
        defaults.synchronize()
    }
}
