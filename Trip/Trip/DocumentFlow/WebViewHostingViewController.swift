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
        let content = DocumentViewContainer(
            url: url,
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
    var hostingController: UIHostingController<DocumentViewContainer>?

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        [.portrait, .landscapeLeft, .landscapeRight]
    }

    override var shouldAutorotate: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }

    func updateContent(url: URL, onError: @escaping () -> Void, on404Detected: @escaping () -> Void) {
        let content = DocumentViewContainer(url: url, onError: onError, on404Detected: on404Detected)
        hostingController?.rootView = content
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let appDelegate = UIApplication.shared.delegate as? DocumentFlowAppDelegate {
            appDelegate.orientationLock = [.portrait, .landscapeLeft, .landscapeRight]
        }
        if #available(iOS 16.0, *) {
            if let windowScene = view.window?.windowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                    interfaceOrientations: [.portrait, .landscapeLeft, .landscapeRight]
                )
                windowScene.requestGeometryUpdate(geometryPreferences) { _ in }
            }
        }
    }
}
