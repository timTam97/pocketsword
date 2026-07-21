//
//  PSInfoPopupViewController.swift
//  PocketSword
//
//  Hosts the WKWebView that shows Strong's entries, morph tags, footnotes,
//  cross-references and dictionary lookups in a native sheet. Replaces the
//  hand-rolled slide-up overlay that PSTabBarControllerDelegate used to build
//  in showInfo:.
//
//  Swift port (Wave 2) of the former Classes/PSInfoPopupViewController.{h,mm}.
//  Zero C++ — a plain UIViewController leaf whose only consumer is the
//  PSTabBarControllerDelegate coordinator (via PocketSword-Swift.h). The @objc
//  surface reproduces the original Obj-C public API 1:1: the readonly `webView`
//  property and -loadHTML:.
//

import UIKit
import WebKit

final class PSInfoPopupContent: NSObject {
    let html: String
    let contextTitle: String?
    let reference: String?
    let searchTerm: String?
    /// The actual Greek/Hebrew lemma (e.g. "ὁ"), parsed from the rendered
    /// lexicon entry. nil when the module isn't a standard Strong's lexicon.
    let lemma: String?
    /// The transliteration (e.g. "ho"), parsed from the first `{…}` token.
    let transliteration: String?

    var isStrongsEntry: Bool {
        reference != nil
    }

    var isHebrew: Bool {
        reference?.hasPrefix("H") ?? false
    }

    init(html: String) {
        self.html = html
        self.contextTitle = nil
        self.reference = nil
        self.searchTerm = nil
        self.lemma = nil
        self.transliteration = nil
    }

    init(strongsHTML html: String, rawEntry: String?, reference rawReference: String, allowsSearch: Bool) {
        let normalizedReference = Self.normalizedStrongsReference(rawReference)
        let isHebrew = normalizedReference.hasPrefix("H")
        let lexeme = Self.parseStrongsLexeme(fromRenderedEntry: rawEntry)

        self.html = html
        self.contextTitle = NSLocalizedString(
            isHebrew ? "PreferencesHebrewStrongsLexiconTitle" : "PreferencesGreekStrongsLexiconTitle",
            comment: ""
        )
        self.reference = normalizedReference
        self.searchTerm = allowsSearch ? normalizedReference : nil
        self.lemma = lexeme.lemma
        self.transliteration = lexeme.transliteration
    }

    private static func normalizedStrongsReference(_ reference: String) -> String {
        let uppercased = reference
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard let prefix = uppercased.first, prefix == "G" || prefix == "H" else {
            return uppercased
        }

        let digits = uppercased.dropFirst()
        let withoutLeadingZeroes = digits.drop(while: { $0 == "0" })
        return String(prefix) + (withoutLeadingZeroes.isEmpty ? "0" : String(withoutLeadingZeroes))
    }

    /// Pull the leading lemma and transliteration out of a rendered Strong's
    /// entry. The bundled strongsrealgreek/strongsrealhebrew modules render as
    /// `ὁ [O(] {ho} \ho\ including the feminine ἡ …` — the lemma is the text
    /// before the first `[`, the transliteration is the first `{…}` token.
    /// Defensive: returns (nil, nil) for anything that doesn't look like a
    /// standard lexeme so callers fall back to showing the reference.
    static func parseStrongsLexeme(fromRenderedEntry rawEntry: String?) -> (lemma: String?, transliteration: String?) {
        guard let rawEntry = rawEntry else { return (nil, nil) }

        // The rendered entry looks like (HTML tags + numeric entities intact):
        //   <a name="4018">4018</a> &#960;&#949;&#961;… [PERIBO/LAION] {perib&#243;laion} \…\ neuter of…
        // Strip tags, decode entities to real Unicode, collapse whitespace,
        // then drop the leading key number the hidden anchor leaves behind.
        let decoded = decodingHTMLEntities(
            rawEntry.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        )
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)

        let body = decoded
            .replacingOccurrences(of: "^\\d+\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let openBracket = body.firstIndex(of: "[") else { return (nil, nil) }
        let candidate = String(body[body.startIndex..<openBracket])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Reject anything that isn't a short run of actual script — the real
        // lemma is a handful of non-ASCII letters, not a sentence.
        let hasNonASCIILetter = candidate.unicodeScalars.contains { $0.value > 0x7F && CharacterSet.letters.contains($0) }
        guard !candidate.isEmpty, candidate.count <= 40, hasNonASCIILetter else {
            return (nil, nil)
        }

        // Transliteration. Greek renders `θεός [QEO/S] {theós} \…\` — the
        // transliteration is the `{…}` immediately after the bracket group.
        // Hebrew renders `חשך [chôshek] \…\ … {misery} …` — the transliteration
        // is *inside* the brackets, and any `{…}` later on is a gloss in the
        // definition, not a transliteration. So: prefer a `{…}` right after the
        // closing `]`; otherwise fall back to the bracket content when it reads
        // like a transliteration (has ASCII lowercase, i.e. not Greek beta-code).
        var transliteration: String? = nil
        if let closeBracket = body[openBracket...].firstIndex(of: "]") {
            let afterBracket = body[body.index(after: closeBracket)...]
                .drop(while: { $0 == " " })
            if afterBracket.first == "{", let brace = afterBracket.firstIndex(of: "}") {
                let inner = String(afterBracket[afterBracket.index(after: afterBracket.startIndex)..<brace])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !inner.isEmpty { transliteration = inner }
            } else {
                let bracketContent = String(body[body.index(after: openBracket)..<closeBracket])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if bracketContent.contains(where: { $0.isLowercase && $0.isASCII }) {
                    transliteration = bracketContent
                }
            }
        }

        return (candidate, transliteration)
    }

    /// Decode the HTML entities the SWORD markup filter emits (named basics +
    /// decimal/hex numeric character references) into real Unicode. The lexicon
    /// renders Greek/Hebrew as `&#960;`-style entities, so we must decode before
    /// we can recognise the script.
    private static func decodingHTMLEntities(_ input: String) -> String {
        var result = input
        let named: [String: String] = [
            "&nbsp;": " ", "&amp;": "&", "&lt;": "<",
            "&gt;": ">", "&quot;": "\"", "&apos;": "'"
        ]
        for (entity, replacement) in named {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        guard result.contains("&#"),
              let regex = try? NSRegularExpression(pattern: "&#(x?)([0-9A-Fa-f]+);") else {
            return result
        }

        let ns = result as NSString
        let matches = regex.matches(in: result, range: NSRange(location: 0, length: ns.length))
        guard !matches.isEmpty else { return result }

        var output = ""
        var cursor = 0
        for match in matches {
            output += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let isHex = ns.substring(with: match.range(at: 1)) == "x"
            let digits = ns.substring(with: match.range(at: 2))
            if let code = UInt32(digits, radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                output.unicodeScalars.append(scalar)
            }
            cursor = match.range.location + match.range.length
        }
        output += ns.substring(from: cursor)
        return output
    }
}

@objc(PSInfoPopupViewController)
final class PSInfoPopupViewController: UIViewController {

    @objc private(set) var webView: WKWebView!

    var onSearch: ((String) -> Void)?

    private var headerView: UIView!
    private var subtitleLabel: UILabel!
    private var heroLabel: UILabel!
    private var transliterationLabel: UILabel!
    private var searchContainer: UIView!
    private var searchTerm: String?
    private var pendingContent: PSInfoPopupContent?

    private static let heroFontSize: CGFloat = 40

    private static let studyAccent = UIColor { traits in
        if traits.userInterfaceStyle == .dark {
            return UIColor(red: 0.40, green: 0.77, blue: 0.79, alpha: 1.0)
        }
        return UIColor(red: 0.04, green: 0.40, blue: 0.44, alpha: 1.0)
    }

    override func loadView() {
        let root = UIView(frame: PSResizing.mainScreenBounds())
        root.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        // Frosted glass: the sheet is translucent at every detent, so the
        // dimmed chapter blurs through. A clear root lets the material below
        // show; the sheet clips it to its rounded corners.
        root.backgroundColor = UIColor.clear

        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        blurView.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(blurView)

        let contentStack = UIStackView()
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        root.addSubview(contentStack)

        let header = makeHeaderView()
        header.isHidden = true
        contentStack.addArrangedSubview(header)
        self.headerView = header

        let cfg = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.translatesAutoresizingMaskIntoConstraints = false
        // Transparent web view over the blur — the HTML body is transparent too
        // (see PSModuleController.createInfoHTMLString), so text composites
        // directly onto the frosted material.
        wv.backgroundColor = UIColor.clear
        wv.isOpaque = false
        wv.scrollView.backgroundColor = UIColor.clear
        contentStack.addArrangedSubview(wv)

        let searchContainer = makeSearchContainer()
        searchContainer.isHidden = true
        contentStack.addArrangedSubview(searchContainer)
        self.searchContainer = searchContainer

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: root.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: root.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: root.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            contentStack.bottomAnchor.constraint(equalTo: root.safeAreaLayoutGuide.bottomAnchor)
        ])

        self.webView = wv
        self.view = root
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let pendingContent = pendingContent {
            apply(pendingContent)
            self.pendingContent = nil
        }
    }

    @objc(loadHTML:)
    func loadHTML(_ html: String?) {
        guard let html = html else { return }
        loadContent(PSInfoPopupContent(html: html))
    }

    func loadContent(_ content: PSInfoPopupContent) {
        if isViewLoaded {
            apply(content)
        } else {
            pendingContent = content
        }
    }

    private func apply(_ content: PSInfoPopupContent) {
        headerView.isHidden = !content.isStrongsEntry
        configureHeader(with: content)

        searchTerm = content.searchTerm
        searchContainer.isHidden = content.searchTerm == nil

        let topInset: CGFloat = content.isStrongsEntry ? 0 : 20
        let insets = UIEdgeInsets(top: topInset, left: 0, bottom: 0, right: 0)
        webView.scrollView.contentInset = insets
        webView.scrollView.scrollIndicatorInsets = insets
        webView.loadHTMLString(content.html, baseURL: nil)
    }

    private func configureHeader(with content: PSInfoPopupContent) {
        guard content.isStrongsEntry else { return }

        if let lemma = content.lemma, let reference = content.reference {
            // Word is the hero; reference folds into the subtitle.
            subtitleLabel.text = [content.contextTitle, reference]
                .compactMap { $0 }
                .joined(separator: " · ")
            heroLabel.text = lemma
            heroLabel.font = scriptFont(hebrew: content.isHebrew)
        } else {
            // No parseable lemma — fall back to the reference as the hero.
            subtitleLabel.text = content.contextTitle
            heroLabel.text = content.reference
            let referenceFont = UIFont.systemFont(ofSize: 28, weight: .semibold)
            heroLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: referenceFont)
        }

        transliterationLabel.text = content.transliteration
        transliterationLabel.isHidden = content.transliteration == nil
    }

    /// The bundled script font for the lemma, scaled for Dynamic Type. Falls
    /// back to a system semibold if the custom font isn't registered.
    private func scriptFont(hebrew: Bool) -> UIFont {
        let name = hebrew ? AppConstants.hebrewStrongsFontName : AppConstants.greekStrongsFontName
        let base = UIFont(name: name, size: Self.heroFontSize)
            ?? UIFont.systemFont(ofSize: Self.heroFontSize, weight: .semibold)
        return UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: base)
    }

    private func makeHeaderView() -> UIView {
        let header = UIView()
        header.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 24, leading: 20, bottom: 16, trailing: 20)

        let rail = UIView()
        rail.translatesAutoresizingMaskIntoConstraints = false
        rail.backgroundColor = Self.studyAccent
        rail.layer.cornerRadius = 1.5
        header.addSubview(rail)

        // Small subtitle: "Greek Strong's lexicon · G3588".
        let subtitleLabel = UILabel()
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 0
        self.subtitleLabel = subtitleLabel

        // Hero: the Greek/Hebrew lemma in its proper script (font is swapped in
        // -apply: depending on Greek vs Hebrew), or the reference as a fallback.
        let heroLabel = UILabel()
        heroLabel.adjustsFontForContentSizeCategory = true
        heroLabel.textColor = UIColor.label
        heroLabel.numberOfLines = 0
        heroLabel.textAlignment = .natural
        self.heroLabel = heroLabel

        // Transliteration, e.g. "ho" — hidden when unavailable.
        let transliterationLabel = UILabel()
        let translitBase = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
            .withSymbolicTraits(.traitItalic) ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .subheadline)
        transliterationLabel.font = UIFont(descriptor: translitBase, size: 0)
        transliterationLabel.adjustsFontForContentSizeCategory = true
        transliterationLabel.textColor = UIColor.secondaryLabel
        transliterationLabel.numberOfLines = 1
        self.transliterationLabel = transliterationLabel

        let labels = UIStackView(arrangedSubviews: [subtitleLabel, heroLabel, transliterationLabel])
        labels.translatesAutoresizingMaskIntoConstraints = false
        labels.axis = .vertical
        labels.spacing = 4
        labels.setCustomSpacing(2, after: heroLabel)
        header.addSubview(labels)

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator
        header.addSubview(separator)

        let guide = header.layoutMarginsGuide
        NSLayoutConstraint.activate([
            rail.topAnchor.constraint(equalTo: guide.topAnchor),
            rail.leadingAnchor.constraint(equalTo: guide.leadingAnchor),
            rail.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
            rail.widthAnchor.constraint(equalToConstant: 3),

            labels.topAnchor.constraint(equalTo: guide.topAnchor),
            labels.leadingAnchor.constraint(equalTo: rail.trailingAnchor, constant: 13),
            labels.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
            labels.bottomAnchor.constraint(equalTo: guide.bottomAnchor),

            separator.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -20),
            separator.bottomAnchor.constraint(equalTo: header.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale)
        ])

        return header
    }

    private func makeSearchContainer() -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor.clear

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = UIColor.separator
        container.addSubview(separator)

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.title = NSLocalizedString("StrongsSearchFindAll", comment: "")
        configuration.image = UIImage(systemName: "magnifyingglass")
        configuration.imagePadding = 10
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        configuration.baseForegroundColor = Self.studyAccent
        button.configuration = configuration
        button.contentHorizontalAlignment = .leading
        button.addTarget(self, action: #selector(searchButtonTapped), for: .touchUpInside)
        container.addSubview(button)

        NSLayoutConstraint.activate([
            separator.topAnchor.constraint(equalTo: container.topAnchor),
            separator.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            separator.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

            button.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 4),
            button.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48)
        ])

        return container
    }

    @objc private func searchButtonTapped() {
        guard let searchTerm = searchTerm else { return }
        onSearch?(searchTerm)
    }
}
