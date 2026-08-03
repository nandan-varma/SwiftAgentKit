import Foundation
import JSONSchema
import SwiftyJSON

/// A weather tool backed by the free [Open-Meteo](https://open-meteo.com) API —
/// no API key or account required. Resolves the given location via Open-Meteo's
/// geocoding API, then fetches current conditions for the resulting coordinates.
public struct WeatherTool: Tool {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public let name = "get_weather"
    public let description = "Get current weather for a location"

    public let inputSchema: JSONSchema = .object(
        description: "Input for weather queries",
        properties: [
            "location": .string(description: "City name")
        ],
        required: ["location"]
    )

    public let outputSchema: JSONSchema = .object(
        description: "Weather information",
        properties: [
            "weather": .string(description: "Weather description"),
            "temperatureFahrenheit": .number(description: "Current temperature in Fahrenheit"),
            "humidityPercent": .integer(description: "Relative humidity percentage"),
            "windSpeedKmh": .number(description: "Wind speed in km/h"),
            "resolvedLocation": .string(description: "The geocoded location name")
        ],
        required: ["weather"]
    )

    public func execute(input: [String: JSON]) async throws -> ToolResult {
        guard let location = input["location"]?.string, !location.isEmpty else {
            throw ToolError.invalidInput
        }

        let place = try await geocode(location: location)
        let weather = try await currentWeather(latitude: place.latitude, longitude: place.longitude)
        let description = Self.description(forWMOCode: weather.weatherCode)

        let content = "Weather in \(place.name): \(description), \(weather.temperature)°F, \(weather.humidity)% humidity, wind \(weather.windSpeed) km/h"
        let structuredOutput = JSON([
            "weather": description,
            "temperatureFahrenheit": weather.temperature,
            "humidityPercent": weather.humidity,
            "windSpeedKmh": weather.windSpeed,
            "resolvedLocation": place.name
        ])

        return ToolResult(
            content: content,
            data: structuredOutput.dictionaryValue,
            structuredOutput: structuredOutput
        )
    }

    // MARK: - Open-Meteo API

    private struct GeocodingResponse: Decodable {
        let results: [GeocodingResult]?
    }

    private struct GeocodingResult: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
    }

    private struct ForecastResponse: Decodable {
        let current: CurrentWeather
    }

    private struct CurrentWeather: Decodable {
        let temperature: Double
        let weatherCode: Int
        let humidity: Int
        let windSpeed: Double

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case weatherCode = "weather_code"
            case humidity = "relative_humidity_2m"
            case windSpeed = "wind_speed_10m"
        }
    }

    private func geocode(location: String) async throws -> (name: String, latitude: Double, longitude: Double) {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: location),
            URLQueryItem(name: "count", value: "1")
        ]

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)

        let decoded = try JSONDecoder().decode(GeocodingResponse.self, from: data)
        guard let result = decoded.results?.first else {
            throw WeatherToolError.locationNotFound(location)
        }
        return (result.name, result.latitude, result.longitude)
    }

    private func currentWeather(latitude: Double, longitude: Double) async throws -> CurrentWeather {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code,relative_humidity_2m,wind_speed_10m"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit")
        ]

        let (data, response) = try await session.data(from: components.url!)
        try Self.validate(response)

        return try JSONDecoder().decode(ForecastResponse.self, from: data).current
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw WeatherToolError.apiError("Open-Meteo request failed with a non-2xx response")
        }
    }

    /// Maps an Open-Meteo/WMO weather code to a human-readable description.
    /// See https://open-meteo.com/en/docs for the full code table.
    private static func description(forWMOCode code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Fog"
        case 51: return "Light drizzle"
        case 53: return "Moderate drizzle"
        case 55: return "Dense drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61: return "Slight rain"
        case 63: return "Moderate rain"
        case 65: return "Heavy rain"
        case 66, 67: return "Freezing rain"
        case 71: return "Slight snow fall"
        case 73: return "Moderate snow fall"
        case 75: return "Heavy snow fall"
        case 77: return "Snow grains"
        case 80: return "Slight rain showers"
        case 81: return "Moderate rain showers"
        case 82: return "Violent rain showers"
        case 85: return "Slight snow showers"
        case 86: return "Heavy snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown weather conditions"
        }
    }
}
