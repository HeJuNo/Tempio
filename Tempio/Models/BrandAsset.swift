import Foundation

/// An image belonging to a Template Set. Image bytes are stored as a file in the
/// app's Documents/Assets folder (referenced by `fileName`) to keep JSON small.
struct BrandAsset: Codable, Identifiable, Hashable {
    enum AssetRole: String, Codable, CaseIterable, Identifiable {
        case logo, brandArt, background, photo
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .logo: return "Logo"
            case .brandArt: return "Brand Art"
            case .background: return "Background"
            case .photo: return "Photo"
            }
        }
    }

    var id: UUID = UUID()
    var name: String
    var fileName: String
    var assetRole: AssetRole
    /// If true the asset can be pulled automatically into auto image slots.
    var useForAutoSlots: Bool = true
}
