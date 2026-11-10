//
//  SceneDelegate.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import UIKit

/// 建立視窗、首頁和城市搜尋。畫面跳轉留在這裡，ViewController 不自己建立下一頁。
/// 依賴由 AppEnvironment 提供，這裡不決定要用哪一個 Repository 實作。
@MainActor
final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let environment = AppEnvironment.resolve()
        let window = UIWindow(windowScene: windowScene)
        let navigationController = UINavigationController()
        let viewModel = WeatherViewModel(
            repository: environment.weatherRepository,
            locationService: environment.locationService,
            placeResolver: environment.placeResolver
        )
        let rootViewController = WeatherViewController(viewModel: viewModel)
        rootViewController.onChangeCity = { [weak self, weak rootViewController] in
            guard let self, let rootViewController else { return }
            self.showCitySearch(
                from: rootViewController,
                weatherViewModel: viewModel,
                geocodingRepository: environment.geocodingRepository
            )
        }

        navigationController.setViewControllers([rootViewController], animated: false)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
    }

    private func showCitySearch(
        from source: UIViewController,
        weatherViewModel: WeatherViewModel,
        geocodingRepository: GeocodingRepositoryProtocol
    ) {
        let searchViewModel = CitySearchViewModel(repository: geocodingRepository)
        let searchViewController = CitySearchViewController(viewModel: searchViewModel)
        searchViewController.onLocationSelected = { [weak source, weak weatherViewModel] location in
            guard let weatherViewModel else { return }
            Task { @MainActor in
                await weatherViewModel.select(location)
                source?.navigationController?.popViewController(animated: true)
            }
        }
        source.navigationController?.pushViewController(searchViewController, animated: true)
    }
}
