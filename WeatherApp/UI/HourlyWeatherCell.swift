import UIKit

final class HourlyWeatherCell: UICollectionViewCell {
    static let reuseIdentifier = "HourlyWeatherCell"

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.9)
        label.textAlignment = .center
        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        return imageView
    }()

    private let temperatureLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private var iconTask: Task<Void, Never>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        iconTask?.cancel()
        iconTask = nil
        iconImageView.image = nil
        timeLabel.text = nil
        temperatureLabel.text = nil
    }

    func configure(item: HourlyWeather, referenceDate: Date, timeZone: TimeZone) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        if calendar.isDate(item.date, equalTo: referenceDate, toGranularity: .hour) {
            timeLabel.text = "Сейчас"
        } else {
            timeLabel.text = WeatherFormatting.hourString(from: item.date, timeZone: timeZone)
        }

        temperatureLabel.text = WeatherFormatting.temperature(item.temperatureC)

        iconTask?.cancel()
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

    private func configureUI() {
        contentView.backgroundColor = UIColor.white.withAlphaComponent(0.15)
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous

        let stack = UIStackView(arrangedSubviews: [timeLabel, iconImageView, temperatureLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.alignment = .fill

        iconImageView.heightAnchor.constraint(equalToConstant: 34).isActive = true

        contentView.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
}
