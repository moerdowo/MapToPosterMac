import SwiftUI

@MainActor
final class PosterViewModel: ObservableObject {
    @Published var settings = PosterSettings()
    @Published var poster: NSImage?
    @Published var isWorking = false
    @Published var statusMessage = ""
    @Published var errorMessage: String?
    @Published var lastCenter: Coordinate?

    private var fetchedData: MapData?
    private var fetchedForKey: String?   // cache key for the downloaded geometry

    /// A key describing which inputs affect the *downloaded* data (not styling).
    private func dataKey(center: Coordinate) -> String {
        [String(format: "%.5f", center.lat),
         String(format: "%.5f", center.lon),
         String(Int(settings.distance)),
         String(format: "%.1f", settings.widthInches),
         String(format: "%.1f", settings.heightInches),
         settings.showBuildings ? "b1" : "b0"].joined(separator: "|")
    }

    func generate() {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        let settings = self.settings

        Task {
            do {
                // 1. Resolve center coordinate.
                let center: Coordinate
                if settings.useManualCenter {
                    center = Coordinate(lat: settings.latitude, lon: settings.longitude)
                    statusMessage = "Using manual coordinates…"
                } else {
                    statusMessage = "Geocoding \(settings.city)…"
                    let geo = try await Geocoder.geocode(city: settings.city, country: settings.country)
                    center = geo.coordinate
                }
                self.lastCenter = center

                // 2. Fetch geometry (reuse cache when only styling changed).
                let key = dataKey(center: center)
                let data: MapData
                if let cached = fetchedData, fetchedForKey == key {
                    data = cached
                } else {
                    statusMessage = "Downloading map data from OpenStreetMap…"
                    let bbox = PosterRenderer.boundingBox(center: center, settings: settings)
                    data = try await OverpassClient.fetch(
                        south: bbox.south, west: bbox.west, north: bbox.north, east: bbox.east,
                        includeBuildings: settings.showBuildings)
                    guard !data.roads.isEmpty || !data.areas.isEmpty else {
                        throw MapToPosterError.noData
                    }
                    fetchedData = data
                    fetchedForKey = key
                }

                // 3. Render.
                statusMessage = "Rendering poster (\(data.roads.count) roads)…"
                let image = await Task.detached(priority: .userInitiated) {
                    PosterRenderer.render(data: data, center: center, settings: settings)
                }.value

                self.poster = image
                self.statusMessage = "Done — \(data.roads.count) roads, \(data.areas.count) areas."
                self.isWorking = false
            } catch {
                self.errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                self.statusMessage = ""
                self.isWorking = false
            }
        }
    }

    /// Re-render from cached data with current styling (fast; no network).
    func rerenderStyleOnly() {
        guard let data = fetchedData, let center = lastCenter, !isWorking else { return }
        let settings = self.settings
        isWorking = true
        statusMessage = "Re-rendering…"
        Task {
            let image = await Task.detached(priority: .userInitiated) {
                PosterRenderer.render(data: data, center: center, settings: settings)
            }.value
            self.poster = image
            self.statusMessage = "Updated."
            self.isWorking = false
        }
    }

    func export() {
        guard let poster else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        let cityToken = settings.city.replacingOccurrences(of: " ", with: "_").lowercased()
        panel.nameFieldStringValue = "\(cityToken)_\(settings.themeID).png"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        guard let tiff = poster.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let data = rep.representation(using: .png, properties: [:]) else { return }
        try? data.write(to: url)
        statusMessage = "Saved to \(url.lastPathComponent)"
    }
}
