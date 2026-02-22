import Foundation

struct WeatherSnapshot {
    let cityName: String
    let country: String
    let currentDate: Date
    let timeZone: TimeZone
    let current: CurrentWeather
    let hourly: [HourlyWeather]
    let daily: [DailyWeather]
}

struct CurrentWeather {
    let temperatureC: Double
    let feelsLikeC: Double
    let humidity: Int
    let windKph: Double
    let conditionText: String
    let conditionIconURL: URL?
    let maxTempC: Double
    let minTempC: Double
}

struct HourlyWeather {
    let date: Date
    let temperatureC: Double
    let conditionText: String
    let conditionIconURL: URL?
}

struct DailyWeather {
    let date: Date
    let maxTempC: Double
    let minTempC: Double
    let conditionText: String
    let conditionIconURL: URL?
}

enum WeatherSnapshotMapper {
    static func map(current: CurrentWeatherResponse, forecast: ForecastWeatherResponse) throws -> WeatherSnapshot {
        guard let today = forecast.forecast.forecastday.first else {
            throw WeatherServiceError.malformedData
        }

        let timeZone = TimeZone(identifier: forecast.location.tzId) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let currentDate = Date(timeIntervalSince1970: TimeInterval(forecast.location.localtimeEpoch))
        let currentHour = calendar.component(.hour, from: currentDate)

        let todayHours = today.hour
            .filter { dto in
                let hourValue = calendar.component(
                    .hour,
                    from: Date(timeIntervalSince1970: TimeInterval(dto.timeEpoch))
                )
                return hourValue >= currentHour
            }

        let nextDayHours = forecast.forecast.forecastday.dropFirst().first?.hour ?? []
        let hourlyItems = (todayHours + nextDayHours)
            .map {
                HourlyWeather(
                    date: Date(timeIntervalSince1970: TimeInterval($0.timeEpoch)),
                    temperatureC: $0.tempC,
                    conditionText: $0.condition.text,
                    conditionIconURL: normalizedIconURL(from: $0.condition.icon)
                )
            }

        let dailyItems = forecast.forecast.forecastday
            .prefix(3)
            .map {
                DailyWeather(
                    date: Date(timeIntervalSince1970: TimeInterval($0.dateEpoch)),
                    maxTempC: $0.day.maxtempC,
                    minTempC: $0.day.mintempC,
                    conditionText: $0.day.condition.text,
                    conditionIconURL: normalizedIconURL(from: $0.day.condition.icon)
                )
            }

        return WeatherSnapshot(
            cityName: forecast.location.name,
            country: forecast.location.country,
            currentDate: currentDate,
            timeZone: timeZone,
            current: CurrentWeather(
                temperatureC: current.current.tempC,
                feelsLikeC: current.current.feelslikeC,
                humidity: current.current.humidity,
                windKph: current.current.windKph,
                conditionText: current.current.condition.text,
                conditionIconURL: normalizedIconURL(from: current.current.condition.icon),
                maxTempC: today.day.maxtempC,
                minTempC: today.day.mintempC
            ),
            hourly: hourlyItems,
            daily: dailyItems
        )
    }

    private static func normalizedIconURL(from source: String) -> URL? {
        if source.hasPrefix("//") {
            return URL(string: "https:\(source)")
        }
        return URL(string: source)
    }
}
