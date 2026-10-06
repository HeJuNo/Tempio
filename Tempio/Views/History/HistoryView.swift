import SwiftUI

/// All generated posts (newest first) plus on-device usage insights.
struct HistoryView: View {
    @EnvironmentObject private var store: TemplateStore
    @State private var postToDelete: GeneratedPost?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    private var posts: [GeneratedPost] {
        store.generatedPosts.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if posts.isEmpty {
                    ContentUnavailableView("No posts yet",
                                           systemImage: "clock.arrow.circlepath",
                                           description: Text("Posts you generate in Create appear here."))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            insights
                            Text("All posts").font(.headline)
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(posts) { post in
                                    NavigationLink(value: post) { cell(post) }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            ShareLink(item: store.imageURL(for: post))
                                            Button(role: .destructive) { postToDelete = post } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: GeneratedPost.self) { post in
                HistoryDetailView(postID: post.id)
            }
            .confirmationDialog("Delete this post?",
                                isPresented: Binding(get: { postToDelete != nil }, set: { if !$0 { postToDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let p = postToDelete { store.deletePost(id: p.id) }
                    postToDelete = nil
                }
            } message: {
                Text("The copy in your Camera Roll is not affected.")
            }
        }
    }

    private var insights: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insights").font(.headline)
            HStack(spacing: 12) {
                statCard(title: "Posts", value: "\(posts.count)", icon: "photo.stack")
                statCard(title: "Top template", value: store.mostUsedTemplateName ?? "—", icon: "star")
            }
            let usage = store.sizeUsage
            if !usage.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Sizes used").font(.subheadline.weight(.semibold))
                    let maxCount = max(usage.map(\.count).max() ?? 1, 1)
                    ForEach(usage, id: \.size) { item in
                        HStack {
                            Image(systemName: item.size.systemImage).frame(width: 20)
                            Text(item.size.displayName).font(.caption).frame(width: 90, alignment: .leading)
                            GeometryReader { geo in
                                Capsule().fill(Color.accentColor)
                                    .frame(width: max(6, geo.size.width * CGFloat(item.count) / CGFloat(maxCount)))
                            }
                            .frame(height: 8)
                            Text("\(item.count)").font(.caption.monospacedDigit())
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
            let recent = store.recentTemplates
            if !recent.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recently used templates").font(.subheadline.weight(.semibold))
                    ForEach(Array(recent.enumerated()), id: \.offset) { _, r in
                        HStack {
                            Text(r.templateName).font(.caption.weight(.medium))
                            Text(r.setName).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(r.date, style: .relative).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func cell(_ post: GeneratedPost) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let img = store.image(for: post) {
                    Image(uiImage: img).resizable().scaledToFill()
                } else {
                    Image(systemName: "photo").foregroundStyle(.secondary)
                }
            }
            .frame(height: 110)
            .frame(maxWidth: .infinity)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(post.templateName).font(.caption.weight(.semibold)).lineLimit(1)
            HStack(spacing: 4) {
                Image(systemName: post.instagramSize.systemImage)
                Text(post.createdAt, format: .dateTime.day().month(.abbreviated))
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
    }
}
