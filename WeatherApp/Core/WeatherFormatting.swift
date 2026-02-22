import Foundation

enum WeatherFormatting {
    private static func makeHourFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone
        return formatter
    }

    private static func makeDayFormatter(timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "E, d MMM"
        formatter.timeZone = timeZone
        return formatter
    }

    static func temperature(_ value: Double) -> String {
        "\(Int(value.rounded()))°"
    }

    static func hourString(from date: Date, timeZone: TimeZone) -> String {
        makeHourFormatter(timeZone: timeZone).string(from: date)
    }

    static func dayString(from date: Date, timeZone: TimeZone) -> String {
        makeDayFormatter(timeZone: timeZone).string(from: date).capitalized
    }
}
