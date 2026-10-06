import UIKit

/// A font definition used by the brand kit and text zones.
struct FontConfig: Codable, Hashable {
    /// PostScript or family name. Empty string means the system font.
    var fontName: String
    var size: CGFloat
    /// One of: regular, medium, semibold, bold, heavy, light
    var weight: String

    static let weights = ["light", "regular", "medium", "semibold", "bold", "heavy"]

    var uiWeight: UIFont.Weight {
        switch weight {
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        default: return .regular
        }
    }

    /// Resolves to a UIFont at the given point size (size override allows zone-specific sizes).
    func uiFont(size overrideSize: CGFloat? = nil) -> UIFont {
        let pointSize = overrideSize ?? size
        if !fontName.isEmpty, let custom = UIFont(name: fontName, size: pointSize) {
            return custom
        }
        return UIFont.systemFont(ofSize: pointSize, weight: uiWeight)
    }

    static let defaultHeading = FontConfig(fontName: "", size: 96, weight: "bold")
    static let defaultBody = FontConfig(fontName: "", size: 44, weight: "regular")
}
