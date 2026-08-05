import SwiftUI
import WebKit

enum ReaderBridgeEvent: Equatable {
    case currentVerse(verse: Int, scrollPosition: CGFloat)
    case verseMenu(verse: Int)
    case versePositions([CGFloat])

    init?(url: URL) {
        let components = url.absoluteString.components(separatedBy: ":")
        guard let scheme = components.first else {
            return nil
        }

        switch scheme {
        case "pocketsword":
            guard components.count >= 3, let verse = Int(components[2]) else {
                return nil
            }
            switch components[1] {
            case "currentverse":
                guard components.count >= 4 else {
                    return nil
                }
                self = .currentVerse(
                    verse: verse,
                    scrollPosition: CGFloat(
                        (components[3] as NSString).doubleValue
                    )
                )
            case "versemenu":
                self = .verseMenu(verse: verse)
            default:
                return nil
            }
        case "arraydump":
            guard components.count > 1 else {
                return nil
            }
            self = .versePositions(
                components.dropFirst().map {
                    CGFloat(($0 as NSString).doubleValue)
                }
            )
        default:
            return nil
        }
    }
}

@MainActor
protocol ReaderWebPageModelDelegate: AnyObject {
    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        decidePolicyFor request: URLRequest
    ) -> WKNavigationActionPolicy
    func readerWebPageModel(
        _ model: ReaderWebPageModel,
        didScrollTo offset: CGFloat
    )
    func readerWebPageModelDidStartNavigation(_ model: ReaderWebPageModel)
    func readerWebPageModelDidFinishNavigation(_ model: ReaderWebPageModel)
    func readerWebPageModelDidEndUserScroll(_ model: ReaderWebPageModel)
}

@MainActor
private final class ReaderNavigationDecider: WebPage.NavigationDeciding {
    weak var model: ReaderWebPageModel?

    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        model?.navigationPolicy(for: action.request) ?? .allow
    }
}

@MainActor
final class ReaderWebPageModel {
    let page: WebPage
    weak var delegate: ReaderWebPageModelDelegate?
    private(set) var lastScrollOffset: CGFloat = 0

    private let navigationDecider: ReaderNavigationDecider
    private var navigationTask: Task<Void, Never>?
    private var javaScriptTask: Task<Void, Never>?

    init() {
        let navigationDecider = ReaderNavigationDecider()
        self.navigationDecider = navigationDecider
        self.page = WebPage(navigationDecider: navigationDecider)
        navigationDecider.model = self
    }

    func loadHTMLString(_ html: String, baseURL: URL) {
        javaScriptTask?.cancel()
        javaScriptTask = nil
        delegate?.readerWebPageModelDidStartNavigation(self)
        let events = page.load(html: html, baseURL: baseURL)
        navigationTask = Task { [weak self] in
            do {
                for try await event in events {
                    guard !Task.isCancelled, let self else {
                        return
                    }
                    switch event {
                    case .finished:
                        delegate?.readerWebPageModelDidFinishNavigation(self)
                    case .startedProvisionalNavigation,
                         .receivedServerRedirect,
                         .committed:
                        break
                    }
                }
            } catch {
                return
            }
        }
    }

    func evaluateJavaScript(
        _ script: String,
        completion: ((Any?) -> Void)? = nil
    ) {
        let previousTask = javaScriptTask
        javaScriptTask = Task { [weak self] in
            await previousTask?.value
            guard let self else {
                completion?(nil)
                return
            }
            let result = try? await page.callJavaScript(script)
            completion?(result)
        }
    }

    func highlightAllOccurrences(of term: String) {
        guard let path = Bundle.main.path(
            forResource: "SearchWebView",
            ofType: "js"
        ),
        let source = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        let previousTask = javaScriptTask
        javaScriptTask = Task { [weak self] in
            await previousTask?.value
            guard let self else {
                return
            }
            _ = try? await page.callJavaScript(source)
            _ = try? await page.callJavaScript(
                "PS_HighlightAllOccurencesOfString(term)",
                arguments: ["term": term]
            )
        }
    }

    fileprivate func didScroll(to offset: CGFloat) {
        let normalizedOffset = max(0, offset)
        guard abs(lastScrollOffset - normalizedOffset) > 2 else {
            return
        }
        lastScrollOffset = normalizedOffset
        delegate?.readerWebPageModel(self, didScrollTo: lastScrollOffset)
    }

    fileprivate func didEndUserScroll() {
        delegate?.readerWebPageModelDidEndUserScroll(self)
    }

    fileprivate func navigationPolicy(
        for request: URLRequest
    ) -> WKNavigationActionPolicy {
        delegate?.readerWebPageModel(
            self,
            decidePolicyFor: request
        ) ?? .allow
    }
}

struct SwiftUIReaderWebView: View {
    let model: ReaderWebPageModel

    var body: some View {
        WebView(model.page)
            .webViewBackForwardNavigationGestures(.disabled)
            .webViewLinkPreviews(.disabled)
            .webViewOnScrollGeometryChange(
                for: CGFloat.self,
                of: {
                    $0.contentOffset.y + $0.contentInsets.top
                },
                action: { _, offset in
                    model.didScroll(to: offset)
                }
            )
            .onScrollPhaseChange { oldPhase, newPhase in
                if oldPhase != .animating && oldPhase.isScrolling
                    && newPhase == .idle {
                    model.didEndUserScroll()
                }
            }
            .clipped()
            .accessibilityIdentifier("reading.web-content")
    }
}
