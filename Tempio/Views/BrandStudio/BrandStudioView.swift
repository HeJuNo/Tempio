import SwiftUI
import UniformTypeIdentifiers

/// Tab 1: list of Template Sets (brands / clients).
struct BrandStudioView: View {
    @EnvironmentObject private var store: TemplateStore
    @State private var showNewSet = false
    @State private var newSetName = ""
    @State private var showImporter = false
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(store.sets) { set in
                        NavigationLink(value: set.id) {
                            TemplateSetRow(set: set, isActive: set.id == store.activeSetID)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                store.activeSetID = set.id
                            } label: { Label("Make Active", systemImage: "checkmark.circle") }
                                .tint(.green)
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.sets[$0].id }
                        ids.forEach { store.deleteSet(id: $0) }
                    }
                } header: {
                    Text("Template Sets")
                } footer: {
                    Text("Each Template Set is a complete brand package: colors, fonts, logos, brand art and templates. Swipe right to make a set active.")
                }
            }
            .navigationTitle("Brand Studio")
            .navigationDestination(for: UUID.self) { id in
                TemplateSetDetailView(setID: id)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { newSetName = ""; showNewSet = true } label: {
                            Label("New Template Set", systemImage: "plus")
                        }
                        Button { showImporter = true } label: {
                            Label("Import .artcraft", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("New Template Set", isPresented: $showNewSet) {
                TextField("Brand or client name", text: $newSetName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    let s = store.addSet(name: newSetName)
                    path.append(s.id)
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.artcraftPackage, .zip, .data]) { result in
                if case .success(let url) = result { store.importArtcraft(from: url) }
            }
        }
    }
}

private struct TemplateSetRow: View {
    @EnvironmentObject private var store: TemplateStore
    let set: TemplateSet
    let isActive: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: set.brandKit.primaryColorHex))
                if let logo = set.primaryLogo, let img = store.image(for: logo) {
                    Image(uiImage: img).resizable().scaledToFit().padding(6)
                } else {
                    Text(String(set.name.prefix(1))).font(.title2.bold()).foregroundStyle(.white)
                }
            }
            .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(set.name).font(.headline)
                    if set.isLocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary) }
                    if isActive {
                        Text("ACTIVE").font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                    }
                }
                Text("\(set.templates.count) templates · \(set.assets.count) assets")
                    .font(.caption).foregroundStyle(.secondary)
                PaletteStrip(hexes: [set.brandKit.primaryColorHex, set.brandKit.secondaryColorHex,
                                     set.brandKit.accentColorHex, set.brandKit.backgroundColorHex])
            }
        }
        .padding(.vertical, 4)
    }
}

extension UTType {
    /// Declared in Info.plist (UTExportedTypeDeclarations).
    static let artcraftPackage = UTType(exportedAs: "com.tempio.artcraft", conformingTo: .zip)
}
