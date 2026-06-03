import Foundation

/// A geographic coordinate in degrees.
struct Coordinate: Hashable {
    var lat: Double
    var lon: Double
}

/// A road segment fetched from OSM, with its highway classification.
struct RoadWay {
    let highway: String
    let points: [Coordinate]
}

/// A filled area (water / park / building), as a list of rings (lat/lon).
struct AreaPolygon {
    enum Kind { case water, park, building }
    let kind: Kind
    let rings: [[Coordinate]]
}

/// The full set of map geometry needed to render a poster.
struct MapData {
    var roads: [RoadWay] = []
    var areas: [AreaPolygon] = []
}

/// Result of geocoding a place name.
struct GeocodeResult {
    let coordinate: Coordinate
    let displayName: String
}

/// All user-configurable settings, mirroring the original CLI options plus a few
/// native extras (layer toggles, resolution).
struct PosterSettings {
    var city: String = "Paris"
    var country: String = "France"

    // Optional manual center override (overrides geocoding when enabled).
    var useManualCenter: Bool = false
    var latitude: Double = 48.8566
    var longitude: Double = 2.3522

    // Map radius in meters (CLI: --distance, default 18000, range 4000–20000).
    var distance: Double = 18000

    var themeID: String = "terracotta"

    // Output size in inches (CLI: --width / --height, max 20).
    var widthInches: Double = 12
    var heightInches: Double = 16

    // Render resolution. The original saves PNGs at 300 DPI.
    var dpi: Double = 300

    // Typography (CLI: --display-city / --display-country / --font-family / --country-label).
    var displayCity: String = ""        // empty → use `city`
    var displayCountry: String = ""     // empty → use `country`
    var fontFamily: String = "Helvetica Neue"

    // Native layer toggles.
    var showWater: Bool = true
    var showParks: Bool = true
    var showBuildings: Bool = false

    var theme: Theme { Theme.named(themeID) }

    var effectiveDisplayCity: String {
        displayCity.isEmpty ? city : displayCity
    }
    var effectiveDisplayCountry: String {
        displayCountry.isEmpty ? country : displayCountry
    }
}
