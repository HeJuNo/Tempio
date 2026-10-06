import Foundation

struct BrandKit: Codable, Hashable {
    var primaryColorHex: String
    var secondaryColorHex: String
    var accentColorHex: String
    var backgroundColorHex: String
    var headingFont: FontConfig
    var subheadingFont: FontConfig
    var bodyFont: FontConfig
    var moodKeywords: [String]
    /// Pre-fill values usable by pre-filled text slots (e.g. website, handle).
    var handle: String
    var website: String
    var tagline: String

    static let `default` = BrandKit(
        primaryColorHex: "#7B2FBE",
        secondaryColorHex: "#1E1B2E",
        accentColorHex: "#F5B841",
        backgroundColorHex: "#121018",
        headingFont: .defaultHeading,
        subheadingFont: FontConfig(fontName: "", size: 56, weight: "semibold"),
        bodyFont: .defaultBody,
        moodKeywords: [],
        handle: "",
        website: "",
        tagline: ""
    )

    var palette: [String] { [primaryColorHex, secondaryColorHex, accentColorHex, backgroundColorHex, "#FFFFFF", "#000000"] }
}
