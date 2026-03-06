//
//  DocumentRootView.swift
//  Trip
//
//  Root view orchestrating the entire document flow.
//

import SwiftUI

struct DocumentRootView: View {
    @EnvironmentObject private var flowState: DocumentFlowState
    @EnvironmentObject private var vault: VitalDataVault
    @EnvironmentObject private var router: VitalRouter

    var body: some View {
        Group {
            switch flowState.currentPhase {
            case .loading:
                DocumentSplashScreenView()
                    .ignoresSafeArea(.all, edges: .all)

            case .webView(let url):
                WebViewHostingViewControllerWrapper(
                    url: url,
                    onError: handleRouteError,
                    on404Detected: handle404Detected
                )
                .id(url.absoluteString)
                .onAppear { setWebViewOrientation() }

            case .nativeApp:
                NativeAppViewControllerWrapper {
                    nativeAppContent
                }
                .ignoresSafeArea(.all, edges: .all)
            }
        }
        .onAppear {
            flowState.startDocumentFlow()
        }
    }

    private var nativeAppContent: some View {
        VitalLifecycleGate()
            .environmentObject(vault)
            .environmentObject(router)
    }

    private func handleRouteError() {
        print("🔄 [DocumentFlow] Ошибка загрузки — запуск fallback")
        flowState.tryFallbackURL { success, url in
            if success, let url = url {
                flowState.currentPhase = .webView(url)
            } else {
                flowState.currentPhase = .webView(URL(string: "about:blank")!)
            }
        }
    }

    private func handle404Detected() {
        handleRouteError()
    }

    private func setWebViewOrientation() {
        print("🔄 [Orientation] setWebViewOrientation called from DocumentRootView.onAppear")
        guard let appDelegate = DocumentFlowAppDelegate.shared else {
            print("❌ [Orientation] DocumentFlowAppDelegate.shared is nil")
            return
        }
        let mask: UIInterfaceOrientationMask = [.portrait, .landscapeLeft, .landscapeRight]
        print("🔄 [Orientation] setting orientationLock to all (portrait+landscape)")
        appDelegate.orientationLock = mask
        // Retry after delay — window scene may not be ready on first appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔄 [Orientation] delayed retry: re-applying orientation")
            appDelegate.orientationLock = mask
        }
    }
}
