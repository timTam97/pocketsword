//
//  SwiftUIStudyViews.swift
//  PocketSword
//
//  Wave 8: the study surfaces the reader raises — the Strong's / morph / footnote /
//  lexicon popup, the bookmark editor, and the voice-reference sheet.
//
//  These replace three UIKit view controllers:
//
//  - `PSInfoPopupViewController` — 467 lines of `UIVisualEffectView` +
//    `UIStackView` + `NSLayoutConstraint` building a frosted sheet with a lemma
//    header, a `WKWebView` and a "Find all occurrences" button. `StudyPopupSheet`
//    below is the same layout declaratively. **`PSInfoPopupContent` is kept
//    unchanged** — its Greek/Hebrew lemma and transliteration parsing is 130 lines
//    of hard-won string handling over the rendered lexicon entries (nested
//    beta-code brackets, the ~114 Hebrew entries with a spurious `<sup>` vowel,
//    numeric-entity decoding), and it is the *content*, not the presentation.
//  - `PSBookmarksAddTableViewController` — a 5-section `UITableViewController`
//    whose folder row pushed a chain of `PSBookmarksNavigatorController`s to let
//    the user walk to a destination folder. `BookmarkEditorView` replaces it with
//    a `Form` over the typed `BookmarkStore`, and the folder walk with a flattened
//    picker: the old chain rebuilt one controller per path component and reset
//    `folder` to nil on re-entry, which is why picking a nested folder twice
//    landed at the root.
//  - `PSVoiceRefViewController` — a `UIHostingController` wrapper that existed
//    only to configure a `pageSheet` detent and wire two closures. Presenting
//    `VoiceReferenceView` from a `.sheet` needs neither.
//

import SwiftUI
import UIKit

// MARK: - Study popup

/// The Strong's / morph / footnote / lexicon sheet.
///
/// The visual design is `PSInfoPopupViewController`'s, preserved deliberately
/// because it is what makes a lexicon entry readable: an accent rail, the lemma as
/// the hero in its own script font, the reference demoted to a subtitle, and the
/// definition below in a transparent WebView over frosted material.
struct StudyPopupSheet: View {
    let content: PSInfoPopupContent
    let findAllOccurrences: (String) -> Void

    /// Cross-links followed from the entry the reader opened, innermost last.
    ///
    /// A lexicon entry's whole value is that "From 3898" is navigable, and 14,989 of
    /// those links are baked into the shipped content. They resolve **in place**
    /// rather than by stacking sheets: a `.medium` detent sheet cannot present
    /// another sheet over itself without the tab-bar layout assertion Wave 8
    /// documented, and a `NavigationStack` inside a half-height sheet spends a fifth
    /// of the visible area on a bar. So the sheet swaps its content and offers a Back
    /// button while the trail is non-empty.
    @State private var trail: [PSInfoPopupContent] = []

    /// What is actually on screen: the deepest cross-link followed, or the entry the
    /// reader opened.
    private var current: PSInfoPopupContent {
        trail.last ?? content
    }

    var body: some View {
        VStack(spacing: 0) {
            if !trail.isEmpty {
                backBar
            }
            if current.isStrongsEntry {
                StudyPopupHeader(content: current)
            }
            EntryTextView(
                // Parsed ONCE, on the content object that owns the HTML. Building it
                // here re-ran the whole scanner on every body evaluation — dragging
                // the detent or tapping Back re-parsed the entry.
                document: current.entryDocument,
                openLink: follow,
                // A non-Strong's entry gets top padding because it has no header
                // to sit under; the old code set the same 20pt as a scroll-view
                // content inset.
                topInset: current.isStrongsEntry ? 0 : 20,
                // `createStrongsInfoHTMLString` overrode the definition's
                // font-family to `-apple-system`; a footnote or a morph entry came
                // through `createInfoHTMLString`, which kept the user's chosen
                // font. Same split, so neither surface changes for the wrong reason.
                usesSystemFace: current.isStrongsEntry
            )
            // `current` changes identity when a cross-link is followed, which resets
            // the entry's scroll offset. Without this the new definition opens
            // scrolled to wherever the previous one sat.
            .id(current.reference ?? "root-\(trail.count)")
            if let searchTerm = current.searchTerm {
                Divider()
                Button {
                    findAllOccurrences(searchTerm)
                } label: {
                    Label("StrongsSearchFindAll", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(StudyPalette.accent)
                .accessibilityIdentifier("study.find-all")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
        .accessibilityIdentifier("study.popup")
    }

    private var backBar: some View {
        HStack {
            Button {
                _ = trail.popLast()
            } label: {
                Label("RefSelectorBackButtonTitle", systemImage: "chevron.left")
                    .font(.subheadline.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(StudyPalette.accent)
            .accessibilityIdentifier("study.back")
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    /// Follow a cross-link, or do nothing if its target is not in the store.
    ///
    /// "Find all occurrences" stays available on a followed entry only if it was
    /// available on the one the reader opened — that flag is Bible-only (the
    /// commentary has no Strong's index to search) and is a property of where the
    /// popup was raised from, not of the entry now showing.
    private func follow(_ link: EntryLink) {
        guard case .lexicon(let module, let key) = link,
              let next = PSInfoPopupContent.lexiconEntry(
                  module: module,
                  key: key,
                  allowsSearch: content.searchTerm != nil
              ) else {
            return
        }
        trail.append(next)
    }
}

/// The lemma header. When the lexeme parses, the WORD is the hero and the
/// reference folds into the subtitle; when it does not, the reference becomes the
/// hero. Both arms are `PSInfoPopupViewController.configureHeader(with:)`'s.
private struct StudyPopupHeader: View {
    let content: PSInfoPopupContent

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Capsule()
                .fill(StudyPalette.accent)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(hero)
                    .font(heroFont)
                    .foregroundStyle(.primary)
                if let transliteration = content.transliteration {
                    Text(transliteration)
                        .font(.subheadline.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.init(top: 24, leading: 20, bottom: 16, trailing: 20))
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String? {
        guard content.lemma != nil, let reference = content.reference else {
            return content.contextTitle
        }
        return [content.contextTitle, reference]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    private var hero: String {
        content.lemma ?? content.reference ?? ""
    }

    /// The bundled script font at 40pt for a parsed lemma, scaled for Dynamic
    /// Type; a plain semibold 28pt for the reference fallback. `Font.custom(…,
    /// relativeTo:)` is the SwiftUI equivalent of the old
    /// `UIFontMetrics(forTextStyle:).scaledFont(for:)`, and falls back to the
    /// system font if the custom family is not registered.
    private var heroFont: Font {
        guard content.lemma != nil else {
            return .system(size: 28, weight: .semibold)
        }
        let name = content.isHebrew
            ? AppConstants.hebrewStrongsFontName
            : AppConstants.greekStrongsFontName
        return .custom(name, size: 40, relativeTo: .largeTitle)
    }
}

// `StudyPopupWebView` is DELETED (Wave 9). It was a transparent `WKWebView` over
// the sheet's material, and it needed `createInfoHTMLString` to inject
// `html, body { background-color: transparent; }` for exactly that reason — plus
// `createStrongsInfoHTMLString`'s 60 further lines of CSS to make it resemble the
// sheet it sat in. `EntryTextView` is a `Text` in that sheet, so it inherits the
// material and the type styles for free, and the definition becomes selectable
// text with real accessibility elements.

/// The study accent, matching `PSInfoPopupViewController.studyAccent` and the
/// `--study-accent` custom property `createStrongsInfoHTMLString` injects, so the
/// header rail and the entry's own links are the same colour.
enum StudyPalette {
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.40, green: 0.77, blue: 0.79, alpha: 1)
                : UIColor(red: 0.04, green: 0.40, blue: 0.44, alpha: 1)
        }
    )
}

// MARK: - Bookmark editor

/// Add a bookmark for a verse.
///
/// `PSBookmarksAddTableViewController` had five sections in edit mode and three in
/// add mode; only **add** is reachable from the reader, and editing an existing
/// bookmark is the Library's rename/colour flow. So this is the add form: the
/// reference (fixed), a description, and a destination folder.
///
/// The folder picker is flat, listing every folder by its full path. The old
/// version pushed one `PSBookmarksNavigatorController` per path component to walk
/// the tree, and then set `self.folder = nil` at the end of that walk — so
/// re-opening the row after choosing a nested folder dropped you back at the root
/// with the selection cleared. A flat list of ~a dozen folders needs no walk.
struct BookmarkEditorView: View {
    let draft: BookmarkDraft

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var folderPath: String?
    @State private var error: BookmarkMutationError?

    var body: some View {
        Form {
            Section("BookmarksAddBookmarkVerseTitle") {
                Text(draft.reference)
                    .accessibilityIdentifier("bookmark.reference")
            }
            Section("BookmarksAddBookmarkDescriptionTitle") {
                TextField(draft.reference, text: $name)
                    .accessibilityIdentifier("bookmark.description")
            }
            Section("BookmarksAddBookmarkFolderTitle") {
                Picker("BookmarksAddBookmarkFolderTitle", selection: $folderPath) {
                    Text("BookmarksTitle").tag(String?.none)
                    ForEach(BookmarkFolderPath.all(), id: \.path) { folder in
                        Text(folder.displayPath).tag(String?.some(folder.path))
                    }
                }
                .accessibilityIdentifier("bookmark.folder")
            }
        }
        .navigationTitle("VerseContextualMenuAddBookmark")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel(Text("Cancel"))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    save()
                } label: {
                    Image(systemName: "checkmark")
                }
                .accessibilityLabel(Text("Save"))
                .accessibilityIdentifier("bookmark.save")
            }
        }
        .alert(
            error?.title ?? "LibraryUpdateFailedTitle",
            item: $error
        ) { _ in
            Button("Ok", role: .cancel) {}
        } message: { error in
            Text(error.message)
        }
    }

    /// Persists the bookmark and announces the change.
    ///
    /// One behaviour comes from `saveButtonPressed`: an empty description falls back
    /// to the reference itself. `PSBookmarks.addBookmark` posts nothing itself, so
    /// the post has to happen here.
    ///
    /// **The post is deliberately UNCONDITIONAL, where the UIKit original gated it
    /// on `createRefString(getCurrentBibleRef()) == bookAndChapterRef`.** That gate
    /// was safe only because `bookmarksChanged` had exactly ONE consumer — the
    /// reader's highlight re-render — and the bookmarks *list* was a
    /// `UITableViewController` that reloaded from `-viewWillAppear:`. It now has a
    /// second consumer with no reload of its own: `LibraryModel` refreshes `bookmarks`
    /// only off this notification, and the Bookmarks section has no `.task`/`onAppear`
    /// reload, so a gated post could leave the Library listing a stale tree until some
    /// unrelated mutation happened to call `BookmarkStore.commit()`.
    ///
    /// In fairness the gate was almost always true — `presentVerseMenu` snapshots
    /// `draft.chapterRef` from the very expression `save()` re-evaluated, so they
    /// diverge only if `lastRef` changes while the sheet is up (an inbound `sword://`
    /// URL, or an absent `lastRef`). So this is closing a contract hole rather than a
    /// defect users were hitting. It is worth closing anyway: two consumers now share
    /// one notification and the condition was written for only one of them. The
    /// reader's handler re-renders its pane at the persisted scroll offset, which in the
    /// ordinary same-chapter case is what already happened.
    private func save() {
        let description = name.isEmpty ? draft.reference : name
        _ = PSBookmarks.addBookmark(
            withRef: draft.reference,
            name: description,
            folderString: folderPath
        )
        NotificationCenter.default.post(name: .bookmarksChanged, object: nil)
        dismiss()
    }
}

/// A folder in the bookmark tree, by its persisted path.
///
/// The path separator is `AppConstants.folderSeparatorString` (`":::"`), which is
/// the persisted format `PSBookmarks.getBookmarkFolder(forFolderString:)` parses —
/// so the value handed to `addBookmark` is exactly what the old navigator chain
/// built up. `displayPath` swaps it for `/` for reading, which is what the old
/// table cell did too.
struct BookmarkFolderPath: Equatable {
    let path: String

    var displayPath: String {
        path.replacingOccurrences(
            of: AppConstants.folderSeparatorString,
            with: " / "
        )
    }

    /// Every folder in the tree, depth-first, as separator-joined paths.
    static func all(root: PSBookmarkFolder = PSBookmarks.default()) -> [BookmarkFolderPath] {
        var result: [BookmarkFolderPath] = []
        func walk(_ folder: PSBookmarkFolder, prefix: String?) {
            for case let child as PSBookmarkFolder in folder.children ?? [] {
                guard let name = child.name else { continue }
                let path = prefix.map {
                    "\($0)\(AppConstants.folderSeparatorString)\(name)"
                } ?? name
                result.append(BookmarkFolderPath(path: path))
                walk(child, prefix: path)
            }
        }
        walk(root, prefix: nil)
        return result
    }
}

// MARK: - Voice reference

/// The voice-reference sheet.
///
/// `PSVoiceRefViewController` was a `UIHostingController` subclass whose entire
/// body configured a 320pt `pageSheet` detent and forwarded two closures. Both are
/// modifiers here. `VoiceReferenceModel` and the underlying `PSVoiceRefSession` /
/// `PSVoiceRefParser` are untouched.
struct VoiceReferenceSheet: View {
    let reading: ReadingWorkspaceModel

    @Environment(\.dismiss) private var dismiss
    @State private var model = VoiceReferenceModel()

    var body: some View {
        VoiceReferenceView(model: model)
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .onAppear {
                model.onCancel = {
                    dismiss()
                }
                model.onReferenceResolved = { reference in
                    dismiss()
                    reading.selectReference(
                        bookName: reference.displayBookName,
                        chapter: reference.chapter,
                        verse: reference.verse
                    )
                }
            }
    }
}
