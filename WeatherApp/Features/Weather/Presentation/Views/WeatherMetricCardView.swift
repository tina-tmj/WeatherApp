//
//  WeatherMetricCardView.swift
//  WeatherApp
//
//  Created by Tina on 2026/11/9.
//

import UIKit

/// 濕度、風速、降雨量那一張小卡片。數值由外面傳入，這裡不計算。
final class WeatherMetricCardView: UIView {
    private let imageView = UIImageView()
    private let valueLabel = UILabel()
    private let titleLabel = UILabel()
    private let title: String

    init(symbolName: String, title: String) {
        self.title = title
        super.init(frame: .zero)
        configure(symbolName: symbolName, title: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setValue(_ value: String) {
        valueLabel.text = value
        // 卡片對 VoiceOver 只是一個元素，讀出來是「濕度，72%」，而不是三個互不相關的片段。
        accessibilityLabel = "\(title)，\(value)"
    }

    private func configure(symbolName: String, title: String) {
        isAccessibilityElement = true
        accessibilityLabel = title
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 16
        layer.cornerCurve = .continuous

        imageView.image = UIImage(systemName: symbolName)
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)

        valueLabel.font = .preferredFont(forTextStyle: .title3)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.textColor = .label
        valueLabel.textAlignment = .center
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.7

        titleLabel.font = .preferredFont(forTextStyle: .caption1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .secondaryLabel
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.text = title

        let stack = UIStackView(arrangedSubviews: [imageView, valueLabel, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            imageView.heightAnchor.constraint(equalToConstant: 24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -14)
        ])
    }
}
