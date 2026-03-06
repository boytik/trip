//
//  WebViewHostingViewController.swift
//  Trip
//
//  Hosts WebView content with support for all orientations.
//

import SwiftUI
import UIKit

struct WebViewHostingViewControllerWrapper: UIViewControllerRepresentable {
    let url: URL
    let onError: () -> Void
    let on404Detected: () -> Void

    func makeUIViewController(context: Context) -> WebViewHostingViewController {
        let vc = WebViewHostingViewController()
        vc.currentURL = url
        let content = DocumentViewContainer(
            url: url,
            navStore: vc.navStore,
            onError: onError,
            on404Detected: on404Detected
        )
        let hosting = UIHostingController(rootView: content)
        vc.hostingController = hosting
        vc.addChild(hosting)
        vc.view.addSubview(hosting.view)
        hosting.view.frame = vc.view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: vc)
        return vc
    }

    func updateUIViewController(_ uiViewController: WebViewHostingViewController, context: Context) {
        uiViewController.updateContent(url: url, onError: onError, on404Detected: on404Detected)
    }
}

final class WebViewHostingViewController: UIViewController {
    let navStore = WebViewNavigationStore()
    var hostingController: UIHostingController<DocumentViewContainer>?
    var currentURL: URL?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait, .landscapeLeft, .landscapeRight]
    }

    override var shouldAutorotate: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(VitalPalette.myBackground)
    }

    func updateContent(url: URL, onError: @escaping () -> Void, on404Detected: @escaping () -> Void) {
        guard url != currentURL else { return }
        currentURL = url
        let content = DocumentViewContainer(url: url, navStore: navStore, onError: onError, on404Detected: on404Detected)
        hostingController?.rootView = content
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔄 [Orientation] WebViewHostingViewController.viewWillAppear")
        print("🔄 [Orientation] view.window: \(view.window != nil), windowScene: \(view.window?.windowScene != nil)")
        if let appDelegate = DocumentFlowAppDelegate.shared {
            appDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
            print("🔄 [Orientation] set orientationLock from WebViewHostingViewController")
        } else {
            print("❌ [Orientation] DocumentFlowAppDelegate.shared is nil")
        }
        if #available(iOS 16.0, *) {
            if let windowScene = view.window?.windowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight]
                )
                windowScene.requestGeometryUpdate(geometryPreferences) { error in
                    print("🔄 [Orientation] WebViewHostingVC requestGeometryUpdate failed: \(error.localizedDescription)")
                }
            } else {
                print("❌ [Orientation] view.window?.windowScene is nil in viewWillAppear")
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if view.window != nil, DocumentFlowAppDelegate.shared != nil {
            print("🔄 [Orientation] viewDidAppear: window ready, re-applying orientation")
            DocumentFlowAppDelegate.shared?.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
        }
    }
}
