//
//  DocumentFlowAppDelegate.swift
//  Trip
//
//  App delegate for orientation control, push notifications, and Firebase.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class DocumentFlowAppDelegate: NSObject,
                               UIApplicationDelegate,
                               UNUserNotificationCenterDelegate,
                               MessagingDelegate {
    /// Shared reference — UIApplication.shared.delegate can be a Firebase/SwiftUI proxy.
    static weak var shared: DocumentFlowAppDelegate?

    var orientationLock: UIInterfaceOrientationMask = .portrait {
        didSet {
            print("🔄 [Orientation] orientationLock changed: \(orientationLock.rawValue) (was: \(oldValue.rawValue))")
            applyOrientationToWindowScenes()
        }
    }

    private func applyOrientationToWindowScenes() {
        print("🔄 [Orientation] applyOrientationToWindowScenes called")
        guard #available(iOS 16.0, *) else {
            print("🔄 [Orientation] iOS 16+ required, skipping requestGeometryUpdate")
            return
        }
        let scenes = UIApplication.shared.connectedScenes
        print("🔄 [Orientation] connectedScenes count: \(scenes.count)")
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else {
                print("🔄 [Orientation] scene is not UIWindowScene: \(type(of: scene))")
                continue
            }
            print("🔄 [Orientation] requesting geometry update for scene, orientations: \(orientationLock.rawValue)")
            let prefs = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: orientationLock)
            windowScene.requestGeometryUpdate(prefs) { error in
                print("❌ [Orientation] requestGeometryUpdate FAILED: \(error.localizedDescription)")
            }
        }
        notifyOrientationUpdate()
    }

    private func notifyOrientationUpdate() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        print("🔄 [Orientation] total windows: \(windows.count), keyWindow: \(windows.first(where: { $0.isKeyWindow }) != nil)")
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else {
            print("🔄 [Orientation] no window found for setNeedsUpdateOfSupportedInterfaceOrientations")
            return
        }
        var vc: UIViewController? = window.rootViewController
        var depth = 0
        while let current = vc {
            print("🔄 [Orientation] setNeedsUpdate at depth \(depth): \(type(of: current))")
            current.setNeedsUpdateOfSupportedInterfaceOrientations()
            vc = current.presentedViewController
            depth += 1
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        DocumentFlowAppDelegate.shared = self
        FirebaseApp.configure()

        // Push notification permission
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                print("Push permission:", granted)
            }

        application.registerForRemoteNotifications()
        Messaging.messaging().delegate = self

        return true
    }

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        print("🔄 [Orientation] supportedInterfaceOrientationsFor called → returning \(orientationLock.rawValue)")
        return orientationLock
    }

    // FCM token
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 FCM Token:", fcmToken ?? "")
    }

    // Pass APNs token to Firebase
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // Show push when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }
}
