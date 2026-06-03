import AppKit

/// Minimal command-line harness used to verify the full pipeline without the GUI.
/// Usage:  MapToPoster --test "City" "Country" out.png [distance]
enum HeadlessTest {
    static func run(arguments: [String]) {
        guard let idx = arguments.firstIndex(of: "--test") else { exit(2) }
        let rest = Array(arguments.dropFirst(idx + 1))
        let city = rest.count > 0 ? rest[0] : "Paris"
        let country = rest.count > 1 ? rest[1] : "France"
        let outPath = rest.count > 2 ? rest[2] : "poster.png"
        let dist = rest.count > 3 ? (Double(rest[3]) ?? 18000) : 18000

        var settings = PosterSettings()
        settings.city = city
        settings.country = country
        settings.distance = dist
        settings.dpi = 150   // smaller for a quick test
        if rest.count > 4 { settings.themeID = rest[4] }
        if rest.count > 5 { settings.displayCity = rest[5] }

        let sema = DispatchSemaphore(value: 0)
        Task {
            do {
                FileHandle.standardError.write("Geocoding \(city), \(country)…\n".data(using: .utf8)!)
                let geo = try await Geocoder.geocode(city: city, country: country)
                FileHandle.standardError.write("  → \(geo.coordinate.lat), \(geo.coordinate.lon)\n".data(using: .utf8)!)

                let bbox = PosterRenderer.boundingBox(center: geo.coordinate, settings: settings)
                FileHandle.standardError.write("Downloading Overpass data…\n".data(using: .utf8)!)
                let data = try await OverpassClient.fetch(
                    south: bbox.south, west: bbox.west, north: bbox.north, east: bbox.east,
                    includeBuildings: false)
                FileHandle.standardError.write("  → \(data.roads.count) roads, \(data.areas.count) areas\n".data(using: .utf8)!)

                let image = PosterRenderer.render(data: data, center: geo.coordinate, settings: settings)
                guard let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    FileHandle.standardError.write("PNG encode failed\n".data(using: .utf8)!); exit(1)
                }
                try png.write(to: URL(fileURLWithPath: outPath))
                FileHandle.standardError.write("✓ Wrote \(outPath)\n".data(using: .utf8)!)
                exit(0)
            } catch {
                FileHandle.standardError.write("ERROR: \(error)\n".data(using: .utf8)!)
                exit(1)
            }
            _ = sema
        }
        dispatchMain()
    }
}
