//
//  DocumentFlowAppDelegate.swift
//  Trip
//
//  App delegate for orientation control in document flow.
//

import UIKit

class DocumentFlowAppDelegate: NSObject, UIApplicationDelegate {
    var orientationLock: UIInterfaceOrientationMask = .portrait

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        orientationLock
    }
}
