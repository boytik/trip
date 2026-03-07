

import SwiftUI
import StoreKit
import UIKit

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

    @State private var deviceOrientation: UIDeviceOrientation = UIDevice.current.orientation

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
                    sideNavBar(navBar: navBar, geo: geo)
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .trailing:
                HStack(spacing: 0) {
                    content()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    sideNavBar(navBar: navBar, geo: geo)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let newOrientation = UIDevice.current.orientation
            if newOrientation.isValidInterfaceOrientation {
                deviceOrientation = newOrientation
            }
        }
        .onAppear {
            deviceOrientation = UIDevice.current.orientation
        }
    }

    private func navBarEdgeAndOrientation(for geo: GeometryProxy) -> (Edge, Bool) {
        let orientation = deviceOrientation
        let w = geo.size.width
        let h = geo.size.height

        // Клавиатура может дать почти квадратные размеры (402×399) — не считать ландшафтом
        let aspectRatio = max(w, h) > 0 ? min(w, h) / max(w, h) : 1.0
        let geometrySaysLandscape = w > h && aspectRatio < 0.85

        // Только если и геометрия, и устройство в ландшафте — показываем боковую панель
        let isLandscape = geometrySaysLandscape && (orientation == .landscapeLeft || orientation == .landscapeRight)

        guard isLandscape else {
            print("🔄 [NavPanel] portrait → nav bottom (aspect=\(String(format: "%.2f", aspectRatio)), orient=\(orientation.rawValue))")
            return (.bottom, false)
        }

        let leadingInset = geo.safeAreaInsets.leading
        let trailingInset = geo.safeAreaInsets.trailing

        print("🔄 [NavPanel] landscape: deviceOrientation=\(orientation.rawValue) (\(deviceOrientationName(orientation))), size=\(Int(w))×\(Int(h)), safeArea leading=\(leadingInset) trailing=\(trailingInset)")

        switch orientation {
        case .landscapeLeft:
            print("🔄 [NavPanel] → landscapeLeft (челка СЛЕВА) → nav справа (.trailing)")
            return (.trailing, true)
        case .landscapeRight:
            print("🔄 [NavPanel] → landscapeRight (челка СПРАВА) → nav слева (.leading)")
            return (.leading, true)
        default:
            if leadingInset > trailingInset {
                print("🔄 [NavPanel] → default: leading>trailing → nav справа (.trailing)")
                return (.trailing, true)
            }
            print("🔄 [NavPanel] → default: nav слева (.leading)")
            return (.leading, true)
        }
    }

    private func deviceOrientationName(_ o: UIDeviceOrientation) -> String {
        switch o {
        case .portrait: return "portrait"
        case .portraitUpsideDown: return "portraitUpsideDown"
        case .landscapeLeft: return "landscapeLeft"
        case .landscapeRight: return "landscapeRight"
        case .faceUp: return "faceUp"
        case .faceDown: return "faceDown"
        default: return "unknown(\(o.rawValue))"
        }
    }

    private func sideNavBar<NavBar: View>(navBar: NavBar, geo: GeometryProxy) -> some View {
        navBar
            .frame(width: 48)
            .padding(.top, geo.safeAreaInsets.top)
            .padding(.bottom, geo.safeAreaInsets.bottom)
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
                .padding(.vertical, 8)
                .padding(.horizontal, 6)
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
                .frame(width: vertical ? 36 : nil, height: vertical ? 36 : 36)
                .frame(maxWidth: vertical ? nil : .infinity, maxHeight: vertical ? .infinity : nil)
        }
        .disabled(!enabled)
    }
}
