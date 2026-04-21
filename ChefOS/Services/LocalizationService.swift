//
//  LocalizationService.swift
//  ChefOS
//
//  Thin localization service — translations live in Core/Localization/LocalizationService+*.swift
//

import Foundation
import Combine
import SwiftUI

// MARK: - In-App Localization

final class LocalizationService: ObservableObject {
    @Published var language: String {
        didSet {
            UserDefaults.standard.set(language, forKey: "app_language")
        }
    }

    static let shared = LocalizationService()

    init() {
        self.language = UserDefaults.standard.string(forKey: "app_language") ?? "en"
    }

    func t(_ key: String) -> String {
        let value = translations[language]?[key] ?? translations["en"]?[key]
        #if DEBUG
        if value == nil {
            print("❗️ Missing localization [\(language)]: \(key)")
        }
        #endif
        return value ?? key
    }

    // MARK: - All translations (built from per-language extensions)
    private var translations: [String: [String: String]] {
        [
            "en": LocalizationService.en,
            "ru": LocalizationService.ru,
            "pl": LocalizationService.pl,
            "uk": LocalizationService.uk
        ]
    }
}
