import CoreGraphics

/// All supported Instagram output formats with their exact pixel dimensions.
enum InstagramSize: String, Codable, CaseIterable, Identifiable, Hashable {
    case square
    case portrait
    case landscape
    case story
    case carousel

    var id: String { rawValue }

    var width: Int { 1080 }

    var height: Int {
        switch self {
        case .square, .carousel: return 1080
        case .portrait: return 1350
        case .landscape: return 566
        case .story: return 1920
        }
    }

    var pixelSize: CGSize { CGSize(width: width, height: height) }

    /// width / height
    var aspectRatio: CGFloat { CGFloat(width) / CGFloat(height) }

    var displayName: String {
        switch self {
        case .square: return "Square"
        case .portrait: return "Portrait"
        case .landscape: return "Landscape"
        case .story: return "Story / Reel"
        case .carousel: return "Carousel"
        }
    }

    var ratioLabel: String {
        switch self {
        case .square, .carousel: return "1:1"
        case .portrait: return "4:5"
        case .landscape: return "1.91:1"
        case .story: return "9:16"
        }
    }

    var dimensionLabel: String { "\(width) × \(height)" }

    var systemImage: String {
        switch self {
        case .square: return "square"
        case .portrait: return "rectangle.portrait"
        case .landscape: return "rectangle"
        case .story: return "iphone"
        case .carousel: return "square.stack"
        }
    }

    /// Areas covered by Instagram's own UI on Stories / Reels (top bar + reply bar),
    /// expressed as normalized heights. Content should stay out of these.
    var unsafeTopFraction: CGFloat { self == .story ? 250.0 / 1920.0 : 0 }
    var unsafeBottomFraction: CGFloat { self == .story ? 340.0 / 1920.0 : 0 }
}
