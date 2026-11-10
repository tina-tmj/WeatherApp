//
//  WeatherCondition.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 畫面使用的天氣狀況。數值來自 Open-Meteo 的 WMO 天氣代碼，相近代碼會合併成同一種。
enum WeatherCondition: Equatable, Sendable {
    case clear
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case rain
    case snow
    case thunderstorm
    case unknown(code: Int)

    // MARK: - WMO Weather Code

    /// 把 WMO 代碼收成畫面用的分類。
    /// 霧含霧凇，毛毛雨含凍毛毛雨，雨含陣雨和凍雨，雪含雪粒和陣雪，雷雨含冰雹。
    init(weatherCode: Int) {
        switch weatherCode {
        case 0:
            self = .clear
        case 1:
            self = .mainlyClear
        case 2:
            self = .partlyCloudy
        case 3:
            self = .overcast
        case 45, 48:
            self = .fog
        case 51, 53, 55, 56, 57:
            self = .drizzle
        case 61, 63, 65, 66, 67, 80, 81, 82:
            self = .rain
        case 71, 73, 75, 77, 85, 86:
            self = .snow
        case 95, 96, 97, 99:
            self = .thunderstorm
        default:
            self = .unknown(code: weatherCode)
        }
    }

    // MARK: - Presentation

    /// SF Symbol 名稱。留成字串，領域模型就不需要依賴 UIKit，也不負責翻譯。
    var symbolName: String {
        switch self {
        case .clear:
            return "sun.max"
        case .mainlyClear:
            return "sun.min"
        case .partlyCloudy:
            return "cloud.sun"
        case .overcast:
            return "cloud"
        case .fog:
            return "cloud.fog"
        case .drizzle:
            return "cloud.drizzle"
        case .rain:
            return "cloud.rain"
        case .snow:
            return "cloud.snow"
        case .thunderstorm:
            return "cloud.bolt"
        case .unknown:
            return "questionmark"
        }
    }
}
