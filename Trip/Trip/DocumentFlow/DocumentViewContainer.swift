//
//  DocumentViewContainer.swift
//  Trip
//
//  WebView container with app rating alert.
//

import SwiftUI
import StoreKit

struct DocumentViewContainer: View {
    let url: URL
    let onError: () -> Void
    let on404Detected: () -> Void

    var body: some View {
        DocumentViewPanel(
            url: url,
            onError: onError,
            on404Detected: on404Detected
        )
        .id(url.absoluteString)
        .ignoresSafeArea(.all, edges: .all)
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
