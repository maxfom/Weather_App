# WeatherApp (UIKit, без Storyboard)

Тестовое iOS-приложение погоды на Swift + UIKit

## ТЗ

- Один экран с погодной информацией:
  - текущая погода;
  - почасовой прогноз: оставшиеся часы текущего дня + все часы следующего дня;
  - прогноз на 3 дня.
- Состояния экрана:
  - `loading`;
  - `error` с кнопкой `Повторить`;
  - `content`.
- Геолокация:
  - запрос разрешения при старте;
  - при отказе/ограничении используется Москва (`55.7558, 37.6176`).
- Данные берутся из двух API endpoint’ов:
  - `/v1/current.json`
  - `/v1/forecast.json?days=3`

## Архитектура

- `ViewModel`: `WeatherViewModel` (управление состояниями экрана, retry, orchestration).
- `Services`:
  - `LocationService` (CLLocation + fallback);
  - `WeatherAPIClient` (сетевые запросы, декодирование, обработка ошибок).
- `Models`:
  - DTO-модели API;
  - доменная модель `WeatherSnapshot` + mapper.
- `UI`:
  - `WeatherViewController`;
  - `HourlyWeatherCell`;
  - `DailyForecastRowView`.

## Технические детали

- UIKit only, без Storyboard.
- `async/await` для сетевых запросов.
- Иконки погодные загружаются с WeatherAPI и кэшируются в `ImageLoader`.
- `Info.plist` содержит `NSLocationWhenInUseUsageDescription`.

## Тесты

Добавлен unit-test target `WeatherAppTests` c проверкой критичной логики маппинга:
- остаток часов текущего дня + все часы следующего;
- корректная граница по часовому поясу из API (`tz_id`);
- ограничение daily-прогноза тремя днями.
