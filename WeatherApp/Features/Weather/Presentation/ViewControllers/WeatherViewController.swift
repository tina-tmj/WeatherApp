//
//  WeatherViewController.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import UIKit

/// 首頁。只排版、把按鈕事件交給 ViewModel，並依 state 切換載入、內容和錯誤。
/// 定位與網路都不寫在這個類別裡。
final class WeatherViewController: UIViewController {
    private let viewModel: WeatherViewModel
    var onChangeCity: (() -> Void)?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let cityLabel = UILabel()
    private let changeCityButton = UIButton(configuration: .gray())
    private let returnToCurrentButton = UIButton(configuration: .plain())
    private let symbolView = UIImageView()
    private let temperatureLabel = UILabel()
    private let conditionLabel = UILabel()
    private let feelsLikeLabel = UILabel()
    private let humidityCard = WeatherMetricCardView(symbolName: "humidity", title: L10n.text(.humidity))
    private let windCard = WeatherMetricCardView(symbolName: "wind", title: L10n.text(.wind))
    private let precipitationCard = WeatherMetricCardView(symbolName: "drop.fill", title: L10n.text(.precipitation))
    private let forecastStack = UIStackView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    private let errorStack = UIStackView()
    private let errorLabel = UILabel()
    private let retryButton = UIButton(configuration: .filled())
    private let searchCityButton = UIButton(configuration: .gray())
    private let settingsButton = UIButton(configuration: .plain())

    init(viewModel: WeatherViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text(.weather)
        view.backgroundColor = .systemBackground
        configureHierarchy()
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(viewModel.state)
        Task { [weak self] in
            await self?.viewModel.loadInitialContent()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    private func configureHierarchy() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(makeHeader())
        contentStack.addArrangedSubview(makeHero())
        contentStack.addArrangedSubview(makeMetrics())
        contentStack.addArrangedSubview(makeForecastSection())

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.accessibilityIdentifier = AccessibilityID.Weather.loading
        view.addSubview(loadingIndicator)

        configureErrorView()

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 12),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40),

            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            errorStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }

    private func makeHeader() -> UIView {
        cityLabel.font = .systemFont(ofSize: 34, weight: .bold)
        cityLabel.adjustsFontForContentSizeCategory = true
        cityLabel.textColor = .label
        cityLabel.numberOfLines = 2
        cityLabel.accessibilityIdentifier = AccessibilityID.Weather.cityName
        cityLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        var configuration = UIButton.Configuration.gray()
        configuration.title = L10n.text(.change)
        configuration.image = UIImage(systemName: "magnifyingglass")
        configuration.imagePadding = 6
        configuration.cornerStyle = .capsule
        changeCityButton.configuration = configuration
        changeCityButton.accessibilityLabel = L10n.text(.changeCity)
        changeCityButton.accessibilityIdentifier = AccessibilityID.Weather.changeCity
        changeCityButton.setContentCompressionResistancePriority(.required, for: .horizontal)
        changeCityButton.addAction(UIAction { [weak self] _ in
            self?.onChangeCity?()
        }, for: .touchUpInside)

        var returnConfiguration = UIButton.Configuration.plain()
        returnConfiguration.title = L10n.text(.returnToCurrentLocation)
        returnConfiguration.image = UIImage(systemName: "location")
        returnConfiguration.imagePadding = 6
        returnToCurrentButton.configuration = returnConfiguration
        returnToCurrentButton.accessibilityIdentifier = AccessibilityID.Weather.returnToCurrentLocation
        returnToCurrentButton.isHidden = true
        returnToCurrentButton.contentHorizontalAlignment = .leading
        returnToCurrentButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.returnToCurrentLocation() }
        }, for: .touchUpInside)

        let titleRow = UIStackView(arrangedSubviews: [cityLabel, changeCityButton])
        titleRow.axis = .horizontal
        titleRow.alignment = .center
        titleRow.spacing = 12

        let header = UIStackView(arrangedSubviews: [titleRow, returnToCurrentButton])
        header.axis = .vertical
        header.alignment = .fill
        header.spacing = 4
        return header
    }

    private func makeHero() -> UIView {
        symbolView.contentMode = .scaleAspectFit
        symbolView.tintColor = .systemBlue
        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)

        temperatureLabel.font = .systemFont(ofSize: 96, weight: .thin)
        temperatureLabel.textColor = .label
        temperatureLabel.textAlignment = .center
        temperatureLabel.adjustsFontSizeToFitWidth = true
        temperatureLabel.minimumScaleFactor = 0.4
        temperatureLabel.accessibilityIdentifier = AccessibilityID.Weather.temperature

        conditionLabel.font = .preferredFont(forTextStyle: .title2)
        conditionLabel.adjustsFontForContentSizeCategory = true
        conditionLabel.textColor = .secondaryLabel
        conditionLabel.textAlignment = .center
        conditionLabel.numberOfLines = 0
        conditionLabel.accessibilityIdentifier = AccessibilityID.Weather.condition

        feelsLikeLabel.font = .preferredFont(forTextStyle: .title3)
        feelsLikeLabel.adjustsFontForContentSizeCategory = true
        feelsLikeLabel.textColor = .secondaryLabel
        feelsLikeLabel.textAlignment = .center

        let hero = UIStackView(arrangedSubviews: [symbolView, temperatureLabel, conditionLabel, feelsLikeLabel])
        hero.axis = .vertical
        hero.alignment = .center
        hero.spacing = 4
        hero.setCustomSpacing(12, after: symbolView)
        symbolView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        return hero
    }

    private func makeMetrics() -> UIView {
        humidityCard.accessibilityIdentifier = AccessibilityID.Weather.humidity
        windCard.accessibilityIdentifier = AccessibilityID.Weather.wind
        precipitationCard.accessibilityIdentifier = AccessibilityID.Weather.precipitation

        let metrics = UIStackView(arrangedSubviews: [humidityCard, windCard, precipitationCard])
        metrics.axis = .horizontal
        metrics.distribution = .fillEqually
        metrics.spacing = 12
        metrics.heightAnchor.constraint(greaterThanOrEqualToConstant: 112).isActive = true
        return metrics
    }

    private func makeForecastSection() -> UIView {
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title3)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .label
        titleLabel.text = L10n.text(.sevenDayForecast)

        forecastStack.axis = .vertical
        forecastStack.spacing = 0
        forecastStack.accessibilityIdentifier = AccessibilityID.Weather.forecastList

        let section = UIStackView(arrangedSubviews: [titleLabel, forecastStack])
        section.axis = .vertical
        section.spacing = 8
        return section
    }

    private func configureErrorView() {
        let imageView = UIImageView(image: UIImage(systemName: "exclamationmark.triangle"))
        imageView.tintColor = .systemOrange
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 36, weight: .regular)

        errorLabel.font = .preferredFont(forTextStyle: .body)
        errorLabel.adjustsFontForContentSizeCategory = true
        errorLabel.textColor = .secondaryLabel
        errorLabel.textAlignment = .center
        errorLabel.numberOfLines = 0
        errorLabel.accessibilityIdentifier = AccessibilityID.Weather.errorMessage

        var retryConfiguration = UIButton.Configuration.filled()
        retryConfiguration.title = L10n.text(.retry)
        retryConfiguration.cornerStyle = .capsule
        retryButton.configuration = retryConfiguration
        retryButton.accessibilityIdentifier = AccessibilityID.Weather.retry
        retryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            Task { await self.viewModel.retry() }
        }, for: .touchUpInside)

        var searchConfiguration = UIButton.Configuration.gray()
        searchConfiguration.title = L10n.text(.searchCity)
        searchConfiguration.cornerStyle = .capsule
        searchCityButton.configuration = searchConfiguration
        searchCityButton.addAction(UIAction { [weak self] _ in
            self?.onChangeCity?()
        }, for: .touchUpInside)

        var settingsConfiguration = UIButton.Configuration.plain()
        settingsConfiguration.title = L10n.text(.openSettings)
        settingsButton.configuration = settingsConfiguration
        settingsButton.accessibilityIdentifier = AccessibilityID.Weather.openSettings
        settingsButton.addAction(UIAction { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            UIApplication.shared.open(url)
        }, for: .touchUpInside)

        errorStack.axis = .vertical
        errorStack.alignment = .center
        errorStack.spacing = 16
        errorStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.addArrangedSubview(imageView)
        errorStack.addArrangedSubview(errorLabel)
        errorStack.addArrangedSubview(retryButton)
        errorStack.addArrangedSubview(searchCityButton)
        errorStack.addArrangedSubview(settingsButton)
        view.addSubview(errorStack)
    }

    private func render(_ state: WeatherViewState) {
        cityLabel.text = viewModel.displayName
        returnToCurrentButton.isHidden = !viewModel.canReturnToCurrentLocation

        switch state {
        case .idle:
            scrollView.isHidden = true
            errorStack.isHidden = true
            loadingIndicator.stopAnimating()
        case .loading:
            scrollView.isHidden = true
            errorStack.isHidden = true
            loadingIndicator.startAnimating()
        case let .loaded(result):
            loadingIndicator.stopAnimating()
            errorStack.isHidden = true
            scrollView.isHidden = false
            apply(result)
        case let .error(message):
            showStatus(
                message: message,
                showsRetry: true,
                showsSettings: false
            )
        case let .locationUnavailable(problem):
            showStatus(
                message: message(for: problem),
                showsRetry: problem == .failed,
                showsSettings: problem == .denied || problem == .servicesDisabled
            )
        }
    }

    private func showStatus(message: String, showsRetry: Bool, showsSettings: Bool) {
        loadingIndicator.stopAnimating()
        scrollView.isHidden = true
        errorStack.isHidden = false
        errorLabel.text = message
        retryButton.isHidden = !showsRetry
        searchCityButton.isHidden = false
        settingsButton.isHidden = !showsSettings
    }

    private func message(for problem: LocationProblem) -> String {
        switch problem {
        case .denied:
            return L10n.text(.locationDenied)
        case .servicesDisabled:
            return L10n.text(.locationServicesDisabled)
        case .failed:
            return L10n.text(.locationFailed)
        }
    }

    private func apply(_ result: WeatherResult) {
        let current = result.currentWeather
        symbolView.image = UIImage(systemName: current.weatherCondition.symbolName)
        temperatureLabel.text = temperatureText(current.temperature)
        conditionLabel.text = L10n.condition(current.weatherCondition)
        feelsLikeLabel.text = String(
            format: L10n.text(.feelsLikeFormat),
            temperatureText(current.apparentTemperature)
        )
        humidityCard.setValue("\(current.humidity)%")
        windCard.setValue(windText(current.windSpeed))
        precipitationCard.setValue(precipitationText(current.precipitation))

        forecastStack.arrangedSubviews.forEach { view in
            forecastStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let forecasts = result.dailyForecasts
        for (index, forecast) in forecasts.enumerated() {
            let row = DailyForecastRowView()
            row.accessibilityIdentifier = AccessibilityID.Weather.forecastRow(index)
            row.configure(
                day: dayText(for: forecast, timeZone: result.timeZone),
                symbolName: forecast.weatherCondition.symbolName,
                condition: L10n.condition(forecast.weatherCondition),
                low: temperatureText(forecast.minTemperature),
                high: temperatureText(forecast.maxTemperature),
                showsSeparator: index < forecasts.count - 1
            )
            forecastStack.addArrangedSubview(row)
        }
    }

    private func temperatureText(_ value: Double) -> String {
        "\(Int(value.rounded()))°C"
    }

    private func windText(_ value: Double) -> String {
        "\(Int(value.rounded())) km/h"
    }

    private func precipitationText(_ value: Double) -> String {
        value == 0 ? "0 mm" : String(format: "%.1f mm", value)
    }

    private func dayText(for forecast: DailyForecast, timeZone: TimeZone) -> String {
        if forecast.isSameDay(as: Date(), in: timeZone) {
            return L10n.text(.today)
        }
        return forecast.weekdayText(locale: .current, timeZone: timeZone)
    }
}
