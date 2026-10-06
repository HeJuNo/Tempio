import SwiftUI
import UIKit
import Photos

/// Native iOS share sheet (Instagram, WhatsApp, AirDrop, Files …).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

/// Identifiable wrapper so share sheets can be driven with `.sheet(item:)`.
struct ShareItem: Identifiable {
    let id = UUID()
    let items: [Any]
}

enum PhotoLibrarySaver {
    enum SaveError: LocalizedError {
        case denied
        var errorDescription: String? { "Tempio has no permission to add photos. Enable it in Settings › Privacy › Photos." }
    }

    /// Saves encoded image files (keeps exact pixels + sRGB profile) to the Camera Roll.
    static func save(fileURLs: [URL]) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw SaveError.denied }
        try await PHPhotoLibrary.shared().performChanges {
            for url in fileURLs {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, fileURL: url, options: nil)
            }
        }
    }
}

/// Small swatch row showing a brand palette.
struct PaletteStrip: View {
    let hexes: [String]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(hexes.enumerated()), id: \.offset) { _, hex in
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hex: hex))
                    .frame(width: 18, height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.secondary.opacity(0.3)))
            }
        }
    }
}

/// Renders a live (low-res) preview of a template.
struct TemplatePreviewImage: View {
    @EnvironmentObject private var store: TemplateStore
    let template: PostTemplate
    let set: TemplateSet
    var size: InstagramSize? = nil
    var scale: CGFloat = 0.25

    var body: some View {
        let s = size ?? template.instagramSize
        Image(uiImage: PostImageRenderer.render(template: template, filledTexts: [:], filledImages: [:],
                                                set: set, store: store, size: s, scale: scale,
                                                showPlaceholders: true))
            .resizable()
            .aspectRatio(s.aspectRatio, contentMode: .fit)
    }
}

/// Alert-style sheet asking for a password.
struct PasswordPrompt: View {
    let title: String
    let message: String
    let confirmTitle: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                } footer: {
                    Text(message)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(confirmTitle) { onConfirm(password); dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
