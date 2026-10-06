import SwiftUI

/// Step 1–3 of creating a post: pick set → pick template → pick sizes.
struct CreateView: View {
    @EnvironmentObject private var store: TemplateStore
    @State private var selectedSetID: UUID?
    @State private var selectedTemplateID: UUID?
    @State private var selectedSizes: Set<InstagramSize> = []
    @State private var fillRequest: FillRequest?

    struct FillRequest: Hashable, Identifiable {
        let id = UUID()
        let setID: UUID
        let templateID: UUID
        let sizes: [InstagramSize]
    }

    private var currentSet: TemplateSet? {
        if let id = selectedSetID, let s = store.set(id: id) { return s }
        return store.activeSet ?? store.sets.first
    }

    private var currentTemplate: PostTemplate? {
        guard let s = currentSet else { return nil }
        return s.templates.first { $0.id == selectedTemplateID }
    }

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if store.sets.isEmpty {
                    ContentUnavailableView("No template sets",
                                           systemImage: "square.stack.3d.up.slash",
                                           description: Text("Create a template set in Brand Studio first."))
                } else if let set = currentSet {
                    content(set: set)
                }
            }
            .navigationTitle("Create")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { setMenu }
            }
            .navigationDestination(item: $fillRequest) { req in
                ContentFillView(setID: req.setID, templateID: req.templateID, sizes: req.sizes)
            }
        }
    }

    private var setMenu: some View {
        Menu {
            ForEach(store.sets) { s in
                Button {
                    selectedSetID = s.id
                    selectedTemplateID = nil
                    selectedSizes = []
                } label: {
                    if s.id == currentSet?.id { Label(s.name, systemImage: "checkmark") } else { Text(s.name) }
                }
            }
        } label: {
            Label(currentSet?.name ?? "Set", systemImage: "square.stack.3d.up")
        }
    }

    @ViewBuilder
    private func content(set: TemplateSet) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(set.name).font(.title2.bold())
                        Text("\(set.templates.count) templates").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    PaletteStrip(hexes: set.brandKit.palette)
                }

                Text("1. Choose a template").font(.headline)
                if set.templates.isEmpty {
                    Text("This set has no templates yet. Add one in Brand Studio › \(set.name) › Templates.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(set.templates) { t in
                            templateCard(t, set: set)
                        }
                    }
                }

                if let template = currentTemplate {
                    Text("2. Choose sizes").font(.headline)
                    sizeChips(base: template.instagramSize)

                    Button {
                        let sizes = InstagramSize.allCases.filter { selectedSizes.contains($0) }
                        fillRequest = FillRequest(setID: set.id, templateID: template.id, sizes: sizes)
                    } label: {
                        Label("Fill content (\(selectedSizes.count) size\(selectedSizes.count == 1 ? "" : "s"))",
                              systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedSizes.isEmpty)
                }
            }
            .padding()
        }
    }

    private func templateCard(_ t: PostTemplate, set: TemplateSet) -> some View {
        let selected = t.id == selectedTemplateID
        return Button {
            selectedTemplateID = t.id
            selectedSizes = [t.instagramSize]
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                TemplatePreviewImage(template: t, set: set, scale: 0.18)
                    .frame(maxWidth: .infinity, maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(t.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(t.instagramSize.displayName).font(.caption).foregroundStyle(.secondary)
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.accentColor : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
    }

    private func sizeChips(base: InstagramSize) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(InstagramSize.allCases) { size in
                    let on = selectedSizes.contains(size)
                    Button {
                        if on { selectedSizes.remove(size) } else { selectedSizes.insert(size) }
                    } label: {
                        HStack {
                            Image(systemName: size.systemImage)
                            VStack(alignment: .leading) {
                                Text(size.displayName).font(.subheadline.weight(.medium))
                                Text(size.ratioLabel).font(.caption2).foregroundStyle(on ? .white.opacity(0.85) : .secondary)
                            }
                            Spacer()
                            if size == base { Image(systemName: "star.fill").font(.caption2) }
                        }
                        .padding(10)
                        .foregroundStyle(on ? .white : .primary)
                        .background(RoundedRectangle(cornerRadius: 10).fill(on ? Color.accentColor : Color(.secondarySystemBackground)))
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Button("Select all") { selectedSizes = Set(InstagramSize.allCases) }
                Spacer()
                Text("★ = template's base size").font(.caption).foregroundStyle(.secondary)
            }
            .font(.footnote)
        }
    }
}
