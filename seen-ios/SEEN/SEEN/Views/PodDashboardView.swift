import SwiftUI

struct PodDashboardView: View {
    let podId: String

    @State private var dashboard: PodDashboard?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedMember: MemberStatus?
    @State private var showingPostComposer = false
    @State private var feedRefreshId = UUID()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading && dashboard == nil {
                    ProgressView("Loading dashboard...")
                        .padding(.top, 50)
                } else if let dashboard = dashboard {
                    dashboardContent(dashboard)
                } else {
                    EmptyStateView(
                        icon: "person.3",
                        title: "Unable to load",
                        message: errorMessage ?? "Try again later"
                    )
                }
            }
            .padding()
        }
        .refreshable {
            feedRefreshId = UUID()
            await loadDashboard()
        }
        .task {
            await loadDashboard()
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailSheet(
                member: member,
                podId: podId,
                onDismiss: {
                    selectedMember = nil
                    Task { await loadDashboard() }
                }
            )
        }
        .sheet(isPresented: $showingPostComposer) {
            PostComposerView(podId: podId) {
                Task { await loadDashboard() }
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private func dashboardContent(_ dashboard: PodDashboard) -> some View {
        // Pod Health
        PodHealthIndicator(health: dashboard.health)
        
        // Member Status Grid
        VStack(alignment: .leading, spacing: 12) {
            Text("Members")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(dashboard.memberStatuses) { member in
                        MemberStatusCard(member: member) {
                            if member.isCurrentUser != true {
                                selectedMember = member
                            }
                        }
                    }
                }
            }
        }
        
        // Needs Encouragement Section
        if !dashboard.needsEncouragement.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Needs Encouragement")
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.red)
                }
                
                ForEach(dashboard.needsEncouragement) { member in
                    NeedsEncouragementCard(
                        member: member,
                        onCheer: {
                            Task { await sendCheer(to: member) }
                        },
                        onNudge: {
                            Task { await sendNudge(to: member) }
                        }
                    )
                }
            }
        }
        
        // Post Encouragement Button
        Button {
            showingPostComposer = true
        } label: {
            Label("Post Encouragement", systemImage: "plus.bubble.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassPrimary)
        .padding(.top, 8)
        
        // Pod Feed Section
        PodFeedSection(podId: podId)
            .id(feedRefreshId)
    }
    
    private func loadDashboard() async {
        isLoading = true
        defer { isLoading = false }

        do {
            dashboard = try await PostService.shared.getPodDashboard(podId: podId)
        } catch {
            print("Failed to load dashboard: \(error)")
            errorMessage = "Failed to load dashboard"
        }
    }
    
    private func sendCheer(to member: NeedsEncouragementMember) async {
        do {
            try await PostService.shared.createPost(
                podId: podId,
                type: .ENCOURAGEMENT,
                content: "You got this! 💪",
                mediaUrl: nil,
                mediaType: nil,
                targetUserId: member.userId
            )
            await loadDashboard()
        } catch {
            errorMessage = "Failed to send cheer"
            print("Send cheer error: \(error)")
        }
    }
    
    private func sendNudge(to member: NeedsEncouragementMember) async {
        do {
            try await PostService.shared.sendNudge(podId: podId, targetUserId: member.userId)
            await loadDashboard()
        } catch {
            errorMessage = "Failed to send nudge"
            print("Send nudge error: \(error)")
        }
    }
}

// MARK: - Pod Feed Section

struct PodFeedSection: View {
    let podId: String
    
    @State private var posts: [PodPost] = []
    @State private var isLoading = true
    @State private var nextCursor: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pod Activity")
                .font(.headline)
            
            if isLoading && posts.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if posts.isEmpty {
                Text("No activity yet. Be the first to post!")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(posts) { post in
                        PostCard(post: post)
                    }
                    
                    if nextCursor != nil {
                        Button("Load more") {
                            Task { await loadMorePosts() }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .task {
            await loadPosts()
        }
    }
    
    private func loadPosts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            print("📥 Loading posts for pod: \(podId)")
            let response = try await PostService.shared.getPodPosts(podId: podId)
            print("✅ Loaded \(response.posts.count) posts")
            posts = response.posts
            nextCursor = response.nextCursor
        } catch {
            print("❌ Load posts error: \(error)")
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

// MARK: - Post Card

struct PostCard: View {
    let post: PodPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Circle()
                    .fill(post.type == .CHECK_IN ? Color.seenGreen.opacity(0.2) : Color.seenBlue.opacity(0.2))
                    .frame(width: 36, height: 36)
                    .overlay {
                        if post.type == .CHECK_IN {
                            Image(systemName: "checkmark")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundStyle(.seenGreen)
                        } else {
                            Text(String(post.author.name.prefix(1)))
                                .font(.subheadline)
                                .fontWeight(.bold)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(post.author.name)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text(post.type.emoji)

                        if post.type == .CHECK_IN, let goalTitle = post.goalTitle {
                            Text(goalTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else if let target = post.target {
                            Text("→")
                                .foregroundStyle(.secondary)
                            Text(target.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }

                    Text(timeAgo(from: post.createdAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            
            // Content
            if let content = post.content, !content.isEmpty {
                Text(content)
                    .font(.body)
            }
            
            // Media
            if let mediaUrl = post.mediaUrl, let url = URL(string: mediaUrl) {
                switch post.mediaType {
                case .PHOTO:
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(height: 150)
                            .overlay { ProgressView() }
                    }
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                case .VIDEO:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 150)
                        .overlay {
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                        }
                    
                case .AUDIO:
                    HStack {
                        Image(systemName: "waveform")
                            .font(.title2)
                            .foregroundStyle(.seenGreen)
                        
                        Text("Voice note")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.seenGreen)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                case .none:
                    EmptyView()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func timeAgo(from dateString: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return ""
        }
        
        let elapsed = Date().timeIntervalSince(date)
        
        if elapsed < 60 {
            return "now"
        } else if elapsed < 3600 {
            return "\(Int(elapsed / 60))m"
        } else if elapsed < 86400 {
            return "\(Int(elapsed / 3600))h"
        } else {
            return "\(Int(elapsed / 86400))d"
        }
    }
}

// MARK: - Post Composer View

struct PostComposerView: View {
    let podId: String
    let onPost: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var postType: PostType = .ENCOURAGEMENT
    @State private var content: String = ""
    @State private var isPosting = false
    @State private var showingMediaCapture = false
    @State private var capturedMedia: CapturedMedia?
    @State private var uploadedMediaUrl: String?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $postType) {
                        ForEach(PostType.allCases, id: \.self) { type in
                            Label("\(type.emoji) \(type.displayName)", systemImage: "sparkles")
                                .tag(type)
                        }
                    }
                }
                
                Section("Message") {
                    TextField("Write something encouraging...", text: $content, axis: .vertical)
                        .lineLimit(5, reservesSpace: true)
                }
                
                Section("Media") {
                    if capturedMedia != nil {
                        HStack {
                            Image(systemName: capturedMedia!.mediaType.emoji == "📸" ? "photo.fill" : capturedMedia!.mediaType.emoji == "🎥" ? "video.fill" : "waveform")
                                .foregroundStyle(.seenGreen)
                            Text("Media attached")
                            Spacer()
                            Button("Remove") {
                                capturedMedia = nil
                                uploadedMediaUrl = nil
                            }
                            .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            showingMediaCapture = true
                        } label: {
                            Label("Add Photo, Video, or Voice", systemImage: "plus.circle")
                        }
                    }
                }
                
                Section {
                    Button {
                        Task { await submitPost() }
                    } label: {
                        HStack {
                            Spacer()
                            if isPosting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Post")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(isPosting || (content.isEmpty && capturedMedia == nil))
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingMediaCapture) {
                MediaCaptureView { media in
                    capturedMedia = media
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func submitPost() async {
        isPosting = true
        defer { isPosting = false }
        
        do {
            // Upload media if present
            var mediaUrl: String?
            var mediaType: MediaType?
            
            if let media = capturedMedia {
                mediaType = media.mediaType
                
                switch media.type {
                case .photo:
                    if let image = media.image {
                        mediaUrl = try await PhotoUploadService.shared.uploadPhoto(image: image, goalId: "post-\(UUID().uuidString)")
                    }
                case .video:
                    if let url = media.videoURL {
                        mediaUrl = try await PhotoUploadService.shared.uploadVideo(url: url, goalId: "post-\(UUID().uuidString)")
                    }
                case .audio:
                    if let url = media.audioURL {
                        mediaUrl = try await PhotoUploadService.shared.uploadAudio(url: url, goalId: "post-\(UUID().uuidString)")
                    }
                }
            }
            
            _ = try await PostService.shared.createPost(
                podId: podId,
                type: postType,
                content: content.isEmpty ? nil : content,
                mediaUrl: mediaUrl,
                mediaType: mediaType
            )
            
            onPost()
            dismiss()
        } catch {
            errorMessage = "Failed to post"
            print("Submit post error: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        PodDashboardView(podId: "test-pod-id")
    }
}
