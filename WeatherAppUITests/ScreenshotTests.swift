//
//  ScreenshotTests.swift
//  WeatherAppUITests
//
//  Created by Tina on 2026/11/9.
//

import XCTest

/// 只負責產生 README 用的截圖，不做斷言。用 `-PreviewCoordinates` 固定座標，
/// 但天氣與反查走真實 Open-Meteo API，讓文件上的畫面是真實資料。
/// 這個類別需要網路；其餘 UI 測試仍走 `-UITestMode` 的替身，離線可跑。執行方式：
/// `xcodebuild test -only-testing:WeatherAppUITests/ScreenshotTests`
final class ScreenshotTests: XCTestCase {

    /// 香港座標，只當作「目前位置」的來源；畫面上的資料是真實 API 回的。
    private static let hongKongCoordinates = "22.3193,114.1694"

    @MainActor
    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-PreviewCoordinates", Self.hongKongCoordinates]
        app.launch()

        // 真實 API 需要網路往返，等待時間放寬。
        XCTAssertTrue(app.staticTexts["weather.cityName"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.otherElements["weather.forecastRow.2"].waitForExistence(timeout: 20))
        XCTAssertTrue(waitForTemperature(app), "溫度遲遲沒有載出數值")
        capture(app, name: "01-current-weather")

        app.buttons["weather.changeCity"].tap()
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Tok")

        let result = app.tables["search.results"].cells["search.result.0"]
        XCTAssertTrue(result.waitForExistence(timeout: 20))
        capture(app, name: "02-city-search")

        result.tap()
        XCTAssertTrue(app.staticTexts["weather.cityName"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.otherElements["weather.forecastRow.2"].waitForExistence(timeout: 20))
        XCTAssertTrue(waitForTemperature(app), "切換城市後溫度沒有載出數值")
        capture(app, name: "03-searched-city")

        app.buttons["weather.changeCity"].tap()
        let emptyField = app.searchFields.firstMatch
        XCTAssertTrue(emptyField.waitForExistence(timeout: 5))
        emptyField.tap()
        emptyField.typeText("zzzzz")
        XCTAssertTrue(app.staticTexts["search.emptyState"].waitForExistence(timeout: 20))
        capture(app, name: "04-empty-search")
    }

    // MARK: - Helpers

    /// 溫度標籤已載出「數值 + °C」的格式（真實資料無法預先知道數字）。
    @MainActor
    private func waitForTemperature(_ app: XCUIApplication) -> Bool {
        let element = app.staticTexts["weather.temperature"]
        let predicate = NSPredicate(format: "label MATCHES %@", "^-?\\d+(\\.\\d)?°C$")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: 20) == .completed
    }

    @MainActor
    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
