import CoreGraphics

/// Starting layouts for new templates. Users pick one, then fine-tune on the canvas.
enum PresetLayout: String, CaseIterable, Identifiable {
    case fullBleed, splitLeftRight, grid2, grid3, topBannerText, centered, editorial, blank

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fullBleed: return "Full Bleed"
        case .splitLeftRight: return "Split"
        case .grid2: return "Grid 2"
        case .grid3: return "Grid 3"
        case .topBannerText: return "Banner + Text"
        case .centered: return "Centered"
        case .editorial: return "Editorial"
        case .blank: return "Blank"
        }
    }

    func makeZones(brandKit: BrandKit) -> [TemplateZone] {
        let headingFont = brandKit.headingFont
        let bodyFont = brandKit.bodyFont

        func image(_ name: String, _ r: CGRect, _ slot: TemplateZone.ImageSlotType, _ layer: Int) -> TemplateZone {
            TemplateZone(name: name, zoneType: .image, normalizedRect: r, layerOrder: layer, imageSlotType: slot)
        }
        func text(_ name: String, _ r: CGRect, heading: Bool, slot: TemplateZone.TextSlotType = .open,
                  color: String = "#FFFFFF", align: TemplateZone.TextAlignment = .leading,
                  placeholder: String, layer: Int) -> TemplateZone {
            let f = heading ? headingFont : bodyFont
            return TemplateZone(name: name, zoneType: .text, normalizedRect: r, layerOrder: layer,
                                textSlotType: slot, fontName: f.fontName, fontSize: f.size,
                                fontWeight: f.weight, textColorHex: color, textAlignment: align,
                                placeholder: placeholder)
        }
        func shape(_ name: String, _ r: CGRect, _ hex: String, _ layer: Int) -> TemplateZone {
            TemplateZone(name: name, zoneType: .shape, normalizedRect: r, layerOrder: layer, backgroundColorHex: hex)
        }
        func logo(_ r: CGRect, _ layer: Int) -> TemplateZone {
            TemplateZone(name: "Logo", zoneType: .logo, normalizedRect: r, layerOrder: layer)
        }

        let handle = brandKit.handle.isEmpty ? "@yourbrand" : brandKit.handle

        switch self {
        case .fullBleed:
            return [
                image("Background", CGRect(x: 0, y: 0, width: 1, height: 1), .auto, 0),
                shape("Overlay", CGRect(x: 0, y: 0.55, width: 1, height: 0.45), "#00000099", 1),
                text("Title", CGRect(x: 0.07, y: 0.6, width: 0.86, height: 0.18), heading: true, placeholder: "Title", layer: 2),
                text("Subtitle", CGRect(x: 0.07, y: 0.79, width: 0.86, height: 0.12), heading: false, placeholder: "Subtitle", layer: 3),
                logo(CGRect(x: 0.82, y: 0.04, width: 0.14, height: 0.1), 4)
            ]
        case .splitLeftRight:
            return [
                shape("Panel", CGRect(x: 0, y: 0, width: 1, height: 1), brandKit.primaryColorHex, 0),
                image("Photo", CGRect(x: 0.5, y: 0, width: 0.5, height: 1), .manual, 1),
                text("Title", CGRect(x: 0.05, y: 0.25, width: 0.4, height: 0.25), heading: true, placeholder: "Title", layer: 2),
                text("Text", CGRect(x: 0.05, y: 0.52, width: 0.4, height: 0.3), heading: false, placeholder: "Body text", layer: 3)
            ]
        case .grid2:
            return [
                image("Image 1", CGRect(x: 0, y: 0, width: 0.5, height: 0.75), .manual, 0),
                image("Image 2", CGRect(x: 0.5, y: 0, width: 0.5, height: 0.75), .auto, 1),
                shape("Footer", CGRect(x: 0, y: 0.75, width: 1, height: 0.25), brandKit.secondaryColorHex, 2),
                text("Title", CGRect(x: 0.06, y: 0.78, width: 0.88, height: 0.12), heading: true, placeholder: "Title", layer: 3),
                text("Handle", CGRect(x: 0.06, y: 0.9, width: 0.88, height: 0.07), heading: false,
                     slot: .preFilled(handle), color: brandKit.accentColorHex, placeholder: "@handle", layer: 4)
            ]
        case .grid3:
            return [
                image("Image 1", CGRect(x: 0, y: 0, width: 0.6, height: 1), .manual, 0),
                image("Image 2", CGRect(x: 0.6, y: 0, width: 0.4, height: 0.5), .auto, 1),
                image("Image 3", CGRect(x: 0.6, y: 0.5, width: 0.4, height: 0.5), .auto, 2),
                shape("Label", CGRect(x: 0.04, y: 0.78, width: 0.52, height: 0.18), brandKit.primaryColorHex, 3),
                text("Title", CGRect(x: 0.07, y: 0.8, width: 0.47, height: 0.14), heading: true, placeholder: "Title", layer: 4)
            ]
        case .topBannerText:
            return [
                shape("Background", CGRect(x: 0, y: 0, width: 1, height: 1), brandKit.backgroundColorHex, 0),
                image("Banner", CGRect(x: 0, y: 0, width: 1, height: 0.55), .manual, 1),
                text("Title", CGRect(x: 0.07, y: 0.6, width: 0.86, height: 0.14), heading: true, placeholder: "Title", layer: 2),
                text("Subtitle", CGRect(x: 0.07, y: 0.74, width: 0.86, height: 0.08), heading: false,
                     color: brandKit.accentColorHex, placeholder: "Subtitle", layer: 3),
                text("Text", CGRect(x: 0.07, y: 0.83, width: 0.86, height: 0.13), heading: false, placeholder: "Body text", layer: 4)
            ]
        case .centered:
            return [
                image("Background", CGRect(x: 0, y: 0, width: 1, height: 1), .auto, 0),
                shape("Card", CGRect(x: 0.1, y: 0.3, width: 0.8, height: 0.4), "#000000AA", 1),
                text("Title", CGRect(x: 0.14, y: 0.36, width: 0.72, height: 0.16), heading: true, align: .center, placeholder: "Title", layer: 2),
                text("Subtitle", CGRect(x: 0.14, y: 0.53, width: 0.72, height: 0.1), heading: false, align: .center, placeholder: "Subtitle", layer: 3)
            ]
        case .editorial:
            return [
                shape("Paper", CGRect(x: 0, y: 0, width: 1, height: 1), "#F4F1EA", 0),
                image("Hero", CGRect(x: 0.08, y: 0.08, width: 0.84, height: 0.55), .manual, 1),
                text("Kicker", CGRect(x: 0.08, y: 0.66, width: 0.84, height: 0.05), heading: false,
                     slot: .locked("FEATURE"), color: brandKit.primaryColorHex, placeholder: "", layer: 2),
                text("Title", CGRect(x: 0.08, y: 0.71, width: 0.84, height: 0.14), heading: true, color: "#111111", placeholder: "Title", layer: 3),
                text("Text", CGRect(x: 0.08, y: 0.85, width: 0.84, height: 0.1), heading: false, color: "#333333", placeholder: "Body text", layer: 4)
            ]
        case .blank:
            return [shape("Background", CGRect(x: 0, y: 0, width: 1, height: 1), brandKit.backgroundColorHex, 0)]
        }
    }
}
