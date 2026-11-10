//
//  DailyForecastRowView.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import UIKit

/// 七日預報的一行：星期、圖示、天氣描述、最低溫、最高溫。
final class DailyForecastRowView: UIView {
    private let dayLabel = UILabel()
    private let symbolView = UIImageView()
    private let conditionLabel = UILabel()
    private let lowLabel = UILabel()
    private let highLabel = UILabel()
    private let separator = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        day: String,
        symbolName: String,
        condition: String,
        low: String,
        high: String,
        showsSeparator: Bool
    ) {
        dayLabel.text = day
        symbolView.image = UIImage(systemName: symbolName)
        symbolView.accessibilityLabel = condition
        conditionLabel.text = condition
        lowLabel.text = low
        highLabel.text = high
        separator.isHidden = !showsSeparator
        // 一行對 VoiceOver 只讀一次完整資訊，不要讓使用者逐格聽五個碎片。
        accessibilityLabel = "\(day)，\(condition)，\(high) \(low)"
    }

    private func configure() {
        isAccessibilityElement = true
        dayLabel.font = .preferredFont(forTextStyle: .body)
        dayLabel.adjustsFontForContentSizeCategory = true
        dayLabel.textColor = .label

        symbolView.tintColor = .systemBlue
        symbolView.contentMode = .scaleAspectFit
        symbolView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .regular)

        conditionLabel.font = .preferredFont(forTextStyle: .subheadline)
        conditionLabel.adjustsFontForContentSizeCategory = true
        conditionLabel.textColor = .secondaryLabel
        conditionLabel.numberOfLines = 2
        conditionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        lowLabel.font = .preferredFont(forTextStyle: .body)
        lowLabel.adjustsFontForContentSizeCategory = true
        lowLabel.textColor = .secondaryLabel
        lowLabel.textAlignment = .right
        lowLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        highLabel.font = .preferredFont(forTextStyle: .body)
        highLabel.adjustsFontForContentSizeCategory = true
        highLabel.textColor = .label
        highLabel.textAlignment = .right
        highLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        separator.backgroundColor = .separator

        [dayLabel, symbolView, conditionLabel, lowLabel, highLabel, separator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            addSubview($0)
        }

        NSLayoutConstraint.activate([
            heightAnchor.constraint(greaterThanOrEqualToConstant: 52),

            dayLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            dayLabel.widthAnchor.constraint(equalToConstant: 92),

            symbolView.leadingAnchor.constraint(equalTo: dayLabel.trailingAnchor, constant: 8),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 28),
            symbolView.heightAnchor.constraint(equalToConstant: 28),

            conditionLabel.leadingAnchor.constraint(equalTo: symbolView.trailingAnchor, constant: 8),
            conditionLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            conditionLabel.trailingAnchor.constraint(lessThanOrEqualTo: lowLabel.leadingAnchor, constant: -8),

            highLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            highLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            highLabel.widthAnchor.constraint(equalToConstant: 64),

            lowLabel.trailingAnchor.constraint(equalTo: highLabel.leadingAnchor, constant: -12),
            lowLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            lowLabel.widthAnchor.constraint(equalToConstant: 64),

            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }
}
