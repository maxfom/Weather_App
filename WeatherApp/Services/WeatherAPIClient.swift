import Foundation

protocol WeatherAPIClientProtocol {
    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherSnapshot
}

enum WeatherServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case badStatusCode(Int)
    case malformedData
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "Не удалось подготовить запрос к серверу погоды."
        case .invalidResponse:
            return "Получен некорректный ответ от сервера погоды."
        case .badStatusCode(let code):
            return "Сервер погоды вернул ошибку (код \(code))."
        case .malformedData:
            return "Сервер вернул неполные данные прогноза."
        case .network:
            return "Проблема с сетью. Проверьте интернет и попробуйте снова."
        case .decoding:
            return "Не удалось обработать данные погоды."
        }
    }
}

final class WeatherAPIClient: WeatherAPIClientProtocol {
    private enum Constants {
        static let apiKey = "fa8b3df74d4042b9aa7135114252304"
        static let host = "api.weatherapi.com"
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherSnapshot {
        let posixLocale = Locale(identifier: "en_US_POSIX")
        let roundedLatitude = String(format: "%.4f", locale: posixLocale, latitude)
        let roundedLongitude = String(format: "%.4f", locale: posixLocale, longitude)
        let query = "\(roundedLatitude),\(roundedLongitude)"

        guard
            let currentURL = makeURL(path: "/v1/current.json", query: query, extra: []),
            let forecastURL = makeURL(path: "/v1/forecast.json", query: query, extra: [
                URLQueryItem(name: "days", value: "3")
            ])
        else {
            throw WeatherServiceError.invalidRequest
        }

        async let currentResponse: CurrentWeatherResponse = request(currentURL)
        async let forecastResponse: ForecastWeatherResponse = request(forecastURL)

        do {
            let (current, forecast) = try await (currentResponse, forecastResponse)
            return try WeatherSnapshotMapper.map(current: current, forecast: forecast)
        } catch let error as WeatherServiceError {
            throw error
        } catch {
            throw WeatherServiceError.network(error)
        }
    }

    private func makeURL(path: String, query: String, extra: [URLQueryItem]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = Constants.host
        components.path = path
        components.queryItems = [
            URLQueryItem(name: "key", value: Constants.apiKey),
            URLQueryItem(name: "q", value: query)
        ] + extra
        return components.url
    }

    private func request<T: Decodable>(_ url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw WeatherServiceError.invalidResponse
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                throw WeatherServiceError.badStatusCode(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw WeatherServiceError.decoding(error)
            }
        } catch let error as WeatherServiceError {
            throw error
        } catch {
            throw WeatherServiceError.network(error)
        }
    }
}
