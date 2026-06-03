import Foundation

enum MapToPosterError: LocalizedError {
    case geocodeFailed(String)
    case overpassFailed(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .geocodeFailed(let s): return "Could not find that place: \(s)"
        case .overpassFailed(let s): return "Map data download failed: \(s)"
        case .noData: return "No map data was returned for this location."
        }
    }
}

/// Geocodes a city/country to coordinates using OpenStreetMap's Nominatim API,
/// the same geocoder the original project relies on.
struct Geocoder {
    static func geocode(city: String, country: String) async throws -> GeocodeResult {
        let query = [city, country].filter { !$0.isEmpty }.joined(separator: ", ")
        var comps = URLComponents(string: "https://nominatim.openstreetmap.org/search")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "limit", value: "1"),
        ]
        var req = URLRequest(url: comps.url!)
        // Nominatim's usage policy requires an identifying User-Agent.
        req.setValue("MapToPosterMac/1.0 (macOS poster generator)", forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw MapToPosterError.geocodeFailed("server error")
        }
        guard let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = arr.first,
              let latStr = first["lat"] as? String, let lat = Double(latStr),
              let lonStr = first["lon"] as? String, let lon = Double(lonStr)
        else {
            throw MapToPosterError.geocodeFailed(query)
        }
        let name = (first["display_name"] as? String) ?? query
        return GeocodeResult(coordinate: Coordinate(lat: lat, lon: lon), displayName: name)
    }
}
