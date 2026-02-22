import CoreLocation

protocol LocationServiceProtocol {
    func requestLocation(_ completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void)
}

final class LocationService: NSObject, LocationServiceProtocol {
    private enum Constants {
        static let moscow = CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6176)
    }

    private let manager: CLLocationManager
    private var completion: ((Result<CLLocationCoordinate2D, Error>) -> Void)?

    override init() {
        self.manager = CLLocationManager()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation(_ completion: @escaping (Result<CLLocationCoordinate2D, Error>) -> Void) {
        self.completion = completion

        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .success(Constants.moscow))
        @unknown default:
            finish(with: .success(Constants.moscow))
        }
    }

    private func finish(with result: Result<CLLocationCoordinate2D, Error>) {
        completion?(result)
        completion = nil
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: .success(Constants.moscow))
        case .notDetermined:
            break
        @unknown default:
            finish(with: .success(Constants.moscow))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else {
            finish(with: .success(Constants.moscow))
            return
        }
        finish(with: .success(coordinate))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: .success(Constants.moscow))
    }
}
