import UIKit

final class DailyForecastRowView: UIView {
    private let dayLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        return label
    }()

    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 1
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let minMaxLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.textAlignment = .right
        return label
    }()

    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        iconTask?.cancel()
    }

    func configure(with item: DailyWeather, timeZone: TimeZone) {
        dayLabel.text = WeatherFormatting.dayString(from: item.date, timeZone: timeZone)
        conditionLabel.text = item.conditionText
        minMaxLabel.text = "\(WeatherFormatting.temperature(item.minTempC)) / \(WeatherFormatting.temperature(item.maxTempC))"

        iconTask?.cancel()
        iconImageView.image = nil

        if let url = item.conditionIconURL {
            iconTask = Task { [weak self] in
                let image = await ImageLoader.shared.image(for: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.iconImageView.image = image
                }
            }
        }
    }

    private func setup() {
        backgroundColor = UIColor.white.withAlphaComponent(0.12)
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous

        let leftStack = UIStackView(arrangedSubviews: [dayLabel, conditionLabel])
        leftStack.axis = .vertical
        leftStack.spacing = 4
        leftStack.alignment = .leading

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.widthAnchor.constraint(equalToConstant: 28).isActive = true
        iconImageView.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let rootStack = UIStackView(arrangedSubviews: [leftStack, iconImageView, minMaxLabel])
        rootStack.axis = .horizontal
        rootStack.alignment = .center
        rootStack.spacing = 12

        addSubview(rootStack)
        rootStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            rootStack.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            rootStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            rootStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            rootStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])

        minMaxLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
    }
}
