import UIKit
import ImageIO
import UniformTypeIdentifiers

/// Composes a template + filled content into a final bitmap at exact Instagram resolution (sRGB).
@MainActor
enum PostImageRenderer {

    /// - Parameters:
    ///   - filledTexts: text per zone id (open / pre-filled zones). Locked zones ignore this.
    ///   - filledImages: image per zone id (manual picks or chosen auto images).
    ///   - scale: 1.0 = exact Instagram pixels. Smaller values are used for fast previews.
    ///   - showPlaceholders: draw hints for empty slots (designer / preview only).
    static func render(template: PostTemplate,
                       filledTexts: [UUID: String],
                       filledImages: [UUID: UIImage],
                       set: TemplateSet,
                       store: TemplateStore,
                       size: InstagramSize,
                       scale: CGFloat = 1.0,
                       showPlaceholders: Bool = false) -> UIImage {
        let canvas = CGSize(width: CGFloat(size.width) * scale, height: CGFloat(size.height) * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        format.preferredRange = .standard // sRGB
        let renderer = UIGraphicsImageRenderer(size: canvas, format: format)
        // Font sizes are authored for a 1080 px wide canvas.
        let fontScale = canvas.width / 1080.0

        return renderer.image { ctx in
            let cg = ctx.cgContext
            UIColor(hex: set.brandKit.backgroundColorHex).setFill()
            cg.fill(CGRect(origin: .zero, size: canvas))

            for zone in template.sortedZones {
                let rect = CGRect(x: zone.normalizedRect.minX * canvas.width,
                                  y: zone.normalizedRect.minY * canvas.height,
                                  width: zone.normalizedRect.width * canvas.width,
                                  height: zone.normalizedRect.height * canvas.height)

                if let bg = zone.backgroundColorHex, !bg.isEmpty {
                    UIColor(hex: bg).setFill()
                    cg.fill(rect)
                }

                switch zone.zoneType {
                case .shape:
                    break
                case .image:
                    let img = filledImages[zone.id] ?? (zone.imageSlotType == .auto ? defaultAutoImage(for: zone, set: set, store: store) : nil)
                    if let img {
                        drawAspectFill(img, in: rect, context: cg)
                    } else if showPlaceholders {
                        drawPlaceholder(in: rect, label: zone.imageSlotType == .manual ? "Pick image" : "Add library images", context: cg, fontScale: fontScale)
                    } else {
                        UIColor(hex: set.brandKit.secondaryColorHex).setFill()
                        cg.fill(rect)
                    }
                case .logo:
                    if let logo = set.primaryLogo, let img = store.image(for: logo) {
                        drawAspectFit(img, in: rect)
                    } else if showPlaceholders {
                        drawPlaceholder(in: rect, label: "Logo", context: cg, fontScale: fontScale)
                    }
                case .text:
                    let text = resolvedText(for: zone, filled: filledTexts)
                    if text.isEmpty {
                        if showPlaceholders {
                            drawText(zone.placeholder.isEmpty ? zone.name : zone.placeholder, zone: zone, in: rect,
                                     fontScale: fontScale, alpha: 0.45)
                        }
                    } else {
                        drawText(text, zone: zone, in: rect, fontScale: fontScale, alpha: 1)
                    }
                }
            }
        }
    }

    /// Batch: one content fill → one image per selected size.
    static func renderAll(template: PostTemplate,
                          filledTexts: [UUID: String],
                          filledImages: [UUID: UIImage],
                          set: TemplateSet,
                          store: TemplateStore,
                          sizes: [InstagramSize]) -> [InstagramSize: UIImage] {
        var result: [InstagramSize: UIImage] = [:]
        for size in sizes {
            result[size] = render(template: template, filledTexts: filledTexts, filledImages: filledImages,
                                  set: set, store: store, size: size)
        }
        return result
    }

    static func resolvedText(for zone: TemplateZone, filled: [UUID: String]) -> String {
        switch zone.textSlotType {
        case .locked(let s): return s
        case .preFilled(let s): return filled[zone.id] ?? s
        case .open: return filled[zone.id] ?? ""
        }
    }

    /// Deterministic library pick so previews are stable until the user shuffles.
    static func defaultAutoImage(for zone: TemplateZone, set: TemplateSet, store: TemplateStore) -> UIImage? {
        let pool = set.autoSlotAssets
        guard !pool.isEmpty else { return nil }
        let index = (Int(zone.id.uuid.0) + Int(zone.id.uuid.1)) % pool.count
        return store.image(for: pool[index])
    }

    // MARK: - Encoding (sRGB JPEG / PNG)

    static func encode(_ image: UIImage, format: PostTemplate.ExportFormat, quality: Double) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let data = NSMutableData()
        let type = (format == .jpeg ? UTType.jpeg : UTType.png).identifier as CFString
        guard let dest = CGImageDestinationCreateWithData(data, type, 1, nil) else { return nil }
        var props: [CFString: Any] = [:]
        if format == .jpeg { props[kCGImageDestinationLossyCompressionQuality] = quality }
        // Convert to sRGB explicitly so Instagram shows the colors as designed.
        let srgb = CGColorSpace(name: CGColorSpace.sRGB)!
        let converted = cgImage.copy(colorSpace: srgb) ?? cgImage
        CGImageDestinationAddImage(dest, converted, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    // MARK: - Drawing helpers

    private static func drawAspectFill(_ image: UIImage, in rect: CGRect, context: CGContext) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = max(rect.width / image.size.width, rect.height / image.size.height)
        let w = image.size.width * scale, h = image.size.height * scale
        let drawRect = CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        context.saveGState()
        context.clip(to: rect)
        image.draw(in: drawRect)
        context.restoreGState()
    }

    private static func drawAspectFit(_ image: UIImage, in rect: CGRect) {
        guard image.size.width > 0, image.size.height > 0 else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let w = image.size.width * scale, h = image.size.height * scale
        image.draw(in: CGRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h))
    }

    private static func drawPlaceholder(in rect: CGRect, label: String, context: CGContext, fontScale: CGFloat) {
        UIColor.systemGray4.withAlphaComponent(0.6).setFill()
        context.fill(rect)
        UIColor.white.withAlphaComponent(0.7).setStroke()
        context.setLineWidth(max(1, 3 * fontScale))
        context.setLineDash(phase: 0, lengths: [12 * fontScale, 8 * fontScale])
        context.stroke(rect.insetBy(dx: 4 * fontScale, dy: 4 * fontScale))
        context.setLineDash(phase: 0, lengths: [])
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: max(8, 36 * fontScale), weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let s = NSAttributedString(string: label, attributes: attrs)
        let size = s.size()
        s.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2))
    }

    private static func drawText(_ text: String, zone: TemplateZone, in rect: CGRect, fontScale: CGFloat, alpha: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        switch zone.textAlignment {
        case .leading: paragraph.alignment = .left
        case .center: paragraph.alignment = .center
        case .trailing: paragraph.alignment = .right
        }
        paragraph.lineBreakMode = .byWordWrapping

        // Shrink-to-fit: reduce font until the text fits the zone (down to 35 %).
        var pointSize = zone.fontSize * fontScale
        let minSize = pointSize * 0.35
        var attributed = NSAttributedString()
        var bounds = CGRect.zero
        repeat {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: zone.fontConfig.uiFont(size: pointSize),
                .foregroundColor: UIColor(hex: zone.textColorHex).withAlphaComponent(alpha),
                .paragraphStyle: paragraph
            ]
            attributed = NSAttributedString(string: text, attributes: attrs)
            bounds = attributed.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                             options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            if bounds.height <= rect.height { break }
            pointSize *= 0.92
        } while pointSize > minSize

        attributed.draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
    }
}
