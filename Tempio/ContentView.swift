import SwiftUI

/// Top-level navigation for Tempio. Each tab is a placeholder for the
/// feature areas that will be built in Phase 2.
struct ContentView: View {
    var body: some View {
        TabView {
            Tab("Brand Studio", systemImage: "paintpalette") {
                PlaceholderScreen(
                    title: "Brand Studio",
                    systemImage: "paintpalette",
                    message: "Template Sets, Brand Kit, Asset Library and the Template Designer will live here."
                )
            }
            Tab("Create", systemImage: "square.and.pencil") {
                PlaceholderScreen(
                    title: "Create",
                    systemImage: "square.and.pencil",
                    message: "Pick a Template Set, a template and a size, then fill the image and text slots."
                )
            }
            Tab("Output", systemImage: "square.and.arrow.up") {
                PlaceholderScreen(
                    title: "Output",
                    systemImage: "square.and.arrow.up",
                    message: "Save finished posts to the Camera Roll or share them via the Share Sheet."
                )
            }
        }
        .tint(.accentColor)
    }
}

private struct PlaceholderScreen: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                Text(message)
            }
            .navigationTitle(title)
        }
    }
}

#Preview {
    ContentView()
}
