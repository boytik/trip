//
//  DocumentViewPanel.swift
//  Trip
//
//  WebView wrapper component with error handling and orientation support.
//

import SwiftUI
import WebKit
import UIKit

struct DocumentViewPanel: UIViewRepresentable {
    let url: URL
    let onError: () -> Void
    let on404Detected: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let view = WKWebView(frame: .zero, configuration: config)
        view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1"
        view.backgroundColor = .black
        view.scrollView.backgroundColor = .black
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true

        context.coordinator.startTimeoutTimer()

        var request = URLRequest(url: url)
        request.timeoutInterval = 7.0
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")

        view.load(request)

        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: DocumentViewPanel
        var timeoutTimer: Timer?

        init(_ parent: DocumentViewPanel) {
            self.parent = parent
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
            if isNetworkError(error) {
                triggerFallback()
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            cancelTimeout()

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
