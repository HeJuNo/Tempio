import SwiftUI

struct TemplateListView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID
    @State private var showNew = false
    @State private var openTemplateID: UUID?

    var body: some View {
        if let set = store.set(id: setID) {
            let editable = store.canEdit(set)
            List {
                if set.templates.isEmpty {
                    ContentUnavailableView("No templates", systemImage: "rectangle.3.group",
                                           description: Text("Tap + to start from a preset layout."))
                }
                ForEach(set.templates) { t in
                    NavigationLink {
                        TemplateDesignerView(setID: setID, templateID: t.id)
                    } label: {
                        HStack(spacing: 12) {
                            TemplatePreviewImage(template: t, set: set, scale: 0.1)
                                .frame(width: 64, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name).font(.headline)
                                Label("\(t.instagramSize.displayName) · \(t.instagramSize.dimensionLabel)",
                                      systemImage: t.instagramSize.systemImage)
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(t.zones.count) zones · \(t.exportFormat.rawValue.uppercased())")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .contextMenu {
                        Button {
                            var copy = t
                            copy.id = UUID()
                            copy.name = "\(t.name) Copy"
                            store.upsertTemplate(copy, inSet: setID)
                        } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                    }
                }
                .onDelete { offsets in
                    guard editable else { return }
                    offsets.map { set.templates[$0].id }.forEach { store.deleteTemplate(id: $0, inSet: setID) }
                }
            }
            .navigationTitle("Templates")
            .navigationDestination(item: $openTemplateID) { id in
                TemplateDesignerView(setID: setID, templateID: id)
            }
            .toolbar {
                if editable {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showNew = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $showNew) {
                NewTemplateSheet(set: set) { template in
                    store.upsertTemplate(template, inSet: setID)
                    openTemplateID = template.id
                }
            }
        }
    }
}

/// Step 1 of the hybrid designer: name, size and a preset layout.
struct NewTemplateSheet: View {
    let set: TemplateSet
    let onCreate: (PostTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = "New Template"
    @State private var size: InstagramSize = .square
    @State private var preset: PresetLayout = .fullBleed

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Template name", text: $name) }
                Section("Size") {
                    Picker("Instagram size", selection: $size) {
                        ForEach(InstagramSize.allCases) { s in
                            Text("\(s.displayName) (\(s.ratioLabel))").tag(s)
                        }
                    }
                }
                Section("Preset Layout") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 12)], spacing: 12) {
                        ForEach(PresetLayout.allCases) { p in
                            let t = PostTemplate(name: p.displayName, instagramSize: size, zones: p.makeZones(brandKit: set.brandKit))
                            Button { preset = p } label: {
                                VStack(spacing: 4) {
                                    TemplatePreviewImage(template: t, set: set, scale: 0.08)
                                        .frame(height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6)
                                            .stroke(preset == p ? Color.accentColor : .clear, lineWidth: 3))
                                    Text(p.displayName).font(.caption2)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("New Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let t = PostTemplate(name: name.isEmpty ? preset.displayName : name,
                                             instagramSize: size, zones: preset.makeZones(brandKit: set.brandKit))
                        dismiss()
                        onCreate(t)
                    }
                }
            }
        }
    }
}
