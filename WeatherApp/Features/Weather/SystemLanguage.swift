//
//  SystemLanguage.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import Foundation

/// 系統語言只在這裡判斷一次。介面文案和 Geocoding API 都用這個結果。
enum SystemLanguage {
    static func openMeteoCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        let identifier = preferredLanguages.first ?? "en"
        let code = Locale(identifier: identifier).languageCode?.lowercased() ?? "en"
        guard code == "zh" else { return code }
        return prefersTraditionalChinese(identifier) ? "zh_tw" : "zh"
    }

    /// 對應 Resources 裡的 lproj 名稱。沒有翻譯的語言使用英文。
    static func localizationName(for locale: Locale) -> String {
        let code = locale.languageCode?.lowercased() ?? "en"
        guard code == "zh" else { return "en" }
        return prefersTraditionalChinese(locale.identifier) ? "zh-Hant" : "zh-Hans"
    }

    private static func prefersTraditionalChinese(_ identifier: String) -> Bool {
        let lowered = identifier.lowercased()
        return lowered.contains("hant")
            || lowered.contains("zh_tw")
            || lowered.contains("zh-tw")
            || lowered.contains("-tw")
            || lowered.contains("zh_hk")
            || lowered.contains("zh-hk")
            || lowered.contains("-hk")
            || lowered.contains("zh_mo")
            || lowered.contains("zh-mo")
            || lowered.contains("-mo")
    }
}
