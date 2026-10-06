import SwiftUI

@main
struct TempioApp: App {
    @StateObject private var store = TemplateStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear { if store.sets.isEmpty { store.loadAll() } }
                .onOpenURL { url in
                    if url.pathExtension.lowercased() == "artcraft" { store.importArtcraft(from: url) }
                }
        }
    }
}
