import Foundation

/// A complete brand package: brand kit, asset library, custom fonts and templates.
struct TemplateSet: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var brandKit: BrandKit = .default
    var templates: [PostTemplate] = []
    var assets: [BrandAsset] = []
    /// File names of imported font files stored in Documents/Fonts.
    var customFontFiles: [String] = []
    var isLocked: Bool = false
    var passwordHash: String? = nil
    var createdAt: Date = Date()

    func assets(role: BrandAsset.AssetRole) -> [BrandAsset] { assets.filter { $0.assetRole == role } }

    /// Assets eligible for auto image slots (backgrounds, brand art, photos).
    var autoSlotAssets: [BrandAsset] {
        assets.filter { $0.useForAutoSlots && $0.assetRole != .logo }
    }

    var primaryLogo: BrandAsset? { assets(role: .logo).first }
}
