import Foundation

/// A rendered post in the history. The image is stored as a file in Documents/Posts.
/// `templateSnapshot` keeps an exact copy of the template as it was when the post was generated.
struct GeneratedPost: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var templateSetName: String
    var templateName: String
    var templateID: UUID
    var instagramSize: InstagramSize
    var imageFileName: String
    var createdAt: Date = Date()
    var templateSnapshot: PostTemplate
    var filledTexts: [String: String] = [:]
}
