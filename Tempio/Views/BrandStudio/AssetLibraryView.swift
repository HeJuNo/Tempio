import SwiftUI
import PhotosUI

struct AssetLibraryView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var importRole: BrandAsset.AssetRole = .background
    @State private var filter: BrandAsset.AssetRole?
    @State private var selectedAsset: BrandAsset?
    @State private var isImporting = false

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        if let set = store.set(id: setID) {
            let editable = store.canEdit(set)
            let assets = filter.map { set.assets(role: $0) } ?? set.assets
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Filter", selection: $filter) {
                        Text("All").tag(BrandAsset.AssetRole?.none)
                        ForEach(BrandAsset.AssetRole.allCases) { Text($0.displayName).tag(BrandAsset.AssetRole?.some($0)) }
                    }
                    .pickerStyle(.segmented)

                    if assets.isEmpty {
                        ContentUnavailableView("No assets",
                                               systemImage: "photo.on.rectangle",
                                               description: Text("Add logos, brand art and background images. Images marked ‘Auto’ fill auto image slots."))
                            .padding(.top, 40)
                    }

                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(assets) { asset in
                            Button { selectedAsset = asset } label: {
                                AssetTile(asset: asset)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .overlay {
                if isImporting { ProgressView("Importing…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }
            .navigationTitle("Asset Library")
            .toolbar {
                if editable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Picker("Import as", selection: $importRole) {
                                ForEach(BrandAsset.AssetRole.allCases) { Text($0.displayName).tag($0) }
                            }
                        } label: {
                            Label(importRole.displayName, systemImage: "tag")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 20, matching: .images) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await importItems(items) }
            }
            .sheet(item: $selectedAsset) { asset in
                AssetDetailSheet(setID: setID, asset: asset, editable: editable)
            }
        }
    }

    private func importItems(_ items: [PhotosPickerItem]) async {
        isImporting = true
        for (i, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                store.addAsset(imageData: data, name: "\(importRole.displayName) \(i + 1)", role: importRole, toSet: setID)
            }
        }
        pickerItems = []
        isImporting = false
    }
}

private struct AssetTile: View {
    @EnvironmentObject private var store: TemplateStore
    let asset: BrandAsset

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Rectangle().fill(Color(.secondarySystemBackground))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let img = store.image(for: asset) {
                        Image(uiImage: img).resizable()
                            .aspectRatio(contentMode: asset.assetRole == .logo ? .fit : .fill)
                            .padding(asset.assetRole == .logo ? 10 : 0)
                    }
                }
                .clipped()
            HStack(spacing: 4) {
                Text(asset.assetRole.displayName)
                if asset.useForAutoSlots && asset.assetRole != .logo { Image(systemName: "shuffle") }
            }
            .font(.caption2.bold())
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct AssetDetailSheet: View {
    @EnvironmentObject private var store: TemplateStore
    @Environment(\.dismiss) private var dismiss
    let setID: UUID
    @State var asset: BrandAsset
    let editable: Bool

    var body: some View {
        NavigationStack {
            Form {
                if let img = store.image(for: asset) {
                    Section {
                        Image(uiImage: img).resizable().scaledToFit().frame(maxHeight: 260)
                            .frame(maxWidth: .infinity)
                    }
                }
                Section("Details") {
                    TextField("Name", text: $asset.name)
                    Picker("Role", selection: $asset.assetRole) {
                        ForEach(BrandAsset.AssetRole.allCases) { Text($0.displayName).tag($0) }
                    }
                    Toggle("Use for Auto image slots", isOn: $asset.useForAutoSlots)
                        .disabled(asset.assetRole == .logo)
                }
                Section {
                    Button("Delete Asset", role: .destructive) {
                        store.deleteAsset(id: asset.id, fromSet: setID)
                        dismiss()
                    }
                }
            }
            .disabled(!editable)
            .navigationTitle(asset.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if editable { store.updateAsset(asset, inSet: setID) }
                        dismiss()
                    }
                }
            }
        }
    }
}
