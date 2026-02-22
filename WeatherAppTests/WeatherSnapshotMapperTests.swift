import XCTest
@testable import WeatherApp

final class WeatherSnapshotMapperTests: XCTestCase {
    func testHourlyIncludesRemainingCurrentDayAndAllNextDay() throws {
        let timeZone = try unwrapTimeZone("Europe/Moscow")
        let localtimeEpoch = epoch(
            year: 2026,
            month: 2,
            day: 20,
            hour: 15,
            minute: 30,
            timeZone: timeZone
        )

        let current = makeCurrentResponse(localtimeEpoch: localtimeEpoch)
        let forecast = makeForecastResponse(
            localtimeEpoch: localtimeEpoch,
            timeZoneIdentifier: timeZone.identifier,
            daySeeds: [
                DateSeed(year: 2026, month: 2, day: 20),
                DateSeed(year: 2026, month: 2, day: 21),
                DateSeed(year: 2026, month: 2, day: 22)
            ]
        )

        let snapshot = try WeatherSnapshotMapper.map(current: current, forecast: forecast)

        XCTAssertEqual(snapshot.hourly.count, 33)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        XCTAssertEqual(calendar.component(.day, from: snapshot.hourly.first?.date ?? Date.distantPast), 20)
        XCTAssertEqual(calendar.component(.hour, from: snapshot.hourly.first?.date ?? Date.distantPast), 15)

        XCTAssertEqual(calendar.component(.day, from: snapshot.hourly.last?.date ?? Date.distantPast), 21)
        XCTAssertEqual(calendar.component(.hour, from: snapshot.hourly.last?.date ?? Date.distantPast), 23)
    }

    func testHourlyBoundaryUsesForecastTimeZone() throws {
        let timeZone = try unwrapTimeZone("Pacific/Chatham")
        let localtimeEpoch = epoch(
            year: 2026,
            month: 7,
            day: 10,
            hour: 23,
            minute: 30,
            timeZone: timeZone
        )

        let current = makeCurrentResponse(localtimeEpoch: localtimeEpoch)
        let forecast = makeForecastResponse(
            localtimeEpoch: localtimeEpoch,
            timeZoneIdentifier: timeZone.identifier,
            daySeeds: [
                DateSeed(year: 2026, month: 7, day: 10),
                DateSeed(year: 2026, month: 7, day: 11),
                DateSeed(year: 2026, month: 7, day: 12)
            ]
        )

        let snapshot = try WeatherSnapshotMapper.map(current: current, forecast: forecast)

        XCTAssertEqual(snapshot.hourly.count, 25)
        XCTAssertEqual(snapshot.timeZone.identifier, timeZone.identifier)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        XCTAssertEqual(calendar.component(.hour, from: snapshot.hourly.first?.date ?? Date.distantPast), 23)
    }

    func testDailyForecastIsLimitedToThreeDays() throws {
        let timeZone = try unwrapTimeZone("Europe/Moscow")
        let localtimeEpoch = epoch(
            year: 2026,
            month: 8,
            day: 1,
            hour: 9,
            minute: 0,
            timeZone: timeZone
        )

        let current = makeCurrentResponse(localtimeEpoch: localtimeEpoch)
        let forecast = makeForecastResponse(
            localtimeEpoch: localtimeEpoch,
            timeZoneIdentifier: timeZone.identifier,
            daySeeds: [
                DateSeed(year: 2026, month: 8, day: 1),
                DateSeed(year: 2026, month: 8, day: 2),
                DateSeed(year: 2026, month: 8, day: 3),
                DateSeed(year: 2026, month: 8, day: 4),
                DateSeed(year: 2026, month: 8, day: 5)
            ]
        )

        let snapshot = try WeatherSnapshotMapper.map(current: current, forecast: forecast)

        XCTAssertEqual(snapshot.daily.count, 3)
        XCTAssertEqual(snapshot.daily.map(\.maxTempC), [10, 11, 12])
    }

    private func makeCurrentResponse(localtimeEpoch: Int) -> CurrentWeatherResponse {
        CurrentWeatherResponse(
            location: LocationDTO(
                name: "Test City",
                country: "Test Country",
                localtimeEpoch: localtimeEpoch,
                tzId: "UTC"
            ),
            current: CurrentDTO(
                tempC: 1,
                feelslikeC: 0,
                humidity: 50,
                windKph: 10,
                condition: ConditionDTO(text: "Cloudy", icon: "//cdn.weatherapi.com/test.png")
            )
        )
    }

    private func makeForecastResponse(
        localtimeEpoch: Int,
        timeZoneIdentifier: String,
        daySeeds: [DateSeed]
    ) -> ForecastWeatherResponse {
        ForecastWeatherResponse(
            location: LocationDTO(
                name: "Test City",
                country: "Test Country",
                localtimeEpoch: localtimeEpoch,
                tzId: timeZoneIdentifier
            ),
            forecast: ForecastDTO(
                forecastday: daySeeds.enumerated().map { index, seed in
                    makeForecastDay(
                        seed: seed,
                        maxTemp: Double(10 + index),
                        minTemp: Double(index),
                        timeZoneIdentifier: timeZoneIdentifier
                    )
                }
            )
        )
    }

    private func makeForecastDay(
        seed: DateSeed,
        maxTemp: Double,
        minTemp: Double,
        timeZoneIdentifier: String
    ) -> ForecastDayDTO {
        let timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let dayDate = makeDate(
            year: seed.year,
            month: seed.month,
            day: seed.day,
            hour: 0,
            minute: 0,
            timeZone: timeZone
        )

        let hours = (0...23).map { hour in
            HourDTO(
                timeEpoch: epoch(
                    year: seed.year,
                    month: seed.month,
                    day: seed.day,
                    hour: hour,
                    minute: 0,
                    timeZone: timeZone
                ),
                tempC: Double(hour),
                condition: ConditionDTO(text: "Hour \(hour)", icon: "//cdn.weatherapi.com/hour\(hour).png")
            )
        }

        return ForecastDayDTO(
            dateEpoch: Int(dayDate.timeIntervalSince1970),
            day: DayDTO(
                maxtempC: maxTemp,
                mintempC: minTemp,
                condition: ConditionDTO(text: "Sunny", icon: "//cdn.weatherapi.com/day.png")
            ),
            hour: hours
        )
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = timeZone
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute

        guard let date = components.date else {
            fatalError("Unable to build date for test fixtures")
        }
        return date
    }

    private func epoch(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        timeZone: TimeZone
    ) -> Int {
        Int(makeDate(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute,
            timeZone: timeZone
        ).timeIntervalSince1970)
    }

    private func unwrapTimeZone(_ identifier: String) throws -> TimeZone {
        guard let timeZone = TimeZone(identifier: identifier) else {
            throw NSError(domain: "WeatherSnapshotMapperTests", code: 0)
        }
        return timeZone
    }
}

private struct DateSeed {
    let year: Int
    let month: Int
    let day: Int
}
