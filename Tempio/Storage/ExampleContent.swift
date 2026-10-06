import UIKit

/// Builds the pre-loaded "Getartcraft" example Template Set on first launch,
/// including generated brand art so auto image slots work out of the box.
@MainActor
enum ExampleContent {
    static func makeGetartcraftSet(store: TemplateStore) -> TemplateSet {
        var kit = BrandKit.default
        kit.primaryColorHex = "#7B2FBE"
        kit.secondaryColorHex = "#2A1745"
        kit.accentColorHex = "#F5B841"
        kit.backgroundColorHex = "#120C1C"
        kit.headingFont = FontConfig(fontName: "AvenirNext-Bold", size: 96, weight: "bold")
        kit.subheadingFont = FontConfig(fontName: "AvenirNext-DemiBold", size: 54, weight: "semibold")
        kit.bodyFont = FontConfig(fontName: "AvenirNext-Regular", size: 44, weight: "regular")
        kit.moodKeywords = ["creative", "bold", "artistic", "open-source"]
        kit.handle = "@getartcraft"
        kit.website = "getartcraft.com"
        kit.tagline = "Controllable AI for Artists"

        var set = TemplateSet(name: "Getartcraft", brandKit: kit)
        set.id = UUID()

        // Generated brand art (gradients + brush strokes) and a logo.
        let artSpecs: [(String, [UIColor])] = [
            ("Violet Dusk", [UIColor(hex: "#7B2FBE"), UIColor(hex: "#120C1C")]),
            ("Golden Hour", [UIColor(hex: "#F5B841"), UIColor(hex: "#7B2FBE")]),
            ("Night Ink", [UIColor(hex: "#2A1745"), UIColor(hex: "#05030A")])
        ]
        for (index, spec) in artSpecs.enumerated() {
            let img = brandArt(colors: spec.1, seed: index)
            if let data = img.jpegData(compressionQuality: 0.9) {
                let fileName = "\(UUID().uuidString).jpg"
                try? data.write(to: store.assetsDir.appendingPathComponent(fileName), options: .atomic)
                set.assets.append(BrandAsset(name: spec.0, fileName: fileName, assetRole: .brandArt))
            }
        }
        if let logoData = logo().pngData() {
            let fileName = "\(UUID().uuidString).png"
            try? logoData.write(to: store.assetsDir.appendingPathComponent(fileName), options: .atomic)
            set.assets.append(BrandAsset(name: "Logo", fileName: fileName, assetRole: .logo, useForAutoSlots: false))
        }

        // 1) Square: full-bleed auto background + title + subtitle
        let square = PostTemplate(
            name: "Product Launch",
            instagramSize: .square,
            zones: [
                TemplateZone(name: "Background", zoneType: .image, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                             layerOrder: 0, imageSlotType: .auto),
                TemplateZone(name: "Shade", zoneType: .shape, normalizedRect: CGRect(x: 0, y: 0.52, width: 1, height: 0.48),
                             layerOrder: 1, backgroundColorHex: "#00000088"),
                TemplateZone(name: "Title", zoneType: .text, normalizedRect: CGRect(x: 0.07, y: 0.58, width: 0.86, height: 0.2),
                             layerOrder: 2, textSlotType: .open, fontName: kit.headingFont.fontName, fontSize: 104,
                             fontWeight: "bold", textColorHex: "#FFFFFF", placeholder: "Title"),
                TemplateZone(name: "Subtitle", zoneType: .text, normalizedRect: CGRect(x: 0.07, y: 0.79, width: 0.86, height: 0.1),
                             layerOrder: 3, textSlotType: .open, fontName: kit.subheadingFont.fontName, fontSize: 52,
                             fontWeight: "semibold", textColorHex: kit.accentColorHex, placeholder: "Subtitle"),
                TemplateZone(name: "Handle", zoneType: .text, normalizedRect: CGRect(x: 0.07, y: 0.9, width: 0.6, height: 0.06),
                             layerOrder: 4, textSlotType: .preFilled(kit.handle), fontName: kit.bodyFont.fontName, fontSize: 36,
                             fontWeight: "regular", textColorHex: "#FFFFFFCC", placeholder: "@handle"),
                TemplateZone(name: "Logo", zoneType: .logo, normalizedRect: CGRect(x: 0.83, y: 0.04, width: 0.13, height: 0.13),
                             layerOrder: 5)
            ]
        )

        // 2) Story: photo + text, keeps content inside the safe zone.
        let story = PostTemplate(
            name: "Story Announcement",
            instagramSize: .story,
            zones: [
                TemplateZone(name: "Background", zoneType: .image, normalizedRect: CGRect(x: 0, y: 0, width: 1, height: 1),
                             layerOrder: 0, imageSlotType: .auto),
                TemplateZone(name: "Photo", zoneType: .image, normalizedRect: CGRect(x: 0.1, y: 0.18, width: 0.8, height: 0.42),
                             layerOrder: 1, imageSlotType: .manual),
                TemplateZone(name: "Kicker", zoneType: .text, normalizedRect: CGRect(x: 0.1, y: 0.62, width: 0.8, height: 0.04),
                             layerOrder: 2, textSlotType: .locked("NEW ON ARTCRAFT"), fontName: kit.subheadingFont.fontName,
                             fontSize: 40, fontWeight: "semibold", textColorHex: kit.accentColorHex),
                TemplateZone(name: "Title", zoneType: .text, normalizedRect: CGRect(x: 0.1, y: 0.66, width: 0.8, height: 0.1),
                             layerOrder: 3, textSlotType: .open, fontName: kit.headingFont.fontName, fontSize: 96,
                             fontWeight: "bold", textColorHex: "#FFFFFF", placeholder: "Title"),
                TemplateZone(name: "Text", zoneType: .text, normalizedRect: CGRect(x: 0.1, y: 0.76, width: 0.8, height: 0.06),
                             layerOrder: 4, textSlotType: .open, fontName: kit.bodyFont.fontName, fontSize: 44,
                             fontWeight: "regular", textColorHex: "#FFFFFFDD", placeholder: "Body text"),
                TemplateZone(name: "Logo", zoneType: .logo, normalizedRect: CGRect(x: 0.42, y: 0.08, width: 0.16, height: 0.07),
                             layerOrder: 5)
            ]
        )
        set.templates = [square, story]
        return set
    }

    private static func brandArt(colors: [UIColor], seed: Int) -> UIImage {
        let size = CGSize(width: 1080, height: 1350)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            let cg = ctx.cgContext
            let cgColors = colors.map { $0.cgColor } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: cgColors, locations: nil) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
            }
            // Brush strokes
            for i in 0..<5 {
                let path = UIBezierPath()
                let y = CGFloat(200 + i * 220 + seed * 40)
                path.move(to: CGPoint(x: -50, y: y + 180))
                path.addCurve(to: CGPoint(x: size.width + 50, y: y - 120),
                              controlPoint1: CGPoint(x: 300, y: y - 80 + CGFloat(seed * 30)),
                              controlPoint2: CGPoint(x: 700, y: y + 200))
                path.lineWidth = CGFloat(30 + (i * 17 + seed * 11) % 70)
                path.lineCapStyle = .round
                UIColor.white.withAlphaComponent(0.05 + CGFloat(i) * 0.025).setStroke()
                path.stroke()
            }
        }
    }

    private static func logo() -> UIImage {
        let size = CGSize(width: 400, height: 400)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let frame = UIBezierPath(roundedRect: CGRect(x: 40, y: 40, width: 320, height: 320), cornerRadius: 60)
            frame.lineWidth = 22
            UIColor.white.setStroke()
            frame.stroke()
            let stroke = UIBezierPath()
            stroke.move(to: CGPoint(x: 90, y: 300))
            stroke.addCurve(to: CGPoint(x: 320, y: 100), controlPoint1: CGPoint(x: 160, y: 180), controlPoint2: CGPoint(x: 240, y: 230))
            stroke.lineWidth = 44
            stroke.lineCapStyle = .round
            UIColor(hex: "#F5B841").setStroke()
            stroke.stroke()
        }
    }
}
