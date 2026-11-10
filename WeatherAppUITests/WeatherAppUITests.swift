//
//  WeatherAppUITests.swift
//  WeatherAppUITests
//
//  Created by Tina on 2026/11/9.
//

import XCTest

/// 端到端流程測試。啟動參數帶 `-UITestMode` 時，App 會把定位、天氣和城市搜尋換成固定結果的替身，
/// 因此這些測試不依賴模擬器的 GPS 或外網，可以重複執行。
@MainActor
final class WeatherAppUITests: XCTestCase {

    /// UI 測試 target 不連結 App 模組，識別碼只能複製一份。
    /// 這份清單必須與 App 的 `AccessibilityID` 保持一致；搬家時兩邊一起改。
    private enum ID {
        enum Weather {
            static let cityName = "weather.cityName"
            static let temperature = "weather.temperature"
            static let condition = "weather.condition"
            static let changeCity = "weather.changeCity"
            static let returnToCurrentLocation = "weather.returnToCurrentLocation"
            static func forecastRow(_ index: Int) -> String { "weather.forecastRow.\(index)" }
        }

        enum Search {
            static let results = "search.results"
            static let emptyState = "search.emptyState"
            static let retry = "search.retry"
            static func resultRow(_ index: Int) -> String { "search.result.\(index)" }
        }
    }

    private enum Launch {
        /// 每個測試從乾淨的狀態開始。
        static let fresh = ["-UITestMode"]
    }

    override func setUp() async throws {
        continueAfterFailure = false
    }

    // MARK: - 啟動與目前位置

    func testLaunchShowsCurrentLocationWeather() throws {
        let app = launch(Launch.fresh)

        let city = app.staticTexts[ID.Weather.cityName]
        XCTAssertTrue(city.waitForExistence(timeout: 10), "首頁沒有出現城市名稱")
        XCTAssertEqual(city.label, "Hong Kong")

        let temperature = app.staticTexts[ID.Weather.temperature]
        XCTAssertTrue(temperature.exists)
        XCTAssertEqual(temperature.label, "26°C", "應顯示替身定位城市目前的溫度")
        XCTAssertTrue(app.staticTexts[ID.Weather.condition].exists)
        // 正在顯示目前位置時，不需要「返回目前位置」。
        XCTAssertFalse(app.buttons[ID.Weather.returnToCurrentLocation].exists)
    }

    func testLaunchShowsSevenDayForecast() throws {
        let app = launch(Launch.fresh)
        XCTAssertTrue(app.staticTexts[ID.Weather.cityName].waitForExistence(timeout: 10))

        let firstDay = app.otherElements[ID.Weather.forecastRow(0)]
        XCTAssertTrue(firstDay.waitForExistence(timeout: 5), "沒有七日預報的第一行")
        XCTAssertTrue(firstDay.label.contains("Today") || firstDay.label.contains("今天"),
                      "第一行應該是今天，實際為：\(firstDay.label)")

        XCTAssertTrue(app.otherElements[ID.Weather.forecastRow(6)].exists, "七日預報應該有七行")
    }

    // MARK: - 搜尋與切換城市

    func testSearchingACityReplacesTheCurrentLocationWeather() throws {
        let app = launch(Launch.fresh)
        XCTAssertTrue(app.staticTexts[ID.Weather.cityName].waitForExistence(timeout: 10))

        selectTokyo(in: app)

        XCTAssertEqual(app.staticTexts[ID.Weather.temperature].label, "16°C",
                       "應顯示東京的天氣，而不是原本位置的")
        // 不在目前位置時，才提供返回目前位置。
        XCTAssertTrue(app.buttons[ID.Weather.returnToCurrentLocation].exists)
    }

    func testSearchWithNoMatchShowsEmptyStateInsteadOfError() throws {
        let app = launch(Launch.fresh)
        XCTAssertTrue(app.staticTexts[ID.Weather.cityName].waitForExistence(timeout: 10))

        openCitySearch(in: app)
        search(in: app, for: "zzzzz")

        let emptyState = app.staticTexts[ID.Search.emptyState]
        XCTAssertTrue(emptyState.waitForExistence(timeout: 5), "搜尋無結果時應顯示提示文字")
        // 「查無資料」不是請求失敗，不該出現重試按鈕。
        XCTAssertFalse(app.buttons[ID.Search.retry].exists, "查無資料不應視為請求失敗")
    }

    // MARK: - 返回目前位置

    func testReturningToCurrentLocationAfterSearchingACity() throws {
        let app = launch(Launch.fresh)
        XCTAssertTrue(app.staticTexts[ID.Weather.cityName].waitForExistence(timeout: 10))

        selectTokyo(in: app)

        let returnButton = app.buttons[ID.Weather.returnToCurrentLocation]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 5))
        returnButton.tap()

        let city = app.staticTexts[ID.Weather.cityName]
        XCTAssertTrue(waitForLabel("Hong Kong", on: city), "返回目前位置後標題沒有恢復，目前為：\(city.label)")
        XCTAssertFalse(returnButton.exists, "回到目前位置後不應再顯示返回按鈕")
    }

    // MARK: - Helpers

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        return app
    }

    private func openCitySearch(in app: XCUIApplication) {
        let changeCity = app.buttons[ID.Weather.changeCity]
        XCTAssertTrue(changeCity.waitForExistence(timeout: 5), "首頁沒有「切換城市」按鈕")
        changeCity.tap()
    }

    private func search(in app: XCUIApplication, for keyword: String) {
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5), "搜尋頁沒有出現搜尋框")
        field.tap()
        field.typeText(keyword)
    }

    private func selectTokyo(in app: XCUIApplication) {
        openCitySearch(in: app)
        search(in: app, for: "Tokyo")

        let result = app.tables[ID.Search.results].cells[ID.Search.resultRow(0)]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "搜尋 Tokyo 沒有結果")
        // Cell 本身不帶 label，城市名是它的子元素。
        XCTAssertTrue(result.staticTexts["Tokyo"].exists, "第一筆結果應該是 Tokyo")
        result.tap()

        let city = app.staticTexts[ID.Weather.cityName]
        XCTAssertTrue(waitForLabel("Tokyo", on: city), "切換城市後標題沒有更新，目前為：\(city.label)")
    }

    /// 狀態是透過回呼送到畫面，斷言前先等標籤變成預期值，避免讀到舊畫面。
    private func waitForLabel(_ expected: String, on element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
