import SwiftUI

/// Full view of one generated post with its template snapshot, share, save and delete.
struct HistoryDetailView: View {
    @EnvironmentObject private var store: TemplateStore
    @Environment(\.dismiss) private var dismiss
    let postID: UUID

    @State private var shareItem: ShareItem?
    @State private var message: String?
    @State private var confirmDelete = false

    private var post: GeneratedPost? { store.generatedPosts.first { $0.id == postID } }

    var body: some View {
        Group {
            if let post { content(post) } else {
                ContentUnavailableView("Post deleted", systemImage: "trash")
            }
        }
        .navigationTitle(post?.templateName ?? "Post")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { ShareSheet(items: $0.items) }
        .alert("Tempio", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(message ?? "") }
        .confirmationDialog("Delete this post?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deletePost(id: postID)
                dismiss()
            }
        } message: { Text("The copy in your Camera Roll is not affected.") }
    }

    private func content(_ post: GeneratedPost) -> some View {
        let snapshot = post.templateSnapshot
        return List {
            Section {
                if let img = store.image(for: post) {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(post.instagramSize.aspectRatio, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Image file missing").foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    shareItem = ShareItem(items: [store.imageURL(for: post)])
                } label: { Label("Share", systemImage: "square.and.arrow.up") }
                Button {
                    Task {
                        do {
                            try await PhotoLibrarySaver.save(fileURLs: [store.imageURL(for: post)])
                            message = "Saved to Camera Roll."
                        } catch {
                            message = error.localizedDescription
                        }
                    }
                } label: { Label("Save to Camera Roll", systemImage: "square.and.arrow.down") }
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            Section("Details") {
                LabeledContent("Template set", value: post.templateSetName)
                LabeledContent("Template", value: post.templateName)
                LabeledContent("Size", value: "\(post.instagramSize.displayName) · \(post.instagramSize.dimensionLabel)")
                LabeledContent("Format", value: snapshot.exportFormat.rawValue.uppercased())
                LabeledContent("Created") {
                    Text(post.createdAt, format: .dateTime.day().month().year().hour().minute())
                }
            }

            Section {
                LabeledContent("Zones", value: "\(snapshot.zones.count)")
                LabeledContent("Template last edited") {
                    Text(snapshot.updatedAt, format: .dateTime.day().month().year().hour().minute())
                }
                let texts = post.filledTexts.compactMap { key, value -> (String, String)? in
                    guard !value.isEmpty, let id = UUID(uuidString: key),
                          let zone = snapshot.zones.first(where: { $0.id == id }) else { return nil }
                    return (zone.name, value)
                }.sorted { $0.0 < $1.0 }
                ForEach(texts, id: \.0) { item in
                    LabeledContent(item.0, value: item.1)
                }
            } header: {
                Text("Template snapshot")
            } footer: {
                Text("An exact copy of the template as it was when this post was generated.")
            }
        }
    }
}
