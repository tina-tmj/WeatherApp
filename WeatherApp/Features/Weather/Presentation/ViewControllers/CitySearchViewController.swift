//
//  CitySearchViewController.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import UIKit

/// 城市搜尋頁。輸入交給 CitySearchViewModel，選中城市後由 SceneDelegate 帶回首頁。
final class CitySearchViewController: UIViewController {
    private let viewModel: CitySearchViewModel
    var onLocationSelected: ((Location) -> Void)?

    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let backgroundContainer = UIView()
    private let emptyLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let retryButton = UIButton(configuration: .plain())
    private var queryTask: Task<Void, Never>?
    private var locations: [Location] = []

    init(viewModel: CitySearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.text(.cities)
        view.backgroundColor = .systemGroupedBackground
        configureSearch()
        configureTable()
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(viewModel.state)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isMovingFromParent || isBeingDismissed else { return }
        queryTask?.cancel()
        viewModel.cancel()
    }

    private func configureSearch() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.placeholder = L10n.text(.searchCitiesPlaceholder)
        searchController.searchBar.autocapitalizationType = .words
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func configureTable() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.accessibilityIdentifier = AccessibilityID.CitySearch.results
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "CityCell")
        view.addSubview(tableView)

        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.accessibilityIdentifier = AccessibilityID.CitySearch.emptyState
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        backgroundContainer.addSubview(emptyLabel)

        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.accessibilityIdentifier = AccessibilityID.CitySearch.loading
        backgroundContainer.addSubview(loadingIndicator)

        var retryConfiguration = UIButton.Configuration.plain()
        retryConfiguration.title = L10n.text(.retry)
        retryButton.configuration = retryConfiguration
        retryButton.translatesAutoresizingMaskIntoConstraints = false
        retryButton.accessibilityIdentifier = AccessibilityID.CitySearch.retry
        retryButton.isHidden = true
        retryButton.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.queryTask?.cancel()
            self.queryTask = Task { [weak self] in
                await self?.viewModel.retry()
            }
        }, for: .touchUpInside)
        backgroundContainer.addSubview(retryButton)
        tableView.backgroundView = backgroundContainer

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: backgroundContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: backgroundContainer.centerYAnchor, constant: -40),
            emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backgroundContainer.leadingAnchor, constant: 24),
            emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: backgroundContainer.trailingAnchor, constant: -24),

            loadingIndicator.centerXAnchor.constraint(equalTo: backgroundContainer.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: backgroundContainer.centerYAnchor, constant: -40),

            retryButton.topAnchor.constraint(equalTo: emptyLabel.bottomAnchor, constant: 12),
            retryButton.centerXAnchor.constraint(equalTo: backgroundContainer.centerXAnchor)
        ])
    }

    private func render(_ state: CitySearchViewState) {
        switch state {
        case .idle:
            locations = []
            loadingIndicator.stopAnimating()
            retryButton.isHidden = true
            emptyLabel.text = L10n.text(.searchForACity)
            emptyLabel.isHidden = false
        case .loading:
            locations = []
            emptyLabel.isHidden = true
            retryButton.isHidden = true
            loadingIndicator.startAnimating()
        case .empty:
            locations = []
            loadingIndicator.stopAnimating()
            retryButton.isHidden = true
            emptyLabel.text = L10n.text(.noMatchingCities)
            emptyLabel.isHidden = false
        case let .results(locations):
            self.locations = locations
            loadingIndicator.stopAnimating()
            retryButton.isHidden = true
            emptyLabel.isHidden = true
        case let .error(message):
            locations = []
            loadingIndicator.stopAnimating()
            emptyLabel.text = message
            emptyLabel.isHidden = false
            retryButton.isHidden = false
        }
        tableView.reloadData()
    }
}

extension CitySearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        let query = searchController.searchBar.text ?? ""
        queryTask?.cancel()
        queryTask = Task { [weak self] in
            guard !Task.isCancelled else { return }
            await self?.viewModel.updateQuery(query)
        }
    }
}

extension CitySearchViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        locations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CityCell", for: indexPath)
        let location = locations[indexPath.row]
        var content = UIListContentConfiguration.subtitleCell()
        content.text = location.name
        content.secondaryText = location.country
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        cell.accessibilityIdentifier = AccessibilityID.CitySearch.resultRow(indexPath.row)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard locations.indices.contains(indexPath.row) else { return }
        onLocationSelected?(locations[indexPath.row])
    }
}
