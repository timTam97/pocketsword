import SwiftUI
import UIKit

enum StudyFonts {
    static let all = [
        "American Typewriter",
        "Arial",
        "Courier",
        "Helvetica Neue",
        "HelveticaNeue-Light",
        "Times New Roman",
        "Code2000",
        "Gentium Plus",
        "Ezra SIL",
        "AppleGothic",
        "Arial Hebrew",
        "Arial Rounded MT Bold",
        "Arial Unicode MS",
        "Bangla Sangam MN",
        "Bodoni 72",
        "Cochin",
        "Courier New",
        "Damascus",
        "Devanagari Sangam MN",
        "Geeza Pro",
        "Georgia",
        "Gill Sans",
        "Gurmukhi MN",
        "Gujarati Sangam MN",
        "Heiti J",
        "Heiti K",
        "Heiti SC",
        "Heiti TC",
        "Helvetica",
        "Hiragino Kaku Gothic ProN",
        "Hoefler Text",
        "Kailasa",
        "Kannada Sangam MN",
        "Malayalam Sangam MN",
        "Marion",
        "Menlo",
        "Optima",
        "Oriya Sangam MN",
        "Sinhala Sangam MN",
        "Tamil Sangam MN",
        "Telugu Sangam MN",
        "Thonburi",
        "Trebuchet MS",
        "Verdana",
    ]
}

struct SettingsView: View {
    let settings: SettingsModel
    let maximumFontSize: Double

    @State private var showingFontPicker = false

    var body: some View {
        GeometryReader { geometry in
            List {
                ReadingSettingsSection(
                    settings: settings,
                    maximumFontSize: maximumFontSize,
                    showFontPicker: { showingFontPicker = true }
                )
                DeviceSettingsSection(
                    settings: settings,
                    currentOrientation: geometry.size.width > geometry.size.height
                        ? .landscape
                        : .portrait
                )
            }
            .listStyle(.insetGrouped)
        }
        .sheet(isPresented: $showingFontPicker) {
            NavigationStack {
                FontPickerView(settings: settings)
            }
        }
    }
}

private struct ReadingSettingsSection: View {
    let settings: SettingsModel
    let maximumFontSize: Double
    let showFontPicker: () -> Void

    var body: some View {
        Section("PreferencesDisplayPreferencesTitle") {
            ReadingPreviewRow(settings: settings)
            FontSizeControl(
                settings: settings,
                maximumFontSize: maximumFontSize
            )
            FontSelectionButton(
                fontName: settings.fontName,
                action: showFontPicker
            )
        }
    }
}

private struct ReadingPreviewRow: View {
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SettingsReadingPreview")
                .font(
                    .custom(
                        settings.fontName,
                        size: CGFloat(settings.fontSize),
                        relativeTo: .body
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            Text("SettingsReadingPreviewReference")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

private struct FontSizeControl: View {
    let settings: SettingsModel
    let maximumFontSize: Double

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SettingsIconLabel(
                    title: "PreferencesFontSizeTitle",
                    systemImage: "textformat.size",
                    tint: .blue
                )
                Spacer()
                Text(settings.fontSize, format: .number)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 12) {
                Text("A")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Slider(
                    value: $settings.fontSizeValue,
                    in: 10...maximumFontSize,
                    step: 1
                )
                .accessibilityIdentifier("settings.font-size")
                .accessibilityLabel(Text("PreferencesFontSizeTitle"))
                .accessibilityValue(Text(settings.fontSize, format: .number))
                Text("A")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct FontSelectionButton: View {
    let fontName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconLabel(
                    title: "PreferencesFontTitle",
                    systemImage: "character.cursor.ibeam",
                    tint: .purple
                )
                Spacer()
                Text(fontName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.font")
    }
}

private struct DeviceSettingsSection: View {
    let settings: SettingsModel
    let currentOrientation: RotationLock

    var body: some View {
        @Bindable var settings = settings

        Section {
            Toggle(
                isOn: $settings.keepScreenAwake,
                label: {
                    SettingsIconLabel(
                        title: "PreferencesDisableAutoLockTitle",
                        systemImage: "sun.max.fill",
                        tint: .orange
                    )
                }
            )
            .accessibilityIdentifier("settings.keep-awake")
            Toggle(
                isOn: $settings[
                    rotationLockedFor: currentOrientation
                ],
                label: {
                    SettingsIconLabel(
                        title: "PreferencesRotationLock",
                        systemImage: "lock.rotation",
                        tint: .teal
                    )
                }
            )
            .accessibilityIdentifier("settings.rotation-lock")
            Toggle(
                isOn: $settings.automaticFullscreen,
                label: {
                    SettingsIconLabel(
                        title: "PreferencesFullscreenModeTitle",
                        systemImage: "arrow.up.left.and.arrow.down.right",
                        tint: .indigo
                    )
                }
            )
            .accessibilityIdentifier("settings.automatic-fullscreen")
        } header: {
            Text("PreferencesDevicePreferencesTitle")
        } footer: {
            Text("PreferencesFullscreenNote")
        }
    }
}

private struct SettingsIconLabel: View {
    let title: LocalizedStringResource
    let systemImage: String
    let tint: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(tint)
                .frame(width: 24)
        }
    }
}

struct FontPickerView: View {
    let settings: SettingsModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(StudyFonts.all, id: \.self) { fontName in
            FontPickerRow(
                fontName: fontName,
                isSelected: fontName == settings.fontName,
                select: {
                    settings.fontName = fontName
                    dismiss()
                }
            )
        }
        .navigationTitle("FontPreferenceTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(Text("CloseButtonTitle"))
                .help("CloseButtonTitle")
            }
        }
    }
}

private struct FontPickerRow: View {
    let fontName: String
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack {
                Text(fontName)
                    .font(.custom(fontName, size: 17, relativeTo: .body))
                    .foregroundStyle(.primary)
                Spacer()
                ZStack {
                    Color.clear
                    if isSelected {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                    }
                }
                .frame(width: 20, height: 20)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(fontName))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct AboutInformation: Equatable {
    let version: String
    let build: String
    let feedbackURL: URL

    static func current() -> AboutInformation {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? ""
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? ""
        let device = UIDevice.current
        let subject = "PocketSword Feedback (v\(version) - "
            + "\(device.systemName) \(device.systemVersion) "
            + "(\(device.model)))"
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "pocketsword@icloud.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
        ]
        let feedbackURL = components.url
            ?? URL(string: "mailto:pocketsword@icloud.com")!
        return AboutInformation(
            version: version,
            build: build,
            feedbackURL: feedbackURL
        )
    }
}

struct AboutView: View {
    let information: AboutInformation

    var body: some View {
        List {
            AboutHeader(
                version: information.version,
                build: information.build
            )
            AboutCommunitySection()
            AboutCompanionAppsSection()
            AboutCreditsSection()
            AboutOpenSourceSection()
            AboutFeedbackSection(feedbackURL: information.feedbackURL)
        }
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            Color.clear
                .frame(height: 56)
                .accessibilityHidden(true)
        }
    }
}

private struct AboutHeader: View {
    let version: String
    let build: String

    var body: some View {
        VStack(spacing: 10) {
            AboutAppIcon()
            Text(verbatim: "PocketSword")
                .font(.title2.weight(.semibold))
            Text("Version \(version) (\(build))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .listRowBackground(Color.clear)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("about.header")
    }
}

private struct AboutAppIcon: View {
    private static let image = UIImage(named: "Icon.png")
        ?? UIImage(named: "Icon")

    var body: some View {
        ZStack {
            if let image = Self.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "book.closed.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(14)
                    .foregroundStyle(.white)
                    .background(Color.accentColor)
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct AboutCommunitySection: View {
    var body: some View {
        Section("AboutCommunityTitle") {
            AboutLinkRow(
                title: "AboutProjectLink",
                systemImage: "safari",
                destination: URL(
                    string: "https://bitbucket.org/niccarter/pocketsword/overview"
                )!
            )
            AboutLinkRow(
                title: "AboutCrossWireLink",
                systemImage: "globe",
                destination: URL(string: "https://www.crosswire.org/")!
            )
            AboutLinkRow(
                title: "AboutUserForumsLink",
                systemImage: "bubble.left.and.bubble.right",
                destination: URL(
                    string: "https://www.crosswire.org/forums/"
                )!
            )
        }
    }
}

private struct AboutCompanionAppsSection: View {
    var body: some View {
        Section("AboutCompanionAppsTitle") {
            AboutLinkRow(
                title: "Xiphos",
                systemImage: "desktopcomputer",
                destination: URL(string: "https://xiphos.org/")!
            )
            AboutLinkRow(
                title: "AndBible",
                systemImage: "smartphone",
                destination: URL(string: "https://andbible.github.io/")!
            )
            AboutLinkRow(
                title: "BibleTime",
                systemImage: "desktopcomputer",
                destination: URL(string: "https://bibletime.info/")!
            )
            AboutLinkRow(
                title: "Eloquent",
                systemImage: "desktopcomputer",
                destination: URL(string: "https://www.macsword.com/")!
            )
        }
    }
}

private struct AboutCreditsSection: View {
    var body: some View {
        Section("AboutCreditsTitle") {
            Text("AboutDevelopedByText")
            Text("AboutContributorsText")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AboutOpenSourceSection: View {
    var body: some View {
        Section("AboutOpenSourceTitle") {
            AboutLinkRow(
                title: "The SWORD Project",
                systemImage: "book.closed",
                destination: URL(
                    string: "https://www.crosswire.org/sword/"
                )!
            )
            AboutLinkRow(
                title: "MBProgressHUD",
                systemImage: "shippingbox",
                destination: URL(
                    string: "https://github.com/jdg/MBProgressHUD"
                )!
            )
            Text("AboutFontLicenseText")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct AboutFeedbackSection: View {
    let feedbackURL: URL

    var body: some View {
        Section("AboutFeedbackTitle") {
            AboutLinkRow(
                title: "EmailUsButton",
                systemImage: "envelope",
                destination: feedbackURL
            )
        }
    }
}

private struct AboutLinkRow: View {
    let title: LocalizedStringResource
    let systemImage: String
    let destination: URL

    var body: some View {
        Link(destination: destination) {
            Label {
                Text(title)
            } icon: {
                Image(systemName: systemImage)
                    .frame(width: 24)
            }
        }
    }
}
