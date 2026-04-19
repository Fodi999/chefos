//
//  RegionService.swift
//  ChefOS
//

import Foundation
import SwiftUI
import Combine

// MARK: - Services/Region

final class RegionService: ObservableObject {
    @Published var countryCode: String
    @Published var currency: String
    @Published var countryFlag: String
    @Published var countryName: String

    static let shared = RegionService()

    struct Country: Identifiable, Hashable {
        var id: String { code }
        let code: String
        let name: String
        let flag: String
        let currency: String
        let currencySymbol: String
    }

    static let supportedCountries: [Country] = [
        .init(code: "PL", name: "Poland", flag: "🇵🇱", currency: "PLN", currencySymbol: "zł"),
        .init(code: "DE", name: "Germany", flag: "🇩🇪", currency: "EUR", currencySymbol: "€"),
        .init(code: "FR", name: "France", flag: "🇫🇷", currency: "EUR", currencySymbol: "€"),
        .init(code: "IT", name: "Italy", flag: "🇮🇹", currency: "EUR", currencySymbol: "€"),
        .init(code: "ES", name: "Spain", flag: "🇪🇸", currency: "EUR", currencySymbol: "€"),
        .init(code: "NL", name: "Netherlands", flag: "🇳🇱", currency: "EUR", currencySymbol: "€"),
        .init(code: "UA", name: "Ukraine", flag: "🇺🇦", currency: "UAH", currencySymbol: "₴"),
        .init(code: "GB", name: "United Kingdom", flag: "🇬🇧", currency: "GBP", currencySymbol: "£"),
        .init(code: "US", name: "United States", flag: "🇺🇸", currency: "USD", currencySymbol: "$"),
        .init(code: "CA", name: "Canada", flag: "🇨🇦", currency: "CAD", currencySymbol: "$"),
        .init(code: "AU", name: "Australia", flag: "🇦🇺", currency: "AUD", currencySymbol: "$"),
        .init(code: "JP", name: "Japan", flag: "🇯🇵", currency: "JPY", currencySymbol: "¥"),
        .init(code: "KR", name: "South Korea", flag: "🇰🇷", currency: "KRW", currencySymbol: "₩"),
        .init(code: "BR", name: "Brazil", flag: "🇧🇷", currency: "BRL", currencySymbol: "R$"),
        .init(code: "CZ", name: "Czech Republic", flag: "🇨🇿", currency: "CZK", currencySymbol: "Kč"),
        .init(code: "SE", name: "Sweden", flag: "🇸🇪", currency: "SEK", currencySymbol: "kr"),
        .init(code: "CH", name: "Switzerland", flag: "🇨🇭", currency: "CHF", currencySymbol: "Fr"),
        .init(code: "TR", name: "Turkey", flag: "🇹🇷", currency: "TRY", currencySymbol: "₺"),
        .init(code: "IN", name: "India", flag: "🇮🇳", currency: "INR", currencySymbol: "₹"),
        .init(code: "RU", name: "Russia", flag: "🇷🇺", currency: "RUB", currencySymbol: "₽"),
    ].sorted { $0.name < $1.name }

    init() {
        let saved = UserDefaults.standard.string(forKey: "chefos_country")
        let detected = saved ?? (Locale.current.region?.identifier ?? "US")
        let country = RegionService.findCountry(detected)
        self.countryCode = country.code
        self.currency = country.currencySymbol
        self.countryFlag = country.flag
        self.countryName = country.name
    }

    static func findCountry(_ code: String) -> Country {
        supportedCountries.first { $0.code == code }
            ?? .init(code: code, name: code, flag: "🏳️", currency: "USD", currencySymbol: "$")
    }

    static func autoDetectedCountry() -> Country {
        let code = Locale.current.region?.identifier ?? "US"
        return findCountry(code)
    }

    func setCountry(_ country: Country) {
        countryCode = country.code
        currency = country.currencySymbol
        countryFlag = country.flag
        countryName = country.name
        UserDefaults.standard.set(country.code, forKey: "chefos_country")
    }

    /// Format a price with the current currency symbol
    func formatPrice(_ value: Double) -> String {
        if value == 0 { return "0 \(currency)" }
        if value < 1 { return String(format: "%.2f \(currency)", value) }
        return String(format: "%.2f \(currency)", value)
    }

    func formatPriceShort(_ value: Double) -> String {
        if value == 0 { return "0 \(currency)" }
        return String(format: "%.0f \(currency)", value)
    }
}
