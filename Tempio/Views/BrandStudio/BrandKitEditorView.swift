import SwiftUI
import UniformTypeIdentifiers

struct BrandKitEditorView: View {
    @EnvironmentObject private var store: TemplateStore
    let setID: UUID

    @State private var kit: BrandKit = .default
    @State private var keywordsText = ""
    @State private var loaded = false
    @State private var showFontImporter = false
    @State private var importedMessage: String?

    var body: some View {
        if let set = store.set(id: setID) {
            let editable = store.canEdit(set)
            let fonts = store.availableFontNames(for: set)
            Form {
                Section("Colors") {
                    ColorPicker("Primary", selection: $kit.primaryColorHex.asColor, supportsOpacity: false)
                    ColorPicker("Secondary", selection: $kit.secondaryColorHex.asColor, supportsOpacity: false)
                    ColorPicker("Accent", selection: $kit.accentColorHex.asColor, supportsOpacity: false)
                    ColorPicker("Background", selection: $kit.backgroundColorHex.asColor, supportsOpacity: false)
                }

                FontSection(title: "Heading Font", font: $kit.headingFont, fontNames: fonts)
                FontSection(title: "Subheading Font", font: $kit.subheadingFont, fontNames: fonts)
                FontSection(title: "Body Font", font: $kit.bodyFont, fontNames: fonts)

                Section {
                    if set.customFontFiles.isEmpty {
                        Text("No custom fonts yet").foregroundStyle(.secondary)
                    }
                    ForEach(set.customFontFiles, id: \.self) { file in
                        Label(file, systemImage: "textformat")
                    }
                    Button { showFontImporter = true } label: {
                        Label("Import Font (.ttf / .otf)", systemImage: "plus")
                    }
                } header: {
                    Text("Custom Fonts")
                } footer: {
                    Text("Fonts are stored inside this Template Set and included in .artcraft exports.")
                }

                Section {
                    TextField("@handle", text: $kit.handle).textInputAutocapitalization(.never)
                    TextField("website.com", text: $kit.website).textInputAutocapitalization(.never).keyboardType(.URL)
                    TextField("Tagline", text: $kit.tagline)
                } header: {
                    Text("Pre-fill Values")
                } footer: {
                    Text("Used as defaults for pre-filled text slots.")
                }

                Section {
                    TextField("e.g. minimal, bold, warm", text: $keywordsText)
                } header: {
                    Text("Brand Mood")
                } footer: {
                    Text("Comma separated keywords. Used for AI suggestions later.")
                }

                Section("Preview") {
                    BrandPreviewCard(kit: kit)
                }
            }
            .disabled(!editable)
            .navigationTitle("Brand Kit")
            .onAppear {
                guard !loaded else { return }
                kit = set.brandKit
                keywordsText = set.brandKit.moodKeywords.joined(separator: ", ")
                loaded = true
            }
            .onDisappear { save() }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(!editable)
                }
            }
            .fileImporter(isPresented: $showFontImporter,
                          allowedContentTypes: [UTType(filenameExtension: "ttf") ?? .data,
                                                UTType(filenameExtension: "otf") ?? .data, .font],
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    var names: [String] = []
                    for url in urls { names += store.importFont(from: url, toSet: setID) }
                    importedMessage = names.isEmpty ? "No fonts imported." : "Imported: \(names.joined(separator: ", "))"
                }
            }
            .alert("Fonts", isPresented: Binding(get: { importedMessage != nil }, set: { if !$0 { importedMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importedMessage ?? "")
            }
        }
    }

    private func save() {
        guard var set = store.set(id: setID), store.canEdit(set) else { return }
        kit.moodKeywords = keywordsText.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        set.brandKit = kit
        store.updateSet(set)
    }
}

private struct FontSection: View {
    let title: String
    @Binding var font: FontConfig
    let fontNames: [String]

    var body: some View {
        Section(title) {
            Picker("Font", selection: $font.fontName) {
                Text("System").tag("")
                ForEach(fontNames, id: \.self) { name in
                    Text(name).font(.custom(name, size: 16)).tag(name)
                }
            }
            Picker("Weight", selection: $font.weight) {
                ForEach(FontConfig.weights, id: \.self) { Text($0.capitalized).tag($0) }
            }
            Stepper("Size: \(Int(font.size)) px", value: $font.size, in: 16...240, step: 2)
        }
    }
}

private struct BrandPreviewCard: View {
    let kit: BrandKit
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Headline")
                .font(Font(kit.headingFont.uiFont(size: 28) as CTFont))
                .foregroundStyle(.white)
            Text("Subheading")
                .font(Font(kit.subheadingFont.uiFont(size: 18) as CTFont))
                .foregroundStyle(Color(hex: kit.accentColorHex))
            Text("Body text looks like this in your posts.")
                .font(Font(kit.bodyFont.uiFont(size: 14) as CTFont))
                .foregroundStyle(.white.opacity(0.85))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(hex: kit.primaryColorHex), Color(hex: kit.backgroundColorHex)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
