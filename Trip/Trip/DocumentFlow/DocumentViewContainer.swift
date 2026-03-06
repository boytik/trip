//
//  DocumentViewContainer.swift
//  Trip
//
//  WebView container with app rating alert and bottom navigation bar.
//

import SwiftUI
import StoreKit

struct DocumentViewContainer: View {
    let url: URL
    let navStore: WebViewNavigationStore
    let onError: () -> Void
    let on404Detected: () -> Void

    private var homeURL: URL? {
        DocumentValidationService.shared.getSavedURL()
    }

    var body: some View {
        DocumentViewPanel(
            url: url,
            navigationStore: navStore,
            onError: onError,
            on404Detected: on404Detected
        )
        .id(url.absoluteString)
        .ignoresSafeArea(edges: [.top, .horizontal])
        .safeAreaInset(edge: .bottom, spacing: 0) {
            WebViewNavBar(
                navStore: navStore,
                homeURL: homeURL
            )
            .background(VitalPalette.myBackground.ignoresSafeArea(edges: .bottom))
        }
        .background(VitalPalette.myBackground.ignoresSafeArea())
        .onAppear {
            requestAppReview()
        }
    }

    private func requestAppReview() {
        let key = "DocumentFlowHasRequestedAppReview"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }

        UserDefaults.standard.set(true, forKey: key)
        SKStoreReviewController.requestReview(in: windowScene)
    }
}

// MARK: - WebView Navigation Bar

private struct WebViewNavBar: View {
    @ObservedObject var navStore: WebViewNavigationStore
    let homeURL: URL?

    var body: some View {
        HStack(spacing: 0) {
            navButton(icon: "chevron.left", enabled: navStore.canGoBack) {
                navStore.goBack()
            }
            navButton(icon: "chevron.right", enabled: navStore.canGoForward) {
                navStore.goForward()
            }
            navButton(icon: "house.fill", enabled: homeURL != nil) {
                if let url = homeURL {
                    navStore.goHome(url: url)
                }
            }
            navButton(icon: "arrow.clockwise", enabled: true) {
                navStore.reload()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(VitalPalette.myBackground)
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(enabled ? VitalPalette.ivoryBreath : VitalPalette.ashVeil)
                .frame(maxWidth: .infinity)
        }
        .disabled(!enabled)
    }
}
