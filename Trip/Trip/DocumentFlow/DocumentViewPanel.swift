//
//  DocumentViewPanel.swift
//  Trip
//
//  WebView wrapper component with error handling, orientation support,
//  and persistent cookie/session storage for automatic login.
//

import SwiftUI
import WebKit
import UIKit
import Combine

/// Shared WebView configuration for cookie/session persistence across app launches.
private enum WebViewConfig {
    static let processPool = WKProcessPool()
    static let dataStore = WKWebsiteDataStore.default()
}

/// Holds WebView reference and navigation state for the bottom nav bar.
@MainActor
final class WebViewNavigationStore: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    weak var webView: WKWebView? {
        didSet { updateNavigationState() }
    }
    var canGoBack = false { willSet { objectWillChange.send() } }
    var canGoForward = false { willSet { objectWillChange.send() } }

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
    func goHome(url: URL) {
        webView?.load(URLRequest(url: url))
    }
    func updateNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }
}

struct DocumentViewPanel: UIViewRepresentable {
    let url: URL
    let navigationStore: WebViewNavigationStore
    let onError: () -> Void
    let on404Detected: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.processPool = WebViewConfig.processPool
        config.websiteDataStore = WebViewConfig.dataStore
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Убираем левый отступ у веб-страниц (многие сайты добавляют margin)
        let removeLeftMarginScript = WKUserScript(
            source: """
            (function() {
                var style = document.createElement('style');
                style.textContent = 'html, body { margin-left: 0 !important; padding-left: 0 !important; }';
                (document.head || document.documentElement).appendChild(style);
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(removeLeftMarginScript)

        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        // Без этого контент не заходит под home indicator в ландшафте
        view.scrollView.contentInsetAdjustmentBehavior = .never
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true

        navigationStore.webView = view
        context.coordinator.setupNavigationObservers(for: view, store: navigationStore)
        context.coordinator.startTimeoutTimer()

        var request = URLRequest(url: url)
        request.timeoutInterval = 7.0
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        view.load(request)

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Гарантируем отсутствие отступов под safe area (home indicator)
        uiView.scrollView.contentInsetAdjustmentBehavior = .never
        uiView.scrollView.contentInset = .zero
        uiView.scrollView.verticalScrollIndicatorInsets = .zero
        uiView.scrollView.horizontalScrollIndicatorInsets = .zero
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: DocumentViewPanel
        var timeoutTimer: Timer?
        private var canGoBackObservation: NSKeyValueObservation?
        private var canGoForwardObservation: NSKeyValueObservation?

        init(_ parent: DocumentViewPanel) {
            self.parent = parent
        }

        func setupNavigationObservers(for webView: WKWebView, store: WebViewNavigationStore) {
            canGoBackObservation?.invalidate()
            canGoForwardObservation?.invalidate()
            canGoBackObservation = webView.observe(\.canGoBack, options: [.new]) { _, _ in
                DispatchQueue.main.async { store.updateNavigationState() }
            }
            canGoForwardObservation = webView.observe(\.canGoForward, options: [.new]) { _, _ in
                DispatchQueue.main.async { store.updateNavigationState() }
            }
        }

        deinit {
            canGoBackObservation?.invalidate()
            canGoForwardObservation?.invalidate()
        }

        func startTimeoutTimer() {
            cancelTimeout()
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: false) { [weak self] _ in
                self?.triggerFallback()
            }
            RunLoop.current.add(timeoutTimer!, forMode: .common)
        }

        func cancelTimeout() {
            timeoutTimer?.invalidate()
            timeoutTimer = nil
        }

        private func triggerFallback() {
            cancelTimeout()
            DispatchQueue.main.async {
                self.parent.onError()
            }
        }

        private func isNetworkError(_ error: Error) -> Bool {
            let nsError = error as NSError
            return nsError.domain == NSURLErrorDomain && (
                nsError.code == NSURLErrorTimedOut ||
                nsError.code == NSURLErrorNotConnectedToInternet ||
                nsError.code == NSURLErrorCannotConnectToHost ||
                nsError.code == NSURLErrorNetworkConnectionLost
            )
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.navigationStore.updateNavigationState()
            }
            if isNetworkError(error) {
                triggerFallback()
            }
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            DispatchQueue.main.async { [weak self] in
                self?.parent.navigationStore.updateNavigationState()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelTimeout()
            DispatchQueue.main.async { [weak self] in
                self?.parent.navigationStore.updateNavigationState()
            }

            let script = """
            (function() {
                var title = document.title.toLowerCase();
                var bodyText = document.body ? document.body.innerText.toLowerCase() : '';
                var is404 = title.includes('404') || 
                           bodyText.includes('404') || 
                           bodyText.includes('not found');
                return is404;
            })();
            """

            webView.evaluateJavaScript(script) { [weak self] result, _ in
                if let is404 = result as? Bool, is404 {
                    DispatchQueue.main.async {
                        self?.parent.on404Detected()
                    }
                }
            }
        }
    }
}
