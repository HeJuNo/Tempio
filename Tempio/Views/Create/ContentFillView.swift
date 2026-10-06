import SwiftUI
import PhotosUI

/// Fill the open slots of a template, preview every selected size, then batch-generate.
struct ContentFillView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID
    let templateID: UUID
    let sizes: [InstagramSize]

    @State private var texts: [UUID: String] = [:]
    @State private var images: [UUID: UIImage] = [:]
    @State private var pickerItems: [UUID: PhotosPickerItem] = [:]
    @State private var previewSize: InstagramSize = .square
    @State private var preview: UIImage?
    @State private var isGenerating = false
    @State private var shareItem: ShareItem?
    @State private var alertMessage: String?
    @State private var didSetup = false
    @State private var pendingShareURLs: [URL] = []

    private var set: TemplateSet? { store.set(id: setID) }
    private var template: PostTemplate? { set?.templates.first { $0.id == templateID } }

    var body: some View {
        Group {
            if let set, let template {
                form(set: set, template: template)
            } else {
                ContentUnavailableView("Template not found", systemImage: "questionmark.square.dashed")
            }
        }
        .navigationTitle(template?.name ?? "Fill")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setup)
        .sheet(item: $shareItem) { item in ShareSheet(items: item.items) }
        .alert("Tempio", isPresented: Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })) {
            if !pendingShareURLs.isEmpty {
                Button("Share anyway") {
                    let urls = pendingShareURLs
                    pendingShareURLs = []
                    shareItem = ShareItem(items: urls)
                }
            }
            Button("OK", role: .cancel) { pendingShareURLs = [] }
        } message: {
            Text(alertMessage ?? "")
        }
        .overlay {
            if isGenerating {
                ZStack {
                    Color.black.opacity(0.35).ignoresSafeArea()
                    ProgressView("Generating \(sizes.count) image\(sizes.count == 1 ? "" : "s")…")
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 14).fill(.regularMaterial))
                }
            }
        }
    }

    private func setup() {
        guard !didSetup, let template else { return }
        didSetup = true
        previewSize = sizes.first ?? template.instagramSize
        for zone in template.zones where zone.zoneType == .text {
            if case .preFilled(let s) = zone.textSlotType { texts[zone.id] = s }
        }
        refreshPreview()
    }

    private func refreshPreview() {
        guard let set, let template else { return }
        preview = PostImageRenderer.render(template: template, filledTexts: texts, filledImages: images,
                                           set: set, store: store, size: previewSize, scale: 0.35,
                                           showPlaceholders: true)
    }

    @ViewBuilder
    private func form(set: TemplateSet, template: PostTemplate) -> some View {
        Form {
            Section {
                if sizes.count > 1 {
                    Picker("Preview size", selection: $previewSize) {
                        ForEach(sizes) { s in Image(systemName: s.systemImage).tag(s) }
                    }
                    .pickerStyle(.segmented)
                }
                if let preview {
                    ZStack {
                        Image(uiImage: preview)
                            .resizable()
                            .aspectRatio(previewSize.aspectRatio, contentMode: .fit)
                        if previewSize == .story { storySafeZones }
                    }
                    .aspectRatio(previewSize.aspectRatio, contentMode: .fit)
                    .frame(maxHeight: 420)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Text("\(previewSize.displayName) · \(previewSize.dimensionLabel)")
                    .font(.caption).foregroundStyle(.secondary)
            } header: { Text("Preview") }

            let editable = template.sortedZones.reversed().filter { $0.zoneType == .text || $0.zoneType == .image }
            Section {
                if editable.isEmpty {
                    Text("This template has no fillable slots.").foregroundStyle(.secondary)
                }
                ForEach(editable) { zone in
                    zoneRow(zone, set: set)
                }
            } header: { Text("Content") }

            Section {
                Button {
                    Task { await generate(set: set, template: template) }
                } label: {
                    Label("Generate \(sizes.count) image\(sizes.count == 1 ? "" : "s")", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isGenerating)
            } footer: {
                Text("Saves to your Camera Roll (\(template.exportFormat.rawValue.uppercased()), sRGB) and opens the share sheet.")
            }
        }
        .onChange(of: previewSize) { _, _ in refreshPreview() }
    }

    private var storySafeZones: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Rectangle().fill(Color.red.opacity(0.18))
                    .frame(height: geo.size.height * InstagramSize.story.unsafeTopFraction)
                Spacer()
                Rectangle().fill(Color.red.opacity(0.18))
                    .frame(height: geo.size.height * InstagramSize.story.unsafeBottomFraction)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func zoneRow(_ zone: TemplateZone, set: TemplateSet) -> some View {
        switch zone.zoneType {
        case .text:
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(zone.name).font(.caption.weight(.semibold))
                    Spacer()
                    Text(zone.textSlotType.kindName).font(.caption2).foregroundStyle(.secondary)
                }
                switch zone.textSlotType {
                case .locked(let s):
                    HStack {
                        Image(systemName: "lock.fill").font(.caption)
                        Text(s.isEmpty ? "—" : s)
                    }
                    .foregroundStyle(.secondary)
                case .preFilled, .open:
                    TextField(zone.placeholder.isEmpty ? zone.name : zone.placeholder,
                              text: Binding(get: { texts[zone.id] ?? "" },
                                            set: { texts[zone.id] = $0; refreshPreview() }),
                              axis: .vertical)
                        .lineLimit(1...4)
                }
            }
        case .image:
            HStack(spacing: 12) {
                thumbnail(for: zone, set: set)
                VStack(alignment: .leading, spacing: 4) {
                    Text(zone.name).font(.subheadline.weight(.semibold))
                    Text(zone.imageSlotType.displayName).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if zone.imageSlotType == .auto {
                    Button {
                        shuffle(zone, set: set)
                    } label: {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(set.autoSlotAssets.isEmpty)
                }
                PhotosPicker(selection: Binding(get: { pickerItems[zone.id] },
                                                set: { item in
                                                    pickerItems[zone.id] = item
                                                    if let item { load(item, for: zone.id) }
                                                }),
                             matching: .images) {
                    Image(systemName: "photo.badge.plus")
                }
                .buttonStyle(.bordered)
            }
        default:
            EmptyView()
        }
    }

    private func thumbnail(for zone: TemplateZone, set: TemplateSet) -> some View {
        let img = images[zone.id] ?? (zone.imageSlotType == .auto
                                       ? PostImageRenderer.defaultAutoImage(for: zone, set: set, store: store) : nil)
        return Group {
            if let img {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
            }
        }
        .frame(width: 54, height: 54)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func shuffle(_ zone: TemplateZone, set: TemplateSet) {
        let pool = set.autoSlotAssets
        guard !pool.isEmpty else { return }
        var candidates = pool
        if pool.count > 1, let current = images[zone.id] {
            candidates = pool.filter { store.image(for: $0) !== current }
        }
        if let pick = candidates.randomElement(), let img = store.image(for: pick) {
            images[zone.id] = img
            refreshPreview()
        }
    }

    private func load(_ item: PhotosPickerItem, for zoneID: UUID) {
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    images[zoneID] = img
                    refreshPreview()
                } else {
                    alertMessage = "Could not load that photo."
                }
            } catch {
                alertMessage = "Could not load that photo: \(error.localizedDescription)"
            }
        }
    }

    private func generate(set: TemplateSet, template: PostTemplate) async {
        isGenerating = true
        defer { isGenerating = false }
        // Let the progress overlay appear before the heavy rendering work.
        try? await Task.sleep(nanoseconds: 50_000_000)

        // Only keep text for editable zones.
        var filled: [UUID: String] = [:]
        for zone in template.zones where zone.zoneType == .text {
            if case .locked = zone.textSlotType { continue }
            if let t = texts[zone.id] { filled[zone.id] = t }
        }

        let rendered = PostImageRenderer.renderAll(template: template, filledTexts: filled, filledImages: images,
                                                   set: set, store: store, sizes: sizes)
        var urls: [URL] = []
        for size in sizes {
            guard let img = rendered[size],
                  let post = store.savePost(image: img, template: template, set: set, size: size, filledTexts: filled)
            else { continue }
            urls.append(store.imageURL(for: post))
        }
        guard !urls.isEmpty else {
            alertMessage = store.lastError ?? "Rendering failed."
            return
        }

        var saveNote = "Saved \(urls.count) image\(urls.count == 1 ? "" : "s") to your Camera Roll and History."
        do {
            try await PhotoLibrarySaver.save(fileURLs: urls)
        } catch {
            saveNote = "Saved to History, but not to Camera Roll: \(error.localizedDescription)"
        }
        if saveNote.hasPrefix("Saved to History, but") {
            pendingShareURLs = urls
            alertMessage = saveNote
        } else {
            shareItem = ShareItem(items: urls)
        }
    }
}
