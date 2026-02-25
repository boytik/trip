//
//  DocumentFlowState.swift
//  Trip
//
//  Main flow controller managing state transitions for the document flow.
//

import Foundation
import Combine
import SwiftUI

enum DocumentFlowPhase: Equatable {
    case loading
    case webView(URL)
    case nativeApp
}

final class DocumentFlowState: ObservableObject {
    let objectWillChange = ObservableObjectPublisher()

    var currentPhase: DocumentFlowPhase = .loading {
        willSet { objectWillChange.send() }
    }

    private let validationService = DocumentValidationService.shared

    init() {}

    func startDocumentFlow() {
        if let firstChoice = validationService.getFirstLaunchChoice() {
            print("📌 [DocumentFlow] Выбор уже установлен: \(firstChoice)")
            handleSavedChoice(firstChoice)
            return
        }

        print("📌 [DocumentFlow] Первый запуск — выполняем валидации")
        currentPhase = .loading
        runValidations()
    }

    private func handleSavedChoice(_ choice: String) {
        if choice == DocumentChoice.webView {
            if let savedURL = validationService.getSavedURL() {
                print("📌 [DocumentFlow] Используем сохранённую ссылку: \(savedURL.absoluteString)")
                if let pathId = validationService.getSavedPathId() {
                    print("📌 [DocumentFlow] Сохранённый path id: \(pathId)")
                }
                currentPhase = .webView(savedURL)
                return
            }
            print("🔄 [DocumentFlow] Fallback: сохранённой ссылки нет, пробуем path id")
            tryFallbackURL { [weak self] success, url in
                if success, let url = url {
                    self?.currentPhase = .webView(url)
                } else {
                    self?.currentPhase = .webView(URL(string: "about:blank")!)
                }
            }
            return
        }

        if choice == DocumentChoice.nativeApp {
            currentPhase = .nativeApp
        }
    }

    private func runValidations() {
        if !validationService.documentCheckDatePublic() {
            validationService.setFirstLaunchChoice(DocumentChoice.nativeApp)
            currentPhase = .nativeApp
            return
        }

        if validationService.isTabletDevice() {
            validationService.setFirstLaunchChoice(DocumentChoice.nativeApp)
            currentPhase = .nativeApp
            return
        }

        validationService.checkInternetConnection { [weak self] hasInternet in
            guard let self = self else { return }
            guard hasInternet else {
                self.validationService.setFirstLaunchChoice(DocumentChoice.nativeApp)
                self.currentPhase = .nativeApp
                return
            }

            let primaryURL = self.validationService.getPrimaryServerURL()
            self.validationService.requestServerURL(urlString: primaryURL) { [weak self] success, url in
                guard let self = self else { return }
                if success, let url = url {
                    print("✅ [DocumentFlow] Сервер OK → webView")
                    self.validationService.setFirstLaunchChoice(DocumentChoice.webView)
                    self.currentPhase = .webView(url)
                } else {
                    print("❌ [DocumentFlow] Сервер ошибка → nativeApp")
                    self.validationService.setFirstLaunchChoice(DocumentChoice.nativeApp)
                    self.currentPhase = .nativeApp
                }
            }
        }
    }

    func tryFallbackURL(completion: @escaping (Bool, URL?) -> Void) {
        print("🔄 [DocumentFlow] Запуск fallback логики")
        validationService.clearSavedDestinationURL()

        guard let fallbackURL = validationService.buildFallbackURL() else {
            print("❌ [DocumentFlow] Fallback: не удалось построить URL")
            completion(false, nil)
            return
        }

        validationService.requestServerURL(urlString: fallbackURL.absoluteString) { success, url in
            if success, let url = url {
                print("✅ [DocumentFlow] Fallback успешен: \(url.absoluteString)")
            } else {
                print("❌ [DocumentFlow] Fallback не удался")
            }
            completion(success, url)
        }
    }
}
