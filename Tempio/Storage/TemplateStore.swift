import SwiftUI
import UIKit
import CoreText

/// Central app state. Persists Template Sets and post history as JSON in the app's
/// Documents directory; image bytes live in Documents/Assets and Documents/Posts.
@MainActor
final class TemplateStore: ObservableObject {
    @Published var sets: [TemplateSet] = []
    @Published var generatedPosts: [GeneratedPost] = []
    @Published var activeSetID: UUID?
    /// Sets unlocked with their password during this session.
    @Published var unlockedSetIDs: Set<UUID> = []
    @Published var lastError: String?

    private var didLoad = false
    private let fm = FileManager.default
    private var imageCache: [String: UIImage] = [:]

    // MARK: - Paths

    var documentsURL: URL { fm.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    var assetsDir: URL { documentsURL.appendingPathComponent("Assets", isDirectory: true) }
    var postsDir: URL { documentsURL.appendingPathComponent("Posts", isDirectory: true) }
    var fontsDir: URL { documentsURL.appendingPathComponent("Fonts", isDirectory: true) }
    private var setsFile: URL { documentsURL.appendingPathComponent("template_sets.json") }
    private var postsFile: URL { documentsURL.appendingPathComponent("generated_posts.json") }

    var activeSet: TemplateSet? {
        if let id = activeSetID, let s = sets.first(where: { $0.id == id }) { return s }
        return sets.first
    }

    // MARK: - Load / Save

    func loadAll() {
        guard !didLoad else { return }
        didLoad = true
        for dir in [assetsDir, postsDir, fontsDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: setsFile),
           let decoded = try? decoder.decode([TemplateSet].self, from: data) {
            sets = decoded
        }
        if let data = try? Data(contentsOf: postsFile),
           let decoded = try? decoder.decode([GeneratedPost].self, from: data) {
            generatedPosts = decoded
        }
        registerAllFonts()
        if sets.isEmpty {
            sets = [ExampleContent.makeGetartcraftSet(store: self)]
            saveSets()
        }
        if activeSetID == nil { activeSetID = sets.first?.id }
    }

    func saveSets() {
        write(sets, to: setsFile)
    }

    func savePosts() {
        write(generatedPosts, to: postsFile)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            lastError = "Saving failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Template Sets

    func set(id: UUID) -> TemplateSet? { sets.first { $0.id == id } }

    @discardableResult
    func addSet(name: String) -> TemplateSet {
        let new = TemplateSet(name: name.isEmpty ? "New Set" : name)
        sets.append(new)
        activeSetID = new.id
        saveSets()
        return new
    }

    func deleteSet(id: UUID) {
        guard let s = set(id: id) else { return }
        for asset in s.assets { try? fm.removeItem(at: assetsDir.appendingPathComponent(asset.fileName)) }
        sets.removeAll { $0.id == id }
        if activeSetID == id { activeSetID = sets.first?.id }
        saveSets()
    }

    func updateSet(_ updated: TemplateSet) {
        guard let i = sets.firstIndex(where: { $0.id == updated.id }) else { return }
        sets[i] = updated
        saveSets()
    }

    /// Binding into a set by id, persisting on every write.
    func binding(forSet id: UUID) -> Binding<TemplateSet>? {
        guard set(id: id) != nil else { return nil }
        return Binding(
            get: { self.set(id: id) ?? TemplateSet(name: "") },
            set: { self.updateSet($0) }
        )
    }

    // MARK: - Locking

    func canEdit(_ s: TemplateSet) -> Bool { !s.isLocked || unlockedSetIDs.contains(s.id) }

    func lock(setID: UUID, password: String) {
        guard var s = set(id: setID) else { return }
        s.isLocked = true
        s.passwordHash = password.isEmpty ? nil : PasswordHasher.hash(password)
        unlockedSetIDs.remove(setID)
        updateSet(s)
    }

    /// Unlocks for this session. Returns false if the password is wrong.
    func unlock(setID: UUID, password: String) -> Bool {
        guard let s = set(id: setID) else { return false }
        if let hash = s.passwordHash, hash != PasswordHasher.hash(password) { return false }
        unlockedSetIDs.insert(setID)
        return true
    }

    func removeLock(setID: UUID) {
        guard var s = set(id: setID) else { return }
        s.isLocked = false
        s.passwordHash = nil
        updateSet(s)
    }

    // MARK: - Templates

    func upsertTemplate(_ template: PostTemplate, inSet setID: UUID) {
        guard var s = set(id: setID) else { return }
        var t = template
        t.updatedAt = Date()
        if let i = s.templates.firstIndex(where: { $0.id == t.id }) {
            s.templates[i] = t
        } else {
            s.templates.append(t)
        }
        updateSet(s)
    }

    func deleteTemplate(id: UUID, inSet setID: UUID) {
        guard var s = set(id: setID) else { return }
        s.templates.removeAll { $0.id == id }
        updateSet(s)
    }

    // MARK: - Assets

    @discardableResult
    func addAsset(imageData: Data, name: String, role: BrandAsset.AssetRole, toSet setID: UUID) -> BrandAsset? {
        guard var s = set(id: setID) else { return nil }
        // Normalize everything to PNG/JPEG we can always decode
        guard let image = UIImage(data: imageData) else {
            lastError = "That file is not a supported image."
            return nil
        }
        let isPNG = role == .logo
        let data = isPNG ? image.pngData() : image.jpegData(compressionQuality: 0.9)
        let fileName = "\(UUID().uuidString).\(isPNG ? "png" : "jpg")"
        do {
            try (data ?? imageData).write(to: assetsDir.appendingPathComponent(fileName), options: .atomic)
        } catch {
            lastError = "Could not save image: \(error.localizedDescription)"
            return nil
        }
        let asset = BrandAsset(name: name, fileName: fileName, assetRole: role)
        s.assets.append(asset)
        updateSet(s)
        return asset
    }

    func updateAsset(_ asset: BrandAsset, inSet setID: UUID) {
        guard var s = set(id: setID), let i = s.assets.firstIndex(where: { $0.id == asset.id }) else { return }
        s.assets[i] = asset
        updateSet(s)
    }

    func deleteAsset(id: UUID, fromSet setID: UUID) {
        guard var s = set(id: setID), let asset = s.assets.first(where: { $0.id == id }) else { return }
        try? fm.removeItem(at: assetsDir.appendingPathComponent(asset.fileName))
        imageCache[asset.fileName] = nil
        s.assets.removeAll { $0.id == id }
        updateSet(s)
    }

    func image(for asset: BrandAsset) -> UIImage? { loadImage(fileName: asset.fileName, in: assetsDir) }

    func image(for post: GeneratedPost) -> UIImage? { loadImage(fileName: post.imageFileName, in: postsDir) }

    func imageURL(for post: GeneratedPost) -> URL { postsDir.appendingPathComponent(post.imageFileName) }

    private func loadImage(fileName: String, in dir: URL) -> UIImage? {
        if let cached = imageCache[fileName] { return cached }
        guard let img = UIImage(contentsOfFile: dir.appendingPathComponent(fileName).path) else { return nil }
        imageCache[fileName] = img
        return img
    }

    // MARK: - Posts / History

    @discardableResult
    func savePost(image: UIImage, template: PostTemplate, set: TemplateSet,
                  size: InstagramSize, filledTexts: [UUID: String]) -> GeneratedPost? {
        guard let data = PostImageRenderer.encode(image, format: template.exportFormat, quality: template.jpegQuality) else {
            return nil
        }
        let fileName = "\(UUID().uuidString).\(template.exportFormat.fileExtension)"
        do {
            try data.write(to: postsDir.appendingPathComponent(fileName), options: .atomic)
        } catch {
            lastError = "Could not save post: \(error.localizedDescription)"
            return nil
        }
        var texts: [String: String] = [:]
        for (k, v) in filledTexts { texts[k.uuidString] = v }
        let post = GeneratedPost(templateSetName: set.name, templateName: template.name,
                                 templateID: template.id, instagramSize: size,
                                 imageFileName: fileName, templateSnapshot: template, filledTexts: texts)
        generatedPosts.insert(post, at: 0)
        savePosts()
        return post
    }

    func deletePost(id: UUID) {
        guard let post = generatedPosts.first(where: { $0.id == id }) else { return }
        try? fm.removeItem(at: postsDir.appendingPathComponent(post.imageFileName))
        imageCache[post.imageFileName] = nil
        generatedPosts.removeAll { $0.id == id }
        savePosts()
    }

    // MARK: - Usage insights (on-device only)

    var recentTemplates: [(setName: String, templateName: String, date: Date)] {
        var seen = Set<UUID>()
        var result: [(String, String, Date)] = []
        for p in generatedPosts.sorted(by: { $0.createdAt > $1.createdAt }) where !seen.contains(p.templateID) {
            seen.insert(p.templateID)
            result.append((p.templateSetName, p.templateName, p.createdAt))
            if result.count == 5 { break }
        }
        return result.map { (setName: $0.0, templateName: $0.1, date: $0.2) }
    }

    var sizeUsage: [(size: InstagramSize, count: Int)] {
        let counts = Dictionary(grouping: generatedPosts, by: { $0.instagramSize }).mapValues { $0.count }
        return counts.map { (size: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    var mostUsedTemplateName: String? {
        let counts = Dictionary(grouping: generatedPosts, by: { $0.templateName }).mapValues { $0.count }
        return counts.max { $0.value < $1.value }?.key
    }

    // MARK: - Fonts

    /// Copies a .ttf/.otf into Documents/Fonts, registers it, and attaches it to the set.
    /// Returns the PostScript names of the fonts contained in the file.
    @discardableResult
    func importFont(from url: URL, toSet setID: UUID) -> [String] {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let ext = url.pathExtension.lowercased()
        guard ["ttf", "otf"].contains(ext) else {
            lastError = "Only .ttf and .otf fonts are supported."
            return []
        }
        let fileName = url.lastPathComponent
        let dest = fontsDir.appendingPathComponent(fileName)
        do {
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: url, to: dest)
        } catch {
            lastError = "Could not import font: \(error.localizedDescription)"
            return []
        }
        registerFont(at: dest)
        if var s = set(id: setID), !s.customFontFiles.contains(fileName) {
            s.customFontFiles.append(fileName)
            updateSet(s)
        }
        return Self.postScriptNames(at: dest)
    }

    func registerAllFonts() {
        guard let files = try? fm.contentsOfDirectory(at: fontsDir, includingPropertiesForKeys: nil) else { return }
        files.forEach { registerFont(at: $0) }
    }

    private func registerFont(at url: URL) {
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        // "already registered" errors are harmless and intentionally ignored.
    }

    static func postScriptNames(at url: URL) -> [String] {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else { return [] }
        return descriptors.compactMap { CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String }
    }

    /// Font names available for a set: custom imported fonts first, then a curated system list.
    func availableFontNames(for s: TemplateSet) -> [String] {
        var names: [String] = []
        for file in s.customFontFiles {
            names.append(contentsOf: Self.postScriptNames(at: fontsDir.appendingPathComponent(file)))
        }
        let system = ["Helvetica Neue", "HelveticaNeue-Bold", "Avenir Next", "AvenirNext-Bold",
                      "Futura-Medium", "Futura-Bold", "Georgia", "Georgia-Bold", "Didot", "Didot-Bold",
                      "Baskerville", "Baskerville-Bold", "Gill Sans", "GillSans-Bold", "Menlo-Regular",
                      "AmericanTypewriter", "Noteworthy-Bold", "Copperplate", "Optima-Regular", "Optima-Bold"]
        names.append(contentsOf: system)
        return names
    }

    // MARK: - .artcraft export / import

    func exportArtcraft(setID: UUID) -> URL? {
        guard let s = set(id: setID) else { return nil }
        do {
            let url = try ArtcraftPackage.export(set: s, store: self)
            return url
        } catch {
            lastError = "Export failed: \(error.localizedDescription)"
            return nil
        }
    }

    func importArtcraft(from url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let imported = try ArtcraftPackage.importPackage(from: url, store: self)
            sets.append(imported)
            activeSetID = imported.id
            saveSets()
        } catch {
            lastError = "Import failed: \(error.localizedDescription)"
        }
    }
}
