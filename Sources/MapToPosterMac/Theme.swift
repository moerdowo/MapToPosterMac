import SwiftUI

/// A poster color theme, mirroring the JSON theme files from the original
/// `maptoposter` project. Colors are stored as hex strings and converted on demand.
struct Theme: Identifiable, Hashable {
    let id: String          // file-name style key, e.g. "midnight_blue"
    let name: String        // display name, e.g. "Midnight Blue"
    let description: String

    let bg: String
    let text: String
    let gradientColor: String
    let water: String
    let parks: String

    let roadMotorway: String
    let roadPrimary: String
    let roadSecondary: String
    let roadTertiary: String
    let roadResidential: String
    let roadDefault: String

    // Convenience NSColor accessors -------------------------------------------------
    var bgColor: NSColor { NSColor(hex: bg) }
    var textColor: NSColor { NSColor(hex: text) }
    var gradientNSColor: NSColor { NSColor(hex: gradientColor) }
    var waterColor: NSColor { NSColor(hex: water) }
    var parksColor: NSColor { NSColor(hex: parks) }

    /// Returns (color, lineWidthPoints) for a given OSM `highway` value, following
    /// the same hierarchy used by the original renderer.
    func style(forHighway highway: String) -> (NSColor, CGFloat) {
        switch highway {
        case "motorway", "motorway_link":
            return (NSColor(hex: roadMotorway), 1.2)
        case "trunk", "trunk_link", "primary", "primary_link":
            return (NSColor(hex: roadPrimary), 1.0)
        case "secondary", "secondary_link":
            return (NSColor(hex: roadSecondary), 0.8)
        case "tertiary", "tertiary_link":
            return (NSColor(hex: roadTertiary), 0.6)
        case "residential", "living_street", "unclassified":
            return (NSColor(hex: roadResidential), 0.4)
        default:
            return (NSColor(hex: roadDefault), 0.4)
        }
    }

    /// Draw priority — lower draws first (underneath). Motorways end up on top.
    static func drawPriority(forHighway highway: String) -> Int {
        switch highway {
        case "motorway", "motorway_link": return 5
        case "trunk", "trunk_link", "primary", "primary_link": return 4
        case "secondary", "secondary_link": return 3
        case "tertiary", "tertiary_link": return 2
        case "residential", "living_street", "unclassified": return 1
        default: return 0
        }
    }
}

extension Theme {
    /// All 17 themes from the original project, in display order.
    static let all: [Theme] = [
        Theme(id: "terracotta", name: "Terracotta",
              description: "Mediterranean warmth — burnt orange and clay tones on cream",
              bg: "#F5EDE4", text: "#8B4513", gradientColor: "#F5EDE4",
              water: "#A8C4C4", parks: "#E8E0D0",
              roadMotorway: "#A0522D", roadPrimary: "#B8653A", roadSecondary: "#C9846A",
              roadTertiary: "#D9A08A", roadResidential: "#E5C4B0", roadDefault: "#D9A08A"),

        Theme(id: "noir", name: "Noir",
              description: "Pure black background with white/gray roads — modern gallery aesthetic",
              bg: "#000000", text: "#FFFFFF", gradientColor: "#000000",
              water: "#0A0A0A", parks: "#111111",
              roadMotorway: "#FFFFFF", roadPrimary: "#E0E0E0", roadSecondary: "#B0B0B0",
              roadTertiary: "#808080", roadResidential: "#505050", roadDefault: "#808080"),

        Theme(id: "midnight_blue", name: "Midnight Blue",
              description: "Deep navy background with gold/copper roads — luxury atlas aesthetic",
              bg: "#0A1628", text: "#D4AF37", gradientColor: "#0A1628",
              water: "#061020", parks: "#0F2235",
              roadMotorway: "#D4AF37", roadPrimary: "#C9A227", roadSecondary: "#A8893A",
              roadTertiary: "#8B7355", roadResidential: "#6B5B4F", roadDefault: "#8B7355"),

        Theme(id: "blueprint", name: "Blueprint",
              description: "Classic architectural blueprint — technical drawing aesthetic",
              bg: "#1A3A5C", text: "#E8F4FF", gradientColor: "#1A3A5C",
              water: "#0F2840", parks: "#1E4570",
              roadMotorway: "#E8F4FF", roadPrimary: "#C5DCF0", roadSecondary: "#9FC5E8",
              roadTertiary: "#7BAED4", roadResidential: "#5A96C0", roadDefault: "#7BAED4"),

        Theme(id: "neon_cyberpunk", name: "Neon Cyberpunk",
              description: "Dark background with electric pink/cyan — bold night city vibes",
              bg: "#0D0D1A", text: "#00FFFF", gradientColor: "#0D0D1A",
              water: "#0A0A15", parks: "#151525",
              roadMotorway: "#FF00FF", roadPrimary: "#00FFFF", roadSecondary: "#00C8C8",
              roadTertiary: "#0098A0", roadResidential: "#006870", roadDefault: "#0098A0"),

        Theme(id: "warm_beige", name: "Warm Beige",
              description: "Earthy warm neutrals with sepia tones — vintage map aesthetic",
              bg: "#F5F0E8", text: "#6B5B4F", gradientColor: "#F5F0E8",
              water: "#DDD5C8", parks: "#E8E4D8",
              roadMotorway: "#8B7355", roadPrimary: "#A08B70", roadSecondary: "#B5A48E",
              roadTertiary: "#C9BBAA", roadResidential: "#D9CFC2", roadDefault: "#C9BBAA"),

        Theme(id: "pastel_dream", name: "Pastel Dream",
              description: "Soft muted pastels with dusty blues and mauves — dreamy artistic aesthetic",
              bg: "#FAF7F2", text: "#5D5A6D", gradientColor: "#FAF7F2",
              water: "#D4E4ED", parks: "#E8EDE4",
              roadMotorway: "#7B8794", roadPrimary: "#9BA4B0", roadSecondary: "#B5AEBB",
              roadTertiary: "#C9C0C9", roadResidential: "#D8D2D8", roadDefault: "#C9C0C9"),

        Theme(id: "japanese_ink", name: "Japanese Ink",
              description: "Traditional ink wash inspired — minimalist with subtle red accent",
              bg: "#FAF8F5", text: "#2C2C2C", gradientColor: "#FAF8F5",
              water: "#E8E4E0", parks: "#F0EDE8",
              roadMotorway: "#8B2500", roadPrimary: "#4A4A4A", roadSecondary: "#6A6A6A",
              roadTertiary: "#909090", roadResidential: "#B8B8B8", roadDefault: "#909090"),

        Theme(id: "emerald", name: "Emerald City",
              description: "Lush dark green aesthetic with mint accents",
              bg: "#062C22", text: "#E3F9F1", gradientColor: "#062C22",
              water: "#0D4536", parks: "#0F523E",
              roadMotorway: "#4ADEB0", roadPrimary: "#2DB88F", roadSecondary: "#249673",
              roadTertiary: "#1B7559", roadResidential: "#155C46", roadDefault: "#155C46"),

        Theme(id: "forest", name: "Forest",
              description: "Deep greens and sage tones — organic botanical aesthetic",
              bg: "#F0F4F0", text: "#2D4A3E", gradientColor: "#F0F4F0",
              water: "#B8D4D4", parks: "#D4E8D4",
              roadMotorway: "#2D4A3E", roadPrimary: "#3D6B55", roadSecondary: "#5A8A70",
              roadTertiary: "#7AAA90", roadResidential: "#A0C8B0", roadDefault: "#7AAA90"),

        Theme(id: "ocean", name: "Ocean",
              description: "Various blues and teals — perfect for coastal cities",
              bg: "#F0F8FA", text: "#1A5F7A", gradientColor: "#F0F8FA",
              water: "#B8D8E8", parks: "#D8EAE8",
              roadMotorway: "#1A5F7A", roadPrimary: "#2A7A9A", roadSecondary: "#4A9AB8",
              roadTertiary: "#70B8D0", roadResidential: "#A0D0E0", roadDefault: "#4A9AB8"),

        Theme(id: "sunset", name: "Sunset",
              description: "Warm oranges and pinks on soft peach — dreamy golden hour aesthetic",
              bg: "#FDF5F0", text: "#C45C3E", gradientColor: "#FDF5F0",
              water: "#F0D8D0", parks: "#F8E8E0",
              roadMotorway: "#C45C3E", roadPrimary: "#D87A5A", roadSecondary: "#E8A088",
              roadTertiary: "#F0B8A8", roadResidential: "#F5D0C8", roadDefault: "#E8A088"),

        Theme(id: "autumn", name: "Autumn",
              description: "Burnt oranges, deep reds, golden yellows — seasonal warmth",
              bg: "#FBF7F0", text: "#8B4513", gradientColor: "#FBF7F0",
              water: "#D8CFC0", parks: "#E8E0D0",
              roadMotorway: "#8B2500", roadPrimary: "#B8450A", roadSecondary: "#CC7A30",
              roadTertiary: "#D9A050", roadResidential: "#E8C888", roadDefault: "#CC7A30"),

        Theme(id: "copper_patina", name: "Copper Patina",
              description: "Oxidized copper aesthetic — teal-green patina with copper accents",
              bg: "#E8F0F0", text: "#2A5A5A", gradientColor: "#E8F0F0",
              water: "#C0D8D8", parks: "#D8E8E0",
              roadMotorway: "#B87333", roadPrimary: "#5A8A8A", roadSecondary: "#6B9E9E",
              roadTertiary: "#88B4B4", roadResidential: "#A8CCCC", roadDefault: "#88B4B4"),

        Theme(id: "monochrome_blue", name: "Monochrome Blue",
              description: "Single blue color family with varying saturation — clean and cohesive",
              bg: "#F5F8FA", text: "#1A3A5C", gradientColor: "#F5F8FA",
              water: "#D0E0F0", parks: "#E0EAF2",
              roadMotorway: "#1A3A5C", roadPrimary: "#2A5580", roadSecondary: "#4A7AA8",
              roadTertiary: "#7AA0C8", roadResidential: "#A8C4E0", roadDefault: "#4A7AA8"),

        Theme(id: "gradient_roads", name: "Gradient Roads",
              description: "Smooth gradient from dark center to light edges with subtle features",
              bg: "#FFFFFF", text: "#000000", gradientColor: "#FFFFFF",
              water: "#D5D5D5", parks: "#EFEFEF",
              roadMotorway: "#050505", roadPrimary: "#151515", roadSecondary: "#2A2A2A",
              roadTertiary: "#404040", roadResidential: "#555555", roadDefault: "#404040"),

        Theme(id: "contrast_zones", name: "Contrast Zones",
              description: "Strong contrast showing urban density — darker center, lighter edges",
              bg: "#FFFFFF", text: "#000000", gradientColor: "#FFFFFF",
              water: "#B0B0B0", parks: "#ECECEC",
              roadMotorway: "#000000", roadPrimary: "#0F0F0F", roadSecondary: "#252525",
              roadTertiary: "#404040", roadResidential: "#5A5A5A", roadDefault: "#404040"),
    ]

    static func named(_ id: String) -> Theme {
        all.first(where: { $0.id == id }) ?? all[0]
    }
}

extension NSColor {
    /// Create an NSColor from a `#RRGGBB` (or `#RRGGBBAA`) hex string.
    convenience init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: s).scanHexInt64(&value)
        let r, g, b, a: CGFloat
        if s.count == 8 {
            r = CGFloat((value >> 24) & 0xFF) / 255
            g = CGFloat((value >> 16) & 0xFF) / 255
            b = CGFloat((value >> 8) & 0xFF) / 255
            a = CGFloat(value & 0xFF) / 255
        } else {
            r = CGFloat((value >> 16) & 0xFF) / 255
            g = CGFloat((value >> 8) & 0xFF) / 255
            b = CGFloat(value & 0xFF) / 255
            a = 1.0
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}
