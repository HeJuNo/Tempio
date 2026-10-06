import SwiftUI

struct TemplateSetDetailView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID

    @State private var shareItem: ShareItem?
    @State private var showLockPrompt = false
    @State private var showUnlockPrompt = false
    @State private var wrongPassword = false
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let set = store.set(id: setID), let binding = store.binding(forSet: setID) {
            let editable = store.canEdit(set)
            List {
                Section("Name") {
                    TextField("Name", text: binding.name)
                        .disabled(!editable)
                }

                if set.isLocked {
                    Section {
                        HStack {
                            Image(systemName: editable ? "lock.open.fill" : "lock.fill")
                            Text(editable ? "Unlocked for this session" : "Locked – read-only. You can still create posts.")
                                .font(.callout)
                        }
                        if !editable {
                            Button("Unlock…") { showUnlockPrompt = true }
                        } else {
                            Button("Remove Lock", role: .destructive) { store.removeLock(setID: setID) }
                        }
                    }
                }

                Section("Brand") {
                    NavigationLink {
                        BrandKitEditorView(setID: setID)
                    } label: {
                        HStack {
                            Label("Brand Kit", systemImage: "paintpalette")
                            Spacer()
                            PaletteStrip(hexes: [set.brandKit.primaryColorHex, set.brandKit.secondaryColorHex, set.brandKit.accentColorHex])
                        }
                    }
                    NavigationLink {
                        AssetLibraryView(setID: setID)
                    } label: {
                        HStack {
                            Label("Asset Library", systemImage: "photo.on.rectangle.angled")
                            Spacer()
                            Text("\(set.assets.count)").foregroundStyle(.secondary)
                        }
                    }
                    NavigationLink {
                        TemplateListView(setID: setID)
                    } label: {
                        HStack {
                            Label("Templates", systemImage: "rectangle.3.group")
                            Spacer()
                            Text("\(set.templates.count)").foregroundStyle(.secondary)
                        }
                    }
                }

                if !set.templates.isEmpty {
                    Section("Templates") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(set.templates) { t in
                                    NavigationLink {
                                        TemplateDesignerView(setID: setID, templateID: t.id)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            TemplatePreviewImage(template: t, set: set, scale: 0.15)
                                                .frame(height: 140)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            Text(t.name).font(.caption).lineLimit(1)
                                            Text(t.instagramSize.displayName).font(.caption2).foregroundStyle(.secondary)
                                        }
                                        .frame(width: 120)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Workspace") {
                    Button {
                        store.activeSetID = setID
                    } label: {
                        Label(store.activeSetID == setID ? "Active Set" : "Make Active Set",
                              systemImage: store.activeSetID == setID ? "checkmark.circle.fill" : "circle")
                    }
                    .disabled(store.activeSetID == setID)
                    Button {
                        if let url = store.exportArtcraft(setID: setID) { shareItem = ShareItem(items: [url]) }
                    } label: {
                        Label("Export as .artcraft", systemImage: "square.and.arrow.up")
                    }
                    if !set.isLocked {
                        Button { showLockPrompt = true } label: {
                            Label("Lock Set (read-only)…", systemImage: "lock")
                        }
                    }
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Delete Set", systemImage: "trash")
                    }
                    .disabled(!editable)
                }
            }
            .navigationTitle(set.name)
            .sheet(item: $shareItem) { item in ShareSheet(items: item.items) }
            .sheet(isPresented: $showLockPrompt) {
                PasswordPrompt(title: "Lock Set",
                               message: "Locked sets can be used to create posts but not edited. Leave empty to lock without a password.",
                               confirmTitle: "Lock") { pw in
                    store.lock(setID: setID, password: pw)
                }
            }
            .sheet(isPresented: $showUnlockPrompt) {
                PasswordPrompt(title: "Unlock Set", message: "Enter the password for this set.", confirmTitle: "Unlock") { pw in
                    if !store.unlock(setID: setID, password: pw) { wrongPassword = true }
                }
            }
            .alert("Wrong password", isPresented: $wrongPassword) { Button("OK", role: .cancel) {} }
            .confirmationDialog("Delete \(set.name)?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    dismiss()
                    store.deleteSet(id: setID)
                }
            } message: {
                Text("All templates and assets of this set will be removed.")
            }
        } else {
            ContentUnavailableView("Set not found", systemImage: "questionmark.folder")
        }
    }
}
