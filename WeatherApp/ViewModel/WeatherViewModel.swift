import CoreLocation
import Foundation

@MainActor
final class WeatherViewModel {
    enum State {
        case loading
        case loaded(WeatherSnapshot)
        case error(String)
    }

    var onStateChange: ((State) -> Void)?

    private let weatherClient: WeatherAPIClientProtocol
    private let locationService: LocationServiceProtocol
    private var coordinate: CLLocationCoordinate2D?
    private var loadingTask: Task<Void, Never>?

    init(
        weatherClient: WeatherAPIClientProtocol = WeatherAPIClient(),
        locationService: LocationServiceProtocol = LocationService()
    ) {
        self.weatherClient = weatherClient
        self.locationService = locationService
    }

    deinit {
        loadingTask?.cancel()
    }

    func start() {
        resolveLocationAndLoad()
    }

    func retry() {
        if let coordinate {
            loadWeather(for: coordinate)
        } else {
            resolveLocationAndLoad()
        }
    }

    private func resolveLocationAndLoad() {
        emit(.loading)

        locationService.requestLocation { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success(let coordinate):
                    self.coordinate = coordinate
                    self.loadWeather(for: coordinate)
                case .failure:
                    self.emit(.error("Не удалось определить геопозицию."))
                }
            }
        }
    }

    private func loadWeather(for coordinate: CLLocationCoordinate2D) {
        loadingTask?.cancel()
        emit(.loading)

        loadingTask = Task { [weak self] in
            guard let self else { return }

            do {
                let weather = try await weatherClient.fetchWeather(
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude
                )

                guard !Task.isCancelled else { return }
                emit(.loaded(weather))
            } catch {
                guard !Task.isCancelled else { return }
                let message = (error as? LocalizedError)?.errorDescription ?? "Не удалось получить прогноз."
                emit(.error(message))
            }
        }
    }

    private func emit(_ state: State) {
        onStateChange?(state)
    }
}
