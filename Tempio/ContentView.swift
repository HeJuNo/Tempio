import SwiftUI

/// Top-level navigation: Brand Studio (design), Create (fill & generate), History (output + insights).
struct ContentView: View {
    @EnvironmentObject private var store: TemplateStore

    var body: some View {
        TabView {
            BrandStudioView()
                .tabItem { Label("Brand Studio", systemImage: "paintpalette") }
            CreateView()
                .tabItem { Label("Create", systemImage: "square.and.pencil") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
        .alert("Something went wrong",
               isPresented: Binding(get: { store.lastError != nil }, set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
    }
}

#Preview {
    ContentView().environmentObject(TemplateStore())
}
