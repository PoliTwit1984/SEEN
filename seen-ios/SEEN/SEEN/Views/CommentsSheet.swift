//
//  CommentsSheet.swift
//  SEEN
//
//  Comments view for feed items (check-ins and posts)
//

import SwiftUI
import PhotosUI

struct CommentsSheet: View {
    let itemType: String  // "checkin" or "post"
    let itemId: String

    @Environment(\.dismiss) private var dismiss
    @State private var comments: [FeedComment] = []
    @State private var isLoading = true
    @State private var isSending = false
    @State private var newCommentText = ""
    @State private var errorMessage: String?
    @State private var nextCursor: String?

    // Media picker
    @State private var showingMediaOptions = false
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading && comments.isEmpty {
                    Spacer()
                    ProgressView("Loading comments...")
                    Spacer()
                } else if comments.isEmpty {
                    emptyState
                } else {
                    commentsList
                }

                Divider()

                // Comment composer
                commentComposer
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await loadComments()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    selectedImage = image
                }
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    selectedImage = image
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Comments Yet")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Be the first to comment!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Comments List

    private var commentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, onDelete: {
                        Task { await deleteComment(comment) }
                    })

                    Divider()
                        .padding(.leading, 60)
                }

                // Load more
                if nextCursor != nil {
                    Button("Load more") {
                        Task { await loadMoreComments() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.seenGreen)
                    .padding()
                }
            }
        }
    }

    // MARK: - Comment Composer

    private var commentComposer: some View {
        VStack(spacing: 8) {
            // Selected image preview
            if let image = selectedImage {
                HStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer()

                    Button {
                        selectedImage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }

            HStack(spacing: 12) {
                // Media button
                Button {
                    showingMediaOptions = true
                } label: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                        .foregroundStyle(.seenGreen)
                }
                .confirmationDialog("Add Media", isPresented: $showingMediaOptions, titleVisibility: .visible) {
                    Button("Take Photo") {
                        showingCamera = true
                    }
                    Button("Choose from Library") {
                        showingImagePicker = true
                    }
                    Button("Cancel", role: .cancel) { }
                }

                // Text field
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)

                // Send button
                Button {
                    Task { await sendComment() }
                } label: {
                    if isSending {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(canSend ? .seenGreen : .secondary)
                    }
                }
                .disabled(!canSend || isSending)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
    }

    private var canSend: Bool {
        !newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }

    // MARK: - Actions

    private func loadComments() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response = try await FeedService.shared.getComments(itemType: itemType, itemId: itemId)
            comments = response.comments
            nextCursor = response.nextCursor
        } catch {
            print("Failed to load comments: \(error)")
            // Show mock data for demo
            loadMockComments()
        }
    }

    private func loadMoreComments() async {
        guard let cursor = nextCursor else { return }

        do {
            let response = try await FeedService.shared.getComments(itemType: itemType, itemId: itemId, cursor: cursor)
            comments.append(contentsOf: response.comments)
            nextCursor = response.nextCursor
        } catch {
            print("Failed to load more comments: \(error)")
        }
    }

    private func sendComment() async {
        let trimmedText = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSend else { return }

        isSending = true
        defer { isSending = false }

        do {
            var mediaUrl: String? = nil
            var mediaType: MediaType? = nil

            // Note: Media upload for comments not yet implemented
            // Would need a separate presigned URL endpoint for comment media
            if selectedImage != nil {
                errorMessage = "Photo comments coming soon!"
                return
            }

            let comment = try await FeedService.shared.addComment(
                itemType: itemType,
                itemId: itemId,
                content: trimmedText.isEmpty ? nil : trimmedText,
                mediaUrl: mediaUrl,
                mediaType: mediaType
            )

            comments.insert(comment, at: 0)
            newCommentText = ""
            selectedImage = nil
        } catch {
            errorMessage = "Failed to send comment: \(error.localizedDescription)"
        }
    }

    private func deleteComment(_ comment: FeedComment) async {
        do {
            try await FeedService.shared.deleteComment(commentId: comment.id)
            comments.removeAll { $0.id == comment.id }
        } catch {
            errorMessage = "Failed to delete comment"
        }
    }

    private func loadMockComments() {
        comments = [
            FeedComment(
                id: "c1",
                content: "This is amazing! Keep it up!",
                mediaUrl: nil,
                mediaType: nil,
                author: FeedUser(id: "u1", name: "Sarah", avatarUrl: "https://i.pravatar.cc/150?img=5"),
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-3600))
            ),
            FeedComment(
                id: "c2",
                content: "Wow, that's inspiring!",
                mediaUrl: nil,
                mediaType: nil,
                author: FeedUser(id: "u2", name: "Mike", avatarUrl: "https://i.pravatar.cc/150?img=12"),
                createdAt: ISO8601DateFormatter().string(from: Date().addingTimeInterval(-7200))
            ),
        ]
    }
}

// MARK: - Comment Row

struct CommentRow: View {
    let comment: FeedComment
    let onDelete: () -> Void

    @State private var showingDeleteAlert = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Author avatar
            authorAvatar

            VStack(alignment: .leading, spacing: 4) {
                // Author name + time
                HStack(spacing: 8) {
                    Text(comment.author.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(comment.relativeTime)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    // Delete button (context menu)
                    Menu {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }

                // Content
                if let content = comment.content, !content.isEmpty {
                    Text(content)
                        .font(.body)
                }

                // Media
                if let mediaUrl = comment.mediaUrl, let url = URL(string: mediaUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: 150)
                                .overlay(ProgressView())
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        case .failure:
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.tertiarySystemBackground))
                                .frame(height: 80)
                                .overlay(
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                )
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .alert("Delete Comment", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Are you sure you want to delete this comment?")
        }
    }

    @ViewBuilder
    private var authorAvatar: some View {
        if let avatarUrl = comment.author.avatarUrl, let url = URL(string: avatarUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty, .failure:
                    avatarPlaceholder
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                @unknown default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Text(String(comment.author.name.prefix(1)).uppercased())
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.seenGreen, .seenMint],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }
}

#Preview {
    CommentsSheet(itemType: "checkin", itemId: "test-id")
}
