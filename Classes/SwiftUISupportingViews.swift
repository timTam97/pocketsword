import SwiftUI
import UIKit
import Observation

struct LaunchView: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()
            ProgressView()
                .controlSize(.large)
                .accessibilityLabel(Text("LaunchProgressLabel"))
                .accessibilityIdentifier("launch.progress")
        }
    }
}

struct ReferencePickerBook: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let shortName: String
    let verseCounts: [Int]

    init(
        id: String,
        name: String,
        shortName: String,
        verseCounts: [Int]
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName
        self.verseCounts = verseCounts
    }

    init(_ book: PSVersificationBook) {
        self.init(
            id: book.osisName,
            name: book.name,
            shortName: book.shortName,
            verseCounts: book.verseMax
        )
    }

    var chapterCount: Int {
        verseCounts.count
    }

    func verseCount(chapter: Int) -> Int {
        guard verseCounts.indices.contains(chapter - 1) else { return 0 }
        return verseCounts[chapter - 1]
    }
}

struct ReferencePickerSelection: Equatable {
    let bookName: String
    let chapter: Int
    let verse: Int
}

struct ReferencePickerIndexEntry: Identifiable, Equatable {
    var id: String { shortName }

    let shortName: String
    let bookID: String
}

enum ReferencePickerDestination: Hashable {
    case chapters(bookID: String)
    case verses(bookID: String, chapter: Int)
}

@MainActor
@Observable
final class ReferencePickerModel {
    var books: [ReferencePickerBook]
    var indexEntries: [ReferencePickerIndexEntry]
    var currentBookID: String?
    var currentChapter: Int?
    var path: [ReferencePickerDestination] = []
    var showsCancel: Bool

    @ObservationIgnored var onSelection: ((ReferencePickerSelection) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?

    init(
        books: [ReferencePickerBook] = [],
        currentReference: String? = nil,
        showsCancel: Bool = false
    ) {
        self.books = books
        self.indexEntries = Self.makeIndexEntries(books: books)
        self.showsCancel = showsCancel
        updateCurrentReference(currentReference)
    }

    func reload(
        books: [ReferencePickerBook],
        currentReference: String?
    ) {
        self.books = books
        indexEntries = Self.makeIndexEntries(books: books)
        path = []
        updateCurrentReference(currentReference)
    }

    func clearBooks() {
        books = []
        indexEntries = []
        currentBookID = nil
        currentChapter = nil
        path = []
    }

    func updateCurrentReference(_ reference: String?) {
        guard let chapterReference = reference?
            .components(separatedBy: ":")
            .first,
              let separator = chapterReference.range(
                of: " ",
                options: .backwards
              ),
              let chapter = Int(chapterReference[separator.upperBound...]) else {
            currentBookID = nil
            currentChapter = nil
            return
        }

        let bookName = String(chapterReference[..<separator.lowerBound])
        currentBookID = books.first { $0.name == bookName }?.id
        currentChapter = currentBookID == nil ? nil : chapter
    }

    func book(id: String) -> ReferencePickerBook? {
        books.first { $0.id == id }
    }

    func openChapters(for bookID: String) {
        guard book(id: bookID) != nil else { return }
        path.append(.chapters(bookID: bookID))
    }

    func openVerses(for bookID: String, chapter: Int) {
        // `(1...n).contains(x)` is a TRAP when `n` is 0: the `...` operator
        // precondition-fails ("Can't form Range with upperBound < lowerBound")
        // while FORMING the range, before `contains` is ever called — and both
        // `chapterCount` and `verseCount(chapter:)` return 0 for a book/chapter
        // the versification does not have. The bounds are therefore compared
        // directly here and in `select`, which is identical for every non-empty
        // book.
        guard let book = book(id: bookID),
              chapter >= 1,
              chapter <= book.chapterCount else {
            return
        }
        path.append(.verses(bookID: bookID, chapter: chapter))
    }

    func select(bookID: String, chapter: Int, verse: Int) {
        guard let book = book(id: bookID),
              chapter >= 1,
              chapter <= book.chapterCount,
              verse >= 1,
              verse <= book.verseCount(chapter: chapter) else {
            return
        }
        onSelection?(
            ReferencePickerSelection(
                bookName: book.name,
                chapter: chapter,
                verse: verse
            )
        )
    }

    func cancel() {
        onCancel?()
    }

    private static func makeIndexEntries(
        books: [ReferencePickerBook]
    ) -> [ReferencePickerIndexEntry] {
        var seen: Set<String> = []
        return books.compactMap { book in
            guard seen.insert(book.shortName).inserted else { return nil }
            return ReferencePickerIndexEntry(
                shortName: book.shortName,
                bookID: book.id
            )
        }
    }
}

struct ReferencePickerView: View {
    let model: ReferencePickerModel

    var body: some View {
        @Bindable var model = model

        NavigationStack(path: $model.path) {
            ReferenceBookList(model: model)
                .navigationDestination(
                    for: ReferencePickerDestination.self
                ) { destination in
                    switch destination {
                    case .chapters(let bookID):
                        if let book = model.book(id: bookID) {
                            ReferenceChapterList(model: model, book: book)
                        }
                    case .verses(let bookID, let chapter):
                        if let book = model.book(id: bookID) {
                            ReferenceVerseList(
                                model: model,
                                book: book,
                                chapter: chapter
                            )
                        }
                    }
                }
        }
    }
}

private struct ReferenceBookList: View {
    let model: ReferencePickerModel

    var body: some View {
        ScrollViewReader { proxy in
            List(model.books) { book in
                ReferenceBookRow(
                    id: book.id,
                    name: book.name,
                    isCurrent: model.currentBookID == book.id,
                    open: { model.openChapters(for: book.id) },
                    jumpToStart: {
                        model.select(bookID: book.id, chapter: 1, verse: 1)
                    }
                )
                .id(book.id)
            }
            .task(id: model.currentBookID) {
                await Task.yield()
                if let currentBookID = model.currentBookID {
                    proxy.scrollTo(currentBookID, anchor: .center)
                }
            }
            .contentMargins(.trailing, 32, for: .scrollContent)
            .overlay(alignment: .trailing) {
                ReferenceBookIndex(entries: model.indexEntries) { bookID in
                    proxy.scrollTo(bookID, anchor: .center)
                }
            }
        }
        .navigationTitle("RefSelectorBookTitle")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if model.showsCancel {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        model.cancel()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel(Text("Cancel"))
                    .help("Cancel")
                }
            }
        }
    }
}

private struct ReferenceBookIndex: View {
    let entries: [ReferencePickerIndexEntry]
    let scrollTo: (String) -> Void

    @State private var lastBookID: String?

    var body: some View {
        GeometryReader { geometry in
            let rowHeight = max(
                geometry.size.height / CGFloat(max(entries.count, 1)),
                0.1
            )

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    Text(entry.shortName)
                        .font(.caption2)
                        .minimumScaleFactor(0.45)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: rowHeight)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let index = min(
                            max(Int(value.location.y / rowHeight), 0),
                            entries.count - 1
                        )
                        guard entries.indices.contains(index) else { return }
                        let bookID = entries[index].bookID
                        guard bookID != lastBookID else { return }
                        lastBookID = bookID
                        scrollTo(bookID)
                    }
                    .onEnded { _ in
                        lastBookID = nil
                    }
            )
        }
        .frame(width: 32)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }
}

private struct ReferenceBookRow: View {
    let id: String
    let name: String
    let isCurrent: Bool
    let open: () -> Void
    let jumpToStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Text(name)
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    Spacer()
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reference.book.\(id)")

            Button(action: jumpToStart) {
                Text(verbatim: "1:1")
                    .monospacedDigit()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("\(name) 1:1"))
            .accessibilityIdentifier("reference.book-start.\(id)")
        }
    }
}

private struct ReferenceChapterList: View {
    let model: ReferencePickerModel
    let book: ReferencePickerBook

    var body: some View {
        List {
            // Half-open deliberately: `1...count` traps at runtime when `count`
            // is 0, and a book with no chapters must degrade to an empty list
            // rather than crash the picker.
            ForEach(1..<(book.chapterCount + 1), id: \.self) { chapter in
                ReferenceChapterRow(
                    bookID: book.id,
                    chapter: chapter,
                    title: ReferencePickerText.chapter(chapter),
                    isCurrent: model.currentBookID == book.id
                        && model.currentChapter == chapter,
                    open: {
                        model.openVerses(
                            for: book.id,
                            chapter: chapter
                        )
                    },
                    jumpToStart: {
                        model.select(
                            bookID: book.id,
                            chapter: chapter,
                            verse: 1
                        )
                    }
                )
            }
        }
        .navigationTitle(book.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReferenceChapterRow: View {
    let bookID: String
    let chapter: Int
    let title: String
    let isCurrent: Bool
    let open: () -> Void
    let jumpToStart: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 10) {
                    Text(title)
                        .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                    Spacer()
                    if isCurrent {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                    }
                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reference.chapter.\(chapter)")

            Button(action: jumpToStart) {
                Text(verbatim: "\(chapter):1")
                    .monospacedDigit()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(Text("\(title), verse 1"))
            .accessibilityIdentifier(
                "reference.chapter-start.\(bookID).\(chapter)"
            )
        }
    }
}

private struct ReferenceVerseList: View {
    let model: ReferencePickerModel
    let book: ReferencePickerBook
    let chapter: Int

    var body: some View {
        List {
            // Half-open for the same reason as `ReferenceChapterList`:
            // `verseCount(chapter:)` returns 0 for a chapter this book does not
            // have, and `1...0` traps. An empty list is the right degradation for
            // a destination that did not come through `openVerses`.
            ForEach(
                1..<(book.verseCount(chapter: chapter) + 1),
                id: \.self
            ) { verse in
                Button {
                    model.select(
                        bookID: book.id,
                        chapter: chapter,
                        verse: verse
                    )
                } label: {
                    Text(ReferencePickerText.verse(verse))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("reference.verse.\(verse)")
            }
        }
        .navigationTitle("\(book.name) \(chapter)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private enum ReferencePickerText {
    static func chapter(_ chapter: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "RefSelectorChapterTitle"),
            chapter
        )
    }

    static func verse(_ verse: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "RefSelectorVerseTitle"),
            verse
        )
    }
}

struct VoiceReferenceView: View {
    let model: VoiceReferenceModel

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            VoiceReferenceHeader(
                isListening: model.isListening,
                status: model.status.text
            )
            VoiceReferenceTranscriptView(
                transcript: model.transcript,
                preview: model.preview
            )
            VoiceReferenceProgress(progress: model.downloadProgress)
            Spacer(minLength: 0)
            VoiceReferenceActionBar(
                action: model.action,
                isActionEnabled: model.isActionEnabled,
                showsCancel: model.showsCancel,
                cancel: model.cancel,
                performAction: {
                    if model.action == .openSettings,
                       let url = URL(
                        string: UIApplication.openSettingsURLString
                       ) {
                        openURL(url)
                    } else {
                        model.performPrimaryAction()
                    }
                }
            )
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .task {
            model.start()
        }
        .onDisappear {
            model.cancelSession()
        }
        .accessibilityIdentifier("voice-reference")
    }
}

private struct VoiceReferenceHeader: View {
    let isListening: Bool
    let status: LocalizedStringResource?

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "microphone")
                .font(.system(.largeTitle, weight: .medium))
                .foregroundStyle(.tint)
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeat(.continuous),
                    isActive: isListening
                )
                .accessibilityHidden(true)
            if let status {
                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

private struct VoiceReferenceTranscriptView: View {
    let transcript: VoiceReferenceTranscript
    let preview: String

    var body: some View {
        VStack(spacing: 6) {
            VStack {
                switch transcript {
                case .empty:
                    Color.clear
                case .prompt:
                    Text("VoiceRefPrompt")
                case .value(let value):
                    Text(value)
                }
            }
            .font(.headline)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 42)

            Text(preview)
                .font(.subheadline)
                .foregroundStyle(.green)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 20)
        }
    }
}

private struct VoiceReferenceProgress: View {
    let progress: Progress?

    var body: some View {
        ZStack {
            if let progress {
                ProgressView(progress)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 8)
    }
}

private struct VoiceReferenceActionBar: View {
    let action: VoiceReferenceAction
    let isActionEnabled: Bool
    let showsCancel: Bool
    let cancel: () -> Void
    let performAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if showsCancel {
                Button("Cancel", action: cancel)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("voice-reference.cancel")
            }
            if let title = action.title {
                Button(title, action: performAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(!isActionEnabled)
                    .accessibilityIdentifier("voice-reference.action")
            }
        }
        .controlSize(.large)
        .frame(maxWidth: .infinity, minHeight: 44)
    }
}

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
            // No MBProgressHUD row: Wave 8 deleted the vendored library along with
            // its only consumer, and `externals/` is now empty. The app ships no
            // third-party code at all, so crediting one is a factual error on a
            // screen whose whole job is attribution. The SWORD Project stays —
            // its *content* is still what the app reads, baked into
            // PSContent.sqlite even though none of its code remains.
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
