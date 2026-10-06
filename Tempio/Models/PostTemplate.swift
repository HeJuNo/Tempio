import Foundation

struct PostTemplate: Codable, Identifiable, Hashable {
    enum ExportFormat: String, Codable, CaseIterable, Identifiable {
        case jpeg, png
        var id: String { rawValue }
        var fileExtension: String { self == .jpeg ? "jpg" : "png" }
    }

    var id: UUID = UUID()
    var name: String
    /// The base size the template was designed for. Other sizes adapt via normalized zones.
    var instagramSize: InstagramSize
    var zones: [TemplateZone]
    var exportFormat: ExportFormat = .jpeg
    var jpegQuality: Double = 0.92
    var updatedAt: Date = Date()

    var sortedZones: [TemplateZone] { zones.sorted { $0.layerOrder < $1.layerOrder } }

    /// Re-number layer orders 0...n-1 keeping the current visual order.
    mutating func normalizeLayers() {
        let ordered = sortedZones
        for (index, zone) in ordered.enumerated() {
            if let i = zones.firstIndex(where: { $0.id == zone.id }) {
                zones[i].layerOrder = index
            }
        }
    }
}
