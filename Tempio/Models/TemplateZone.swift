import CoreGraphics
import Foundation

/// A rectangular region on a template. Rect values are normalized (0...1) so the
/// same zone layout adapts to every Instagram size.
struct TemplateZone: Codable, Identifiable, Hashable {
    enum ZoneType: String, Codable, CaseIterable, Identifiable {
        case image, text, logo, shape
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .image: return "Image"
            case .text: return "Text"
            case .logo: return "Logo"
            case .shape: return "Color Block"
            }
        }
        var systemImage: String {
            switch self {
            case .image: return "photo"
            case .text: return "textformat"
            case .logo: return "seal"
            case .shape: return "square.fill"
            }
        }
    }

    enum TextSlotType: Codable, Hashable {
        /// Baked into the template, never changes.
        case locked(String)
        /// Default value (e.g. from brand kit), editable at creation time.
        case preFilled(String)
        /// Blank, filled fresh every time.
        case open

        var kindName: String {
            switch self {
            case .locked: return "Locked"
            case .preFilled: return "Pre-filled"
            case .open: return "Open"
            }
        }

        var defaultText: String {
            switch self {
            case .locked(let s), .preFilled(let s): return s
            case .open: return ""
            }
        }
    }

    enum ImageSlotType: String, Codable, CaseIterable, Identifiable {
        /// Pulled automatically from the set's asset library (shuffleable).
        case auto
        /// User picks from camera roll each time.
        case manual
        var id: String { rawValue }
        var displayName: String { self == .auto ? "Auto (Library)" : "Manual (Pick)" }
    }

    enum TextAlignment: String, Codable, CaseIterable, Identifiable {
        case leading, center, trailing
        var id: String { rawValue }
    }

    var id: UUID = UUID()
    var name: String = "Zone"
    var zoneType: ZoneType
    var normalizedRect: CGRect
    var layerOrder: Int = 0
    var isLocked: Bool = false
    var textSlotType: TextSlotType = .open
    var imageSlotType: ImageSlotType = .manual
    var fontName: String = ""
    var fontSize: CGFloat = 64
    var fontWeight: String = "bold"
    var textColorHex: String = "#FFFFFF"
    var backgroundColorHex: String? = nil
    var textAlignment: TextAlignment = .leading
    /// Placeholder hint shown to the user in the content form.
    var placeholder: String = ""
    var currentText: String? = nil

    var fontConfig: FontConfig {
        FontConfig(fontName: fontName, size: fontSize, weight: fontWeight)
    }

    /// Clamp the rect so the zone always stays (mostly) on the canvas.
    mutating func clampRect() {
        var r = normalizedRect
        r.size.width = min(max(r.size.width, 0.05), 1.0)
        r.size.height = min(max(r.size.height, 0.03), 1.0)
        r.origin.x = min(max(r.origin.x, 0), 1 - r.size.width)
        r.origin.y = min(max(r.origin.y, 0), 1 - r.size.height)
        normalizedRect = r
    }
}
