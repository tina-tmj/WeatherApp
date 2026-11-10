//
//  L10n.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 從 Localizable.strings 取介面文字。領域模型不呼叫這裡。
enum L10n {
    enum Key: String {
        case weather
        case change
        case changeCity
        case returnToCurrentLocation
        case sevenDayForecast
        case humidity
        case wind
        case precipitation
        case feelsLikeFormat
        case retry
        case searchCity
        case openSettings
        case today
        case cities
        case searchCitiesPlaceholder
        case searchForACity
        case noMatchingCities
        case locationDenied
        case locationServicesDisabled
        case locationFailed
        case currentLocation
        case requestTimeout
        case networkFailed
        case serverFailed
        case unreadableData
        case requestFailed
        case clear
        case mainlyClear
        case partlyCloudy
        case overcast
        case fog
        case drizzle
        case rain
        case snow
        case thunderstorm
        case unknown
    }

    static func text(_ key: Key, locale: Locale = .current) -> String {
        localized(key.rawValue, locale: locale)
    }

    static func condition(_ condition: WeatherCondition, locale: Locale = .current) -> String {
        let key: Key
        switch condition {
        case .clear: key = .clear
        case .mainlyClear: key = .mainlyClear
        case .partlyCloudy: key = .partlyCloudy
        case .overcast: key = .overcast
        case .fog: key = .fog
        case .drizzle: key = .drizzle
        case .rain: key = .rain
        case .snow: key = .snow
        case .thunderstorm: key = .thunderstorm
        case .unknown: key = .unknown
        }
        return text(key, locale: locale)
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        let folder = SystemLanguage.localizationName(for: locale)
        let bundle = bundle(forFolder: folder) ?? bundle(forFolder: "en") ?? Bundle(for: BundleToken.self)
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func bundle(forFolder name: String) -> Bundle? {
        guard let path = Bundle(for: BundleToken.self).path(forResource: name, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }
}

private final class BundleToken {}
