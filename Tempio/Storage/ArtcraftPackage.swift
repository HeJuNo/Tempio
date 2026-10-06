import Foundation
import UIKit

/// `.artcraft` = a ZIP archive containing a complete, self-contained Template Set:
///
///     set.json          full Template Set (used for import)
///     brand.json        brand kit only (human readable)
///     templates/*.json  one file per template
///     assets/*          logos, brand art, backgrounds
///     fonts/*           imported .ttf / .otf files
///     preview.png       thumbnail of the first template
@MainActor
enum ArtcraftPackage {
    enum PackageError: LocalizedError {
        case missingSetFile, invalidArchive
        var errorDescription: String? {
            switch self {
            case .missingSetFile: return "The file is not a valid .artcraft package (set.json missing)."
            case .invalidArchive: return "The .artcraft archive is damaged or unsupported."
            }
        }
    }

    static func export(set s: TemplateSet, store: TemplateStore) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        var entries: [(String, Data)] = []
        entries.append(("set.json", try encoder.encode(s)))
        entries.append(("brand.json", try encoder.encode(s.brandKit)))
        for t in s.templates {
            entries.append(("templates/\(t.id.uuidString).json", try encoder.encode(t)))
        }
        for a in s.assets {
            if let data = try? Data(contentsOf: store.assetsDir.appendingPathComponent(a.fileName)) {
                entries.append(("assets/\(a.fileName)", data))
            }
        }
        for f in s.customFontFiles {
            if let data = try? Data(contentsOf: store.fontsDir.appendingPathComponent(f)) {
                entries.append(("fonts/\(f)", data))
            }
        }
        if let first = s.templates.first {
            let preview = PostImageRenderer.render(template: first, filledTexts: [:], filledImages: [:],
                                                   set: s, store: store, size: first.instagramSize, scale: 0.33)
            if let png = preview.pngData() { entries.append(("preview.png", png)) }
        }

        let safeName = s.name.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(safeName.isEmpty ? "TemplateSet" : safeName).artcraft")
        try ZipArchive.write(entries: entries).write(to: url, options: .atomic)
        return url
    }

    static func importPackage(from url: URL, store: TemplateStore) throws -> TemplateSet {
        let data = try Data(contentsOf: url)
        let entries = try ZipArchive.read(data)
        guard let setData = entries["set.json"] else { throw PackageError.missingSetFile }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var s = try decoder.decode(TemplateSet.self, from: setData)

        // Fresh identity so the same package can be imported more than once.
        s.id = UUID()
        s.name = store.sets.contains(where: { $0.name == s.name }) ? "\(s.name) (Imported)" : s.name

        // Remap asset files to new names so sets never share files.
        var newAssets: [BrandAsset] = []
        for var a in s.assets {
            guard let bytes = entries["assets/\(a.fileName)"] else { continue }
            let ext = (a.fileName as NSString).pathExtension
            let newName = "\(UUID().uuidString).\(ext.isEmpty ? "png" : ext)"
            try bytes.write(to: store.assetsDir.appendingPathComponent(newName), options: .atomic)
            a.id = UUID()
            a.fileName = newName
            newAssets.append(a)
        }
        s.assets = newAssets

        for f in s.customFontFiles {
            guard let bytes = entries["fonts/\(f)"] else { continue }
            let dest = store.fontsDir.appendingPathComponent(f)
            if !FileManager.default.fileExists(atPath: dest.path) {
                try bytes.write(to: dest, options: .atomic)
            }
        }
        store.registerAllFonts()
        return s
    }
}

/// Minimal ZIP writer/reader using the "stored" method (no compression).
/// Produces standard archives that open in Finder / Files / any unzip tool.
enum ZipArchive {
    private static let crcTable: [UInt32] = (0..<256).map { i -> UInt32 in
        var c = UInt32(i)
        for _ in 0..<8 { c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1) }
        return c
    }

    static func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data { crc = crcTable[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFFFFFF
    }

    private static func le16(_ v: UInt16, into d: inout Data) { d.append(UInt8(v & 0xFF)); d.append(UInt8(v >> 8)) }
    private static func le32(_ v: UInt32, into d: inout Data) {
        for shift in stride(from: 0, to: 32, by: 8) { d.append(UInt8((v >> UInt32(shift)) & 0xFF)) }
    }

    static func write(entries: [(String, Data)]) -> Data {
        var out = Data()
        var central = Data()
        for (name, content) in entries {
            let nameData = Data(name.utf8)
            let crc = crc32(content)
            let offset = UInt32(out.count)
            // Local file header
            le32(0x04034b50, into: &out)
            le16(20, into: &out)          // version needed
            le16(0x0800, into: &out)      // flags: UTF-8 names
            le16(0, into: &out)           // method: stored
            le16(0, into: &out); le16(0x21, into: &out) // time / date (1980-01-01)
            le32(crc, into: &out)
            le32(UInt32(content.count), into: &out)
            le32(UInt32(content.count), into: &out)
            le16(UInt16(nameData.count), into: &out)
            le16(0, into: &out)
            out.append(nameData)
            out.append(content)
            // Central directory header
            le32(0x02014b50, into: &central)
            le16(20, into: &central); le16(20, into: &central)
            le16(0x0800, into: &central); le16(0, into: &central)
            le16(0, into: &central); le16(0x21, into: &central)
            le32(crc, into: &central)
            le32(UInt32(content.count), into: &central)
            le32(UInt32(content.count), into: &central)
            le16(UInt16(nameData.count), into: &central)
            le16(0, into: &central); le16(0, into: &central)
            le16(0, into: &central); le16(0, into: &central)
            le32(0, into: &central)
            le32(offset, into: &central)
            central.append(nameData)
        }
        let centralOffset = UInt32(out.count)
        out.append(central)
        le32(0x06054b50, into: &out)
        le16(0, into: &out); le16(0, into: &out)
        le16(UInt16(entries.count), into: &out); le16(UInt16(entries.count), into: &out)
        le32(UInt32(central.count), into: &out)
        le32(centralOffset, into: &out)
        le16(0, into: &out)
        return out
    }

    /// Reads stored (uncompressed) entries via the central directory.
    static func read(_ data: Data) throws -> [String: Data] {
        let bytes = [UInt8](data)
        func u16(_ o: Int) -> Int { Int(bytes[o]) | Int(bytes[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }

        guard bytes.count >= 22 else { throw ArtcraftPackage.PackageError.invalidArchive }
        var eocd = -1
        var i = bytes.count - 22
        while i >= max(0, bytes.count - 65557) {
            if u32(i) == 0x06054b50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw ArtcraftPackage.PackageError.invalidArchive }
        let count = u16(eocd + 10)
        var p = u32(eocd + 16)
        var result: [String: Data] = [:]
        for _ in 0..<count {
            guard p + 46 <= bytes.count, u32(p) == 0x02014b50 else { throw ArtcraftPackage.PackageError.invalidArchive }
            let method = u16(p + 10)
            let compSize = u32(p + 20)
            let nameLen = u16(p + 28), extraLen = u16(p + 30), commentLen = u16(p + 32)
            let localOffset = u32(p + 42)
            let name = String(decoding: bytes[(p + 46)..<(p + 46 + nameLen)], as: UTF8.self)
            guard method == 0 else { throw ArtcraftPackage.PackageError.invalidArchive }
            let lNameLen = u16(localOffset + 26), lExtraLen = u16(localOffset + 28)
            let start = localOffset + 30 + lNameLen + lExtraLen
            guard start + compSize <= bytes.count else { throw ArtcraftPackage.PackageError.invalidArchive }
            if !name.hasSuffix("/") { result[name] = Data(bytes[start..<(start + compSize)]) }
            p += 46 + nameLen + extraLen + commentLen
        }
        return result
    }
}
