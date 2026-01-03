import SwiftUI

struct EncouragementFeedView: View {
    let podId: String
    
    @State private var posts: [PodPost] = []
    @State private var isLoading = true
    @State private var nextCursor: String?
    @State private var errorMessage: String?
    @State private var showingPostComposer = false
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && posts.isEmpty {
                Spacer()
                ProgressView("Loading feed...")
                Spacer()
            } else if posts.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: "bubble.left.and.bubble.right",
                    title: "No Posts Yet",
                    message: "Be the first to encourage your pod!"
                )
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(posts) { post in
                            EncouragementPostCard(post: post)
                        }
                        
                        if nextCursor != nil {
                            Button {
                                Task { await loadMorePosts() }
                            } label: {
                                Text("Load More")
                                    .font(.subheadline)
                                    .foregroundStyle(.seenBlue)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Pod Activity")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingPostComposer = true
                } label: {
                    Image(systemName: "plus.bubble.fill")
                        .foregroundStyle(.seenGreen)
                }
            }
        }
        .refreshable {
            await loadPosts()
        }
        .task {
            await loadPosts()
        }
        .sheet(isPresented: $showingPostComposer) {
            PostComposerView(podId: podId) {
                Task { await loadPosts() }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await PostService.shared.getPodPosts(podId: podId)
            posts = response.posts
            nextCursor = response.nextCursor
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load posts"
            print("Load posts error: \(error)")
        }
    }
    
    private func loadMorePosts() async {
        guard let cursor = nextCursor else { return }
        
        do {
            let response = try await PostService.shared.getPodPosts(podId: podId, cursor: cursor)
            posts.append(contentsOf: response.posts)
            nextCursor = response.nextCursor
        } catch {
            print("Load more posts error: \(error)")
        }
    }
}

// MARK: - Encouragement Post Card

struct EncouragementPostCard: View {
    let post: PodPost
    
    @State private var isPlayingAudio = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                // Author avatar
                avatarView(for: post.author)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Text(post.type.emoji)
                        
                        if let target = post.target {
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Text(target.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Text(post.type.displayName)
                            .font(.caption)
                            .foregroundStyle(typeColor)
                        
                        Text("•")
                            .foregroundStyle(.tertiary)
                        
                        Text(timeAgo(from: post.createdAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
            }
            
            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.body)
            }
            
            // Media
            if post.hasMedia, let mediaUrl = post.mediaUrl {
                mediaView(url: mediaUrl, type: post.mediaType)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    @ViewBuilder
    private func avatarView(for author: PostAuthor) -> some View {
        if let avatarUrl = author.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                initialsAvatar(name: author.name, size: 44)
            }
            .frame(width: 44, height: 44)
            .clipShape(Circle())
        } else {
            initialsAvatar(name: author.name, size: 44)
        }
    }
    
    private func initialsAvatar(name: String, size: CGFloat) -> some View {
        Circle()
            .fill(Color.seenBlue.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
    }
    
    @ViewBuilder
    private func mediaView(url: String, type: MediaType?) -> some View {
        switch type {
        case .PHOTO:
            if let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay { ProgressView() }
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxHeight: 250)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    case .failure:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 150)
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
            }
            
        case .VIDEO:
            Button {
                // TODO: Play video
            } label: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(height: 180)
                    .overlay {
                        ZStack {
                            Image(systemName: "video.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            
                            Circle()
                                .fill(.white.opacity(0.9))
                                .frame(width: 60, height: 60)
                                .overlay {
                                    Image(systemName: "play.fill")
                                        .font(.title2)
                                        .foregroundStyle(.seenGreen)
                                        .offset(x: 2)
                                }
                        }
                    }
            }
            
        case .AUDIO:
            Button {
                isPlayingAudio.toggle()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title)
                        .foregroundStyle(.seenGreen)
                    
                    // Waveform visualization
                    HStack(spacing: 3) {
                        ForEach(0..<15, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.seenGreen.opacity(0.6))
                                .frame(width: 3, height: CGFloat.random(in: 8...30))
                        }
                    }
                    
                    Spacer()
                    
                    Text("Voice Note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.seenGreen.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
        case .none:
            EmptyView()
        }
    }
    
    private var typeColor: Color {
        switch post.type {
        case .ENCOURAGEMENT: return .seenGreen
        case .NUDGE: return .orange
        case .CELEBRATION: return .purple
        }
    }
    
    private func timeAgo(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        
        let elapsed = Date().timeIntervalSince(date)
        
        if elapsed < 60 {
            return "now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m ago"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h ago"
        } else {
            return "\(Int(elapsed / 86400))d ago"
        }
    }
}

#Preview {
    NavigationStack {
        EncouragementFeedView(podId: "test-pod")
    }
}
