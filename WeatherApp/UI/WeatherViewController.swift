import UIKit

final class WeatherViewController: UIViewController {
    private let viewModel = WeatherViewModel()

    private var snapshot: WeatherSnapshot?
    private var hourlyItems: [HourlyWeather] = []
    private var headerIconTask: Task<Void, Never>?

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.10, green: 0.22, blue: 0.46, alpha: 1.0).cgColor,
            UIColor(red: 0.20, green: 0.47, blue: 0.75, alpha: 1.0).cgColor,
            UIColor(red: 0.44, green: 0.71, blue: 0.91, alpha: 1.0).cgColor
        ]
        layer.startPoint = CGPoint(x: 0.1, y: 0.0)
        layer.endPoint = CGPoint(x: 0.9, y: 1.0)
        return layer
    }()

    private lazy var hourlyCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 10
        layout.itemSize = CGSize(width: 84, height: 116)

        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.showsHorizontalScrollIndicator = false
        collection.dataSource = self
        collection.register(HourlyWeatherCell.self, forCellWithReuseIdentifier: HourlyWeatherCell.reuseIdentifier)
        return collection
    }()

    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        return scrollView
    }()

    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 20
        return stack
    }()

    private let headerCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        view.layer.cornerRadius = 24
        view.layer.cornerCurve = .continuous
        return view
    }()

    private let cityLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()

    private let conditionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white.withAlphaComponent(0.9)
        return label
    }()

    private let headerIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.widthAnchor.constraint(equalToConstant: 32).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return imageView
    }()

    private let currentTemperatureLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 64, weight: .thin)
        label.textColor = .white
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

    private let hiLowLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white.withAlphaComponent(0.95)
        return label
    }()

    private let hourlyTitleLabel = WeatherViewController.makeSectionTitle("Почасовой прогноз")
    private let dailyTitleLabel = WeatherViewController.makeSectionTitle("Прогноз на 3 дня")

    private let dailyStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        return stack
    }()

    private let loadingStack: UIStackView = {
        let spinner = UIActivityIndicatorView(style: .large)
        spinner.startAnimating()

        let label = UILabel()
        label.text = "Загружаем погоду..."
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white

        let stack = UIStackView(arrangedSubviews: [spinner, label])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        return stack
    }()

    private let errorLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var retryButton: UIButton = {
        let button = UIButton(type: .system)

        var title = AttributedString("Повторить")
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        var configuration = UIButton.Configuration.filled()
        configuration.attributedTitle = title
        configuration.baseBackgroundColor = .white
        configuration.baseForegroundColor = UIColor(red: 0.16, green: 0.35, blue: 0.65, alpha: 1.0)
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 20, bottom: 10, trailing: 20)
        button.configuration = configuration

        button.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        return button
    }()

    private lazy var errorStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [errorLabel, retryButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 14
        return stack
    }()

    private let feelsLikeValueLabel = WeatherViewController.makeMetricValueLabel()
    private let humidityValueLabel = WeatherViewController.makeMetricValueLabel()
    private let windValueLabel = WeatherViewController.makeMetricValueLabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        bindViewModel()
        viewModel.start()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    deinit {
        headerIconTask?.cancel()
    }

    @objc
    private func retryTapped() {
        viewModel.retry()
    }

    private func bindViewModel() {
        viewModel.onStateChange = { [weak self] state in
            self?.render(state)
        }
    }

    private func render(_ state: WeatherViewModel.State) {
        switch state {
        case .loading:
            setVisibleState(content: false, loading: true, error: false)
        case .loaded(let snapshot):
            apply(snapshot: snapshot)
            setVisibleState(content: true, loading: false, error: false)
        case .error(let message):
            errorLabel.text = message
            setVisibleState(content: false, loading: false, error: true)
        }
    }

    private func apply(snapshot: WeatherSnapshot) {
        self.snapshot = snapshot
        self.hourlyItems = snapshot.hourly

        cityLabel.text = "\(snapshot.cityName), \(snapshot.country)"
        conditionLabel.text = snapshot.current.conditionText
        currentTemperatureLabel.text = WeatherFormatting.temperature(snapshot.current.temperatureC)
        hiLowLabel.text = "Макс: \(WeatherFormatting.temperature(snapshot.current.maxTempC))  Мин: \(WeatherFormatting.temperature(snapshot.current.minTempC))"

        feelsLikeValueLabel.text = WeatherFormatting.temperature(snapshot.current.feelsLikeC)
        humidityValueLabel.text = "\(snapshot.current.humidity)%"
        windValueLabel.text = "\(Int(snapshot.current.windKph.rounded())) км/ч"

        headerIconImageView.image = nil
        headerIconTask?.cancel()
        if let url = snapshot.current.conditionIconURL {
            headerIconTask = Task { [weak self] in
                let image = await ImageLoader.shared.image(for: url)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.headerIconImageView.image = image
                }
            }
        }

        hourlyCollectionView.reloadData()
        reloadDailyRows(snapshot.daily, timeZone: snapshot.timeZone)
    }

    private func reloadDailyRows(_ items: [DailyWeather], timeZone: TimeZone) {
        dailyStack.arrangedSubviews.forEach { view in
            dailyStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        for item in items {
            let row = DailyForecastRowView()
            row.configure(with: item, timeZone: timeZone)
            dailyStack.addArrangedSubview(row)
        }
    }

    private func setVisibleState(content: Bool, loading: Bool, error: Bool) {
        scrollView.isHidden = !content
        loadingStack.isHidden = !loading
        errorStack.isHidden = !error
    }

    private func configureUI() {
        view.layer.insertSublayer(gradientLayer, at: 0)

        setupScrollView()
        setupHeaderCard()

        contentStack.addArrangedSubview(headerCard)
        contentStack.addArrangedSubview(hourlyTitleLabel)
        contentStack.addArrangedSubview(hourlyCollectionView)
        contentStack.addArrangedSubview(dailyTitleLabel)
        contentStack.addArrangedSubview(dailyStack)

        headerCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 230).isActive = true
        hourlyCollectionView.heightAnchor.constraint(equalToConstant: 116).isActive = true

        view.addSubview(loadingStack)
        view.addSubview(errorStack)

        loadingStack.translatesAutoresizingMaskIntoConstraints = false
        errorStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            loadingStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            errorStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            errorStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            errorStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            errorStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24)
        ])

        setVisibleState(content: false, loading: true, error: false)
    }

    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        ])
    }

    private func setupHeaderCard() {
        let conditionStack = UIStackView(arrangedSubviews: [conditionLabel, headerIconImageView])
        conditionStack.axis = .horizontal
        conditionStack.spacing = 8
        conditionStack.alignment = .center

        let topStack = UIStackView(arrangedSubviews: [cityLabel, conditionStack])
        topStack.axis = .vertical
        topStack.spacing = 8

        let feelsLikeView = makeMetricCard(title: "Ощущается", valueLabel: feelsLikeValueLabel)
        let humidityView = makeMetricCard(title: "Влажность", valueLabel: humidityValueLabel)
        let windView = makeMetricCard(title: "Ветер", valueLabel: windValueLabel)

        let metricsStack = UIStackView(arrangedSubviews: [feelsLikeView, humidityView, windView])
        metricsStack.axis = .horizontal
        metricsStack.spacing = 8
        metricsStack.distribution = .fillEqually

        let content = UIStackView(arrangedSubviews: [topStack, currentTemperatureLabel, hiLowLabel, metricsStack])
        content.axis = .vertical
        content.spacing = 14

        headerCard.addSubview(content)
        content.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: headerCard.topAnchor, constant: 18),
            content.leadingAnchor.constraint(equalTo: headerCard.leadingAnchor, constant: 18),
            content.trailingAnchor.constraint(equalTo: headerCard.trailingAnchor, constant: -18),
            content.bottomAnchor.constraint(equalTo: headerCard.bottomAnchor, constant: -18)
        ])
    }

    private func makeMetricCard(title: String, valueLabel: UILabel) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = .white.withAlphaComponent(0.75)
        titleLabel.textAlignment = .center

        let stack = UIStackView(arrangedSubviews: [valueLabel, titleLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 4

        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        card.layer.cornerRadius = 12
        card.layer.cornerCurve = .continuous

        card.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -8),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])

        return card
    }

    private static func makeSectionTitle(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .white
        return label
    }

    private static func makeMetricValueLabel() -> UILabel {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }
}

extension WeatherViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        hourlyItems.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: HourlyWeatherCell.reuseIdentifier,
                for: indexPath
            ) as? HourlyWeatherCell
        else {
            return UICollectionViewCell()
        }

        let item = hourlyItems[indexPath.item]
        let referenceDate = snapshot?.currentDate ?? Date()
        let timeZone = snapshot?.timeZone ?? .current
        cell.configure(item: item, referenceDate: referenceDate, timeZone: timeZone)
        return cell
    }
}
