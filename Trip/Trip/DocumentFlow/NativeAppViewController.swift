//
//  NativeAppViewController.swift
//  Trip
//
//  Wrapper for native SwiftUI content enforcing portrait-only orientation.
//

import SwiftUI
import UIKit

struct NativeAppViewControllerWrapper: UIViewControllerRepresentable {
    let content: AnyView

    init<Content: View>(@ViewBuilder content: () -> Content) {
        self.content = AnyView(content())
    }

    func makeUIViewController(context: Context) -> NativeAppViewController {
        let vc = NativeAppViewController()
        let hosting = UIHostingController(rootView: content)
        vc.addChild(hosting)
        vc.view.addSubview(hosting.view)
        hosting.view.frame = vc.view.bounds
        hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        hosting.didMove(toParent: vc)
        return vc
    }

    func updateUIViewController(_ uiViewController: NativeAppViewController, context: Context) {}
}

final class NativeAppViewController: UIViewController {
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var shouldAutorotate: Bool {
        false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isOpaque = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        forcePortraitOrientation()
    }

    private func forcePortraitOrientation() {
        if let appDelegate = UIApplication.shared.delegate as? DocumentFlowAppDelegate {
            appDelegate.orientationLock = .portrait
        }
        if #available(iOS 16.0, *) {
            if let windowScene = view.window?.windowScene {
                let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: .portrait)
                windowScene.requestGeometryUpdate(geometryPreferences) { _ in }
            }
        }
    }
}
