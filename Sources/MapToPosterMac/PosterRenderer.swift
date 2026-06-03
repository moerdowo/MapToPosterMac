import AppKit

/// Renders a map poster to an `NSImage`, reproducing the layout, layering,
/// gradient fades and typography of the original `create_map_poster.py`.
struct PosterRenderer {

    /// Compute the equirectangular projection helpers and crop extents that match
    /// the original's `compensated_dist` / `get_crop_limits` logic.
    struct Frame {
        let center: Coordinate
        let mPerDegLat: Double
        let mPerDegLon: Double
        let halfX: Double      // meters, half width of crop
        let halfY: Double      // meters, half height of crop

        func project(_ c: Coordinate) -> CGPoint {
            let x = (c.lon - center.lon) * mPerDegLon
            let y = (c.lat - center.lat) * mPerDegLat
            return CGPoint(x: x, y: y)
        }
    }

    static func makeFrame(center: Coordinate, settings: PosterSettings) -> Frame {
        let w = settings.widthInches, h = settings.heightInches
        // compensated_dist = dist * (max/min) / 4   (viewport-crop compensation)
        let compensated = settings.distance * (max(h, w) / min(h, w)) / 4.0
        let aspect = w / h
        var halfX = compensated
        var halfY = compensated
        if aspect > 1 {            // landscape → reduce height
            halfY = halfX / aspect
        } else {                   // portrait → reduce width
            halfX = halfY * aspect
        }
        let mPerDegLat = 111_320.0
        let mPerDegLon = 111_320.0 * cos(center.lat * .pi / 180.0)
        return Frame(center: center, mPerDegLat: mPerDegLat, mPerDegLon: mPerDegLon,
                     halfX: halfX, halfY: halfY)
    }

    /// Bounding box (with margin) to request from Overpass, using the square
    /// `compensated_dist` extent like the original fetch step.
    static func boundingBox(center: Coordinate, settings: PosterSettings)
        -> (south: Double, west: Double, north: Double, east: Double) {
        let w = settings.widthInches, h = settings.heightInches
        let compensated = settings.distance * (max(h, w) / min(h, w)) / 4.0
        let mPerDegLat = 111_320.0
        let mPerDegLon = 111_320.0 * cos(center.lat * .pi / 180.0)
        let dLat = (compensated / mPerDegLat) * 1.05
        let dLon = (compensated / mPerDegLon) * 1.05
        return (center.lat - dLat, center.lon - dLon, center.lat + dLat, center.lon + dLon)
    }

    // MARK: - Rendering

    static func render(data: MapData, center: Coordinate, settings: PosterSettings) -> NSImage {
        let theme = settings.theme
        let frame = makeFrame(center: center, settings: settings)
        let dpi = settings.dpi
        let pxW = Int((settings.widthInches * dpi).rounded())
        let pxH = Int((settings.heightInches * dpi).rounded())
        let scaleFactor = min(settings.heightInches, settings.widthInches) / 12.0

        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pxW, pixelsHigh: pxH,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = NSSize(width: pxW, height: pxH)

        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            return NSImage(size: NSSize(width: pxW, height: pxH))
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ctx
        let cg = ctx.cgContext
        cg.setShouldAntialias(true)

        // Map meters → pixels. Crop region [-halfX, halfX] × [-halfY, halfY].
        let sx = Double(pxW) / (2 * frame.halfX)
        let sy = Double(pxH) / (2 * frame.halfY)
        func toPixel(_ c: Coordinate) -> CGPoint {
            let p = frame.project(c)
            return CGPoint(x: (p.x + frame.halfX) * sx, y: (p.y + frame.halfY) * sy)
        }

        // 1. Background ------------------------------------------------------------
        theme.bgColor.setFill()
        cg.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))

        // 2. Area fills (parks under water) ---------------------------------------
        func fillAreas(_ kind: AreaPolygon.Kind, color: NSColor) {
            color.setFill()
            for area in data.areas where area.kind == kind {
                let path = CGMutablePath()
                for ring in area.rings where ring.count >= 3 {
                    let pts = ring.map(toPixel)
                    path.addLines(between: pts)
                    path.closeSubpath()
                }
                cg.addPath(path)
            }
            cg.fillPath(using: .evenOdd)
        }
        if settings.showBuildings {
            fillAreas(.building, color: theme.parksColor.blended(withFraction: 0.25, of: theme.bgColor) ?? theme.parksColor)
        }
        if settings.showParks { fillAreas(.park, color: theme.parksColor) }
        if settings.showWater { fillAreas(.water, color: theme.waterColor) }

        // 3. Roads, drawn small → large so motorways sit on top --------------------
        let lwScale = dpi / 72.0   // matplotlib points → pixels
        let sortedRoads = data.roads.sorted {
            Theme.drawPriority(forHighway: $0.highway) < Theme.drawPriority(forHighway: $1.highway)
        }
        cg.setLineCap(.round)
        cg.setLineJoin(.round)
        for road in sortedRoads {
            let (color, widthPt) = theme.style(forHighway: road.highway)
            let pts = road.points.map(toPixel)
            guard pts.count >= 2 else { continue }
            cg.setStrokeColor(color.cgColor)
            cg.setLineWidth(max(0.3, widthPt * lwScale))
            cg.beginPath()
            cg.addLines(between: pts)
            cg.strokePath()
        }

        // 4. Gradient fades at top & bottom (fade to background) -------------------
        drawGradientFade(cg, color: theme.gradientNSColor, pxW: pxW, pxH: pxH, location: .bottom)
        drawGradientFade(cg, color: theme.gradientNSColor, pxW: pxW, pxH: pxH, location: .top)

        // 5. Typography ------------------------------------------------------------
        drawText(cg: cg, pxW: pxW, pxH: pxH, scale: scaleFactor, dpi: dpi,
                 settings: settings, theme: theme, center: center)

        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: NSSize(width: pxW, height: pxH))
        image.addRepresentation(rep)
        return image
    }

    // MARK: - Gradient fade

    private enum FadeLocation { case top, bottom }

    private static func drawGradientFade(_ cg: CGContext, color: NSColor,
                                         pxW: Int, pxH: Int, location: FadeLocation) {
        guard let c = color.usingColorSpace(.deviceRGB) else { return }
        let comps: [CGFloat] = [c.redComponent, c.greenComponent, c.blueComponent]
        let band = CGFloat(pxH) * 0.25

        // Bottom: alpha 1 at the very bottom → 0 at 25% up.
        // Top:    alpha 0 at 75% → 1 at the very top.
        let (y0, y1, a0, a1): (CGFloat, CGFloat, CGFloat, CGFloat)
        switch location {
        case .bottom: (y0, y1, a0, a1) = (0, band, 1, 0)
        case .top:    (y0, y1, a0, a1) = (CGFloat(pxH) - band, CGFloat(pxH), 0, 1)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let start = CGColor(colorSpace: colorSpace, components: [comps[0], comps[1], comps[2], a0])!
        let end = CGColor(colorSpace: colorSpace, components: [comps[0], comps[1], comps[2], a1])!
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: [start, end] as CFArray,
                                        locations: [0, 1]) else { return }
        cg.saveGState()
        cg.clip(to: CGRect(x: 0, y: y0, width: CGFloat(pxW), height: y1 - y0))
        cg.drawLinearGradient(gradient,
                              start: CGPoint(x: 0, y: y0),
                              end: CGPoint(x: 0, y: y1),
                              options: [])
        cg.restoreGState()
    }

    // MARK: - Text

    private static func drawText(cg: CGContext, pxW: Int, pxH: Int, scale: Double, dpi: Double,
                                 settings: PosterSettings, theme: Theme, center: Coordinate) {
        let W = CGFloat(pxW), H = CGFloat(pxH)
        let ptToPx = dpi / 72.0
        let textColor = theme.textColor

        // Base sizes (at 12-inch reference), scaled by min(h,w)/12, then pt → px.
        let baseMain: CGFloat = 60, baseSub: CGFloat = 22, baseCoords: CGFloat = 14, baseAttr: CGFloat = 8

        let family = settings.fontFamily
        func font(weight: NSFont.Weight, sizePt: CGFloat) -> NSFont {
            let sizePx = sizePt * CGFloat(scale) * ptToPx
            if let f = NSFont(name: resolveFontName(family: family, weight: weight), size: sizePx) {
                return f
            }
            return NSFont.systemFont(ofSize: sizePx, weight: weight)
        }

        let displayCity = settings.effectiveDisplayCity
        let displayCountry = settings.effectiveDisplayCountry
        let latin = isLatinScript(displayCity)

        // City name: Latin → uppercase + double-space letter spacing.
        let cityString = latin ? displayCity.uppercased().map { String($0) }.joined(separator: "  ")
                                : displayCity

        // Dynamic font-size reduction for long names (heuristic from original).
        var mainSizePt = baseMain
        let charCount = displayCity.count
        if charCount > 10 {
            let lengthFactor = 10.0 / Double(charCount)
            mainSizePt = CGFloat(max(Double(baseMain) * lengthFactor, 10.0))
        }

        func draw(_ text: String, font: NSFont, yFrac: CGFloat, alpha: CGFloat,
                  align: NSTextAlignment, xFrac: CGFloat) {
            let para = NSMutableParagraphStyle()
            para.alignment = align
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor.withAlphaComponent(alpha),
                .paragraphStyle: para,
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            let size = attr.size()
            let yBaseline = yFrac * H
            var x: CGFloat
            switch align {
            case .right: x = xFrac * W - size.width
            default:     x = xFrac * W - size.width / 2     // centered
            }
            attr.draw(at: CGPoint(x: x, y: yBaseline))
        }

        // City name — bold, y = 0.14
        draw(cityString, font: font(weight: .bold, sizePt: mainSizePt),
             yFrac: 0.14, alpha: 1.0, align: .center, xFrac: 0.5)

        // Country — light, uppercase, y = 0.10
        draw(displayCountry.uppercased(), font: font(weight: .light, sizePt: baseSub),
             yFrac: 0.10, alpha: 1.0, align: .center, xFrac: 0.5)

        // Coordinates — regular, alpha 0.7, y = 0.07
        let coords = formatCoordinates(center)
        draw(coords, font: font(weight: .regular, sizePt: baseCoords),
             yFrac: 0.07, alpha: 0.7, align: .center, xFrac: 0.5)

        // Separator line at y = 0.125, x 0.4 → 0.6, linewidth 1 * scale (points).
        cg.saveGState()
        cg.setStrokeColor(textColor.cgColor)
        cg.setLineWidth(max(0.5, CGFloat(scale) * ptToPx))
        cg.beginPath()
        cg.move(to: CGPoint(x: 0.4 * W, y: 0.125 * H))
        cg.addLine(to: CGPoint(x: 0.6 * W, y: 0.125 * H))
        cg.strokePath()
        cg.restoreGState()

        // Attribution — light, alpha 0.5, bottom-right (0.98, 0.02), fixed 8pt-ish.
        let attrFont = font(weight: .light, sizePt: baseAttr)
        draw("© OpenStreetMap contributors", font: attrFont,
             yFrac: 0.02, alpha: 0.5, align: .right, xFrac: 0.98)
    }

    /// Map a family + weight to a concrete PostScript/display font name when possible.
    private static func resolveFontName(family: String, weight: NSFont.Weight) -> String {
        let suffix: String
        switch weight {
        case .bold, .heavy, .black: suffix = " Bold"
        case .light, .thin, .ultraLight: suffix = " Light"
        default: suffix = ""
        }
        // Try "Family Bold"/"Family Light"; callers fall back to system font if nil.
        return family + suffix
    }

    private static func formatCoordinates(_ c: Coordinate) -> String {
        let ns = c.lat >= 0 ? "N" : "S"
        let ew = c.lon >= 0 ? "E" : "W"
        return String(format: "%.4f° %@ / %.4f° %@", abs(c.lat), ns, abs(c.lon), ew)
    }

    /// Heuristic Latin-script detection (Latin letters + basic Latin supplements).
    private static func isLatinScript(_ s: String) -> Bool {
        let letters = s.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return true }
        let latin = letters.filter { $0.value <= 0x024F }   // through Latin Extended-B
        return Double(latin.count) / Double(letters.count) >= 0.6
    }
}
