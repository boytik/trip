//
//  DocumentViewContainer.swift
//  Trip
//
//  WebView container with app rating alert and bottom navigation bar.
//  Nav bar is pinned opposite to the notch: bottom in portrait, left/right in landscape.
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
        OrientationAwareNavBarWrapper(
            navStore: navStore,
            homeURL: homeURL,
            content: {
                DocumentViewPanel(
                    url: url,
                    navigationStore: navStore,
                    onError: onError,
                    on404Detected: on404Detected
                )
                .id(url.absoluteString)
                .ignoresSafeArea(edges: [.top, .horizontal])
            }
        )
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

// MARK: - Orientation-Aware Nav Bar Wrapper

/// Positions nav bar opposite to the notch: bottom in portrait, left when notch is right, right when notch is left.
private struct OrientationAwareNavBarWrapper<Content: View>: View {
    let navStore: WebViewNavigationStore
    let homeURL: URL?
    @ViewBuilder let content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let (navEdge, isVertical) = navBarEdgeAndOrientation(for: geo)
            let navBar = WebViewNavBar(navStore: navStore, homeURL: homeURL, vertical: isVertical)
                .background(VitalPalette.myBackground)

            switch navEdge {
            case .bottom:
                VStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    navBar
                }
            case .top:
                VStack(spacing: 0) {
                    navBar
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .leading:
                HStack(spacing: 0) {
                    navBar
                        .frame(width: 60)
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .trailing:
                HStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    navBar
                        .frame(width: 60)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func navBarEdgeAndOrientation(for geo: GeometryProxy) -> (Edge, Bool) {
        let isLandscape = geo.size.width > geo.size.height
        guard isLandscape else { return (.bottom, false) }

        // Notch side has larger safe area inset; nav goes opposite
        if geo.safeAreaInsets.leading > geo.safeAreaInsets.trailing {
            return (.trailing, true)  // notch on left → nav on right
        }
        return (.leading, true)  // notch on right → nav on left
    }
}

// MARK: - WebView Navigation Bar

private struct WebViewNavBar: View {
    @ObservedObject var navStore: WebViewNavigationStore
    let homeURL: URL?
    var vertical: Bool = false

    var body: some View {
        Group {
            if vertical {
                VStack(spacing: 0) {
                    navButtons
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
            } else {
                HStack(spacing: 0) {
                    navButtons
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
            }
        }
        .background(VitalPalette.myBackground)
    }

    private var navButtons: some View {
        Group {
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
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(enabled ? VitalPalette.ivoryBreath : VitalPalette.ashVeil)
                .frame(width: vertical ? 44 : nil, height: vertical ? 44 : 36)
                .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
        }
        .disabled(!enabled)
    }
}
