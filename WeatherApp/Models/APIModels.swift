import Foundation

struct CurrentWeatherResponse: Decodable {
    let location: LocationDTO
    let current: CurrentDTO
}

struct ForecastWeatherResponse: Decodable {
    let location: LocationDTO
    let forecast: ForecastDTO
}

struct LocationDTO: Decodable {
    let name: String
    let country: String
    let localtimeEpoch: Int
    let tzId: String
}

struct CurrentDTO: Decodable {
    let tempC: Double
    let feelslikeC: Double
    let humidity: Int
    let windKph: Double
    let condition: ConditionDTO
}

struct ForecastDTO: Decodable {
    let forecastday: [ForecastDayDTO]
}

struct ForecastDayDTO: Decodable {
    let dateEpoch: Int
    let day: DayDTO
    let hour: [HourDTO]
}

struct DayDTO: Decodable {
    let maxtempC: Double
    let mintempC: Double
    let condition: ConditionDTO
}

struct HourDTO: Decodable {
    let timeEpoch: Int
    let tempC: Double
    let condition: ConditionDTO
}

struct ConditionDTO: Decodable {
    let text: String
    let icon: String
}
