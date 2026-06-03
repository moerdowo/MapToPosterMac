import Foundation

/// Downloads roads, water, parks (and optionally buildings) from the Overpass API.
/// This replaces the OSMnx data layer used by the original Python project; OSMnx
/// itself queries Overpass under the hood.
struct OverpassClient {
    /// Public Overpass mirrors, tried in order.
    static let endpoints = [
        "https://overpass-api.de/api/interpreter",
        "https://overpass.kumi.systems/api/interpreter",
        "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
    ]

    /// Fetch map geometry within a bounding box (south, west, north, east in degrees).
    static func fetch(south: Double, west: Double, north: Double, east: Double,
                      includeBuildings: Bool) async throws -> MapData {
        let bbox = "\(south),\(west),\(north),\(east)"
        var query = """
        [out:json][timeout:120];
        (
          way["highway"](\(bbox));
          way["natural"~"^(water|bay|strait)$"](\(bbox));
          way["waterway"="riverbank"](\(bbox));
          relation["natural"="water"](\(bbox));
          way["leisure"="park"](\(bbox));
          way["landuse"="grass"](\(bbox));
        """
        if includeBuildings {
            query += "\n  way[\"building\"](\(bbox));"
        }
        query += "\n);\nout geom;"

        var lastError: Error = MapToPosterError.noData
        for endpoint in endpoints {
            do {
                return try await run(query: query, endpoint: endpoint)
            } catch {
                lastError = error
                continue
            }
        }
        throw lastError
    }

    private static func run(query: String, endpoint: String) async throws -> MapData {
        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = "POST"
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        req.setValue("MapToPosterMac/1.0 (macOS poster generator)", forHTTPHeaderField: "User-Agent")
        req.httpBody = "data=\(query.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? query)".data(using: .utf8)
        req.timeoutInterval = 180

        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw MapToPosterError.overpassFailed("HTTP \(code)")
        }
        return try parse(data)
    }

    private static func parse(_ data: Data) throws -> MapData {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let elements = root["elements"] as? [[String: Any]] else {
            throw MapToPosterError.overpassFailed("bad JSON")
        }

        var result = MapData()

        func ring(from geometry: [[String: Any]]) -> [Coordinate] {
            geometry.compactMap { node in
                guard let lat = node["lat"] as? Double, let lon = node["lon"] as? Double else { return nil }
                return Coordinate(lat: lat, lon: lon)
            }
        }

        for el in elements {
            let type = el["type"] as? String ?? ""
            let tags = el["tags"] as? [String: Any] ?? [:]

            if type == "way", let geometry = el["geometry"] as? [[String: Any]] {
                let pts = ring(from: geometry)
                guard pts.count >= 2 else { continue }

                if let highway = tags["highway"] as? String {
                    result.roads.append(RoadWay(highway: highway, points: pts))
                } else if isWater(tags) {
                    result.areas.append(AreaPolygon(kind: .water, rings: [pts]))
                } else if isPark(tags) {
                    result.areas.append(AreaPolygon(kind: .park, rings: [pts]))
                } else if tags["building"] != nil {
                    result.areas.append(AreaPolygon(kind: .building, rings: [pts]))
                }
            } else if type == "relation", isWater(tags),
                      let members = el["members"] as? [[String: Any]] {
                var rings: [[Coordinate]] = []
                for m in members {
                    guard m["type"] as? String == "way",
                          let geometry = m["geometry"] as? [[String: Any]] else { continue }
                    let pts = ring(from: geometry)
                    if pts.count >= 3 { rings.append(pts) }
                }
                if !rings.isEmpty {
                    result.areas.append(AreaPolygon(kind: .water, rings: rings))
                }
            }
        }
        return result
    }

    private static func isWater(_ tags: [String: Any]) -> Bool {
        if let n = tags["natural"] as? String, ["water", "bay", "strait"].contains(n) { return true }
        if let w = tags["waterway"] as? String, w == "riverbank" { return true }
        return false
    }

    private static func isPark(_ tags: [String: Any]) -> Bool {
        if let l = tags["leisure"] as? String, l == "park" { return true }
        if let lu = tags["landuse"] as? String, lu == "grass" { return true }
        return false
    }
}
