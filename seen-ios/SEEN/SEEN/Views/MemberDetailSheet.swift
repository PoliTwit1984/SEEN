import SwiftUI

struct MemberDetailSheet: View {
    let member: MemberStatus
    let podId: String
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var memberGoals: [MemberStatusWithGoals]?
    @State private var isLoading = true
    @State private var showingMediaCapture = false
    @State private var capturedMedia: CapturedMedia?
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var selectedGoalForComment: PendingGoal?
    @State private var commentText = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Member Header
                    memberHeader
                    
                    // Today's Goals
                    if let goals = memberGoals?.first(where: { $0.userId == member.userId }) {
                        goalsSection(goals.pendingGoals)
                    }
                    
                    Divider()
                    
                    // Interaction Buttons
                    interactionButtons
                }
                .padding()
            }
            .navigationTitle(member.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
            .task {
                await loadMemberGoals()
            }
            .sheet(isPresented: $showingMediaCapture) {
                MediaCaptureView { media in
                    capturedMedia = media
                }
            }
            .sheet(item: $selectedGoalForComment) { goal in
                GoalCommentSheet(
                    goal: goal,
                    onComment: { content, mediaUrl, mediaType in
                        Task {
                            await addGoalComment(goalId: goal.id, content: content, mediaUrl: mediaUrl, mediaType: mediaType)
                        }
                    }
                )
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Sent!", isPresented: .constant(successMessage != nil)) {
                Button("OK") { successMessage = nil }
            } message: {
                Text(successMessage ?? "")
            }
        }
    }
    
    private var memberHeader: some View {
        VStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .strokeBorder(statusColor, lineWidth: 4)
                    .frame(width: 100, height: 100)
                
                if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        initialsView(size: 88)
                    }
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                } else {
                    initialsView(size: 88)
                }
            }
            
            // Name and Status
            VStack(spacing: 4) {
                Text(member.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text(member.todayStatus.emoji)
                    Text(member.todayStatus.displayText)
                        .foregroundStyle(.secondary)
                }
                
                if member.currentStreak > 0 {
                    HStack {
                        Text("🔥")
                        Text("\(member.currentStreak) day streak")
                            .fontWeight(.medium)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }
        }
    }
    
    @ViewBuilder
    private func goalsSection(_ pendingGoals: [PendingGoal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Goals")
                .font(.headline)
            
            if pendingGoals.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.seenGreen)
                    Text("All goals completed!")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(pendingGoals) { goal in
                    HStack {
                        Image(systemName: "circle")
                            .foregroundStyle(.orange)
                        
                        Text(goal.title)
                            .font(.subheadline)
                        
                        Spacer()
                        
                        Button {
                            selectedGoalForComment = goal
                        } label: {
                            Image(systemName: "bubble.right")
                                .foregroundStyle(.seenBlue)
                        }
                        .accessibilityLabel("Comment on \(goal.title)")
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    
    private var interactionButtons: some View {
        VStack(spacing: 12) {
            Text("Send Encouragement")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Quick actions
            HStack(spacing: 12) {
                interactionButton(
                    icon: "hand.point.right.fill",
                    label: "Nudge",
                    color: .orange
                ) {
                    Task { await sendNudge() }
                }
                
                interactionButton(
                    icon: "hands.clap.fill",
                    label: "Cheer",
                    color: .seenGreen
                ) {
                    Task { await sendCheer() }
                }
            }
            
            // Media buttons
            HStack(spacing: 12) {
                mediaButton(icon: "camera.fill", label: "Photo", type: .photo)
                mediaButton(icon: "video.fill", label: "Video", type: .video)
                mediaButton(icon: "mic.fill", label: "Voice", type: .audio)
            }
            
            // Send media if captured
            if capturedMedia != nil {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: mediaIcon)
                            .foregroundStyle(.seenGreen)
                        Text("Media ready to send")
                        Spacer()
                        Button("Clear") {
                            capturedMedia = nil
                        }
                        .foregroundStyle(.red)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    
                    Button {
                        Task { await sendMediaEncouragement() }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Label("Send to \(member.name.components(separatedBy: " ").first ?? member.name)", systemImage: "paperplane.fill")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(isSending)
                }
            }
        }
    }
    
    private func interactionButton(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                    .frame(width: 50, height: 50)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isSending)
    }
    
    private func mediaButton(icon: String, label: String, type: CaptureMediaType) -> some View {
        Button {
            showingMediaCapture = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.seenBlue)
                    .frame(width: 44, height: 44)
                    .background(Color.seenBlue.opacity(0.1))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private var mediaIcon: String {
        switch capturedMedia?.type {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "waveform"
        case .none: return "photo"
        }
    }
    
    private func initialsView(size: CGFloat) -> some View {
        Circle()
            .fill(Color.seenBlue.opacity(0.2))
            .frame(width: size, height: size)
            .overlay {
                Text(String(member.name.prefix(1)))
                    .font(.system(size: size * 0.4))
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
            }
    }
    
    private var statusColor: Color {
        switch member.todayStatus {
        case .completed: return .seenGreen
        case .pending: return .orange
        case .missed: return .red
        case .no_goals: return .gray
        }
    }
    
    // MARK: - Actions
    
    private func loadMemberGoals() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            memberGoals = try await PostService.shared.getMemberStatuses(podId: podId)
        } catch {
            print("Load member goals error: \(error)")
        }
    }
    
    private func sendNudge() async {
        isSending = true
        defer { isSending = false }
        
        do {
            try await PostService.shared.sendNudge(podId: podId, targetUserId: member.userId)
            successMessage = "Nudge sent to \(member.name)! 👊"
        } catch {
            errorMessage = "Failed to send nudge"
            print("Send nudge error: \(error)")
        }
    }
    
    private func sendCheer() async {
        isSending = true
        defer { isSending = false }
        
        do {
            _ = try await PostService.shared.createPost(
                podId: podId,
                type: .ENCOURAGEMENT,
                content: "You got this! 💪",
                mediaUrl: nil,
                mediaType: nil,
                targetUserId: member.userId
            )
            successMessage = "Cheer sent to \(member.name)! 🎉"
        } catch {
            errorMessage = "Failed to send cheer"
            print("Send cheer error: \(error)")
        }
    }
    
    private func sendMediaEncouragement() async {
        guard let media = capturedMedia else { return }
        
        isSending = true
        defer { isSending = false }
        
        do {
            var mediaUrl: String?
            let mediaType = media.mediaType
            
            switch media.type {
            case .photo:
                if let image = media.image {
                    mediaUrl = try await PhotoUploadService.shared.uploadPhoto(image: image, goalId: "encourage-\(UUID().uuidString)")
                }
            case .video:
                if let url = media.videoURL {
                    mediaUrl = try await PhotoUploadService.shared.uploadVideo(url: url, goalId: "encourage-\(UUID().uuidString)")
                }
            case .audio:
                if let url = media.audioURL {
                    mediaUrl = try await PhotoUploadService.shared.uploadAudio(url: url, goalId: "encourage-\(UUID().uuidString)")
                }
            }
            
            _ = try await PostService.shared.createPost(
                podId: podId,
                type: .ENCOURAGEMENT,
                content: nil,
                mediaUrl: mediaUrl,
                mediaType: mediaType,
                targetUserId: member.userId
            )
            
            capturedMedia = nil
            successMessage = "Encouragement sent to \(member.name)!"
        } catch {
            errorMessage = "Failed to send encouragement"
            print("Send media encouragement error: \(error)")
        }
    }
    
    private func addGoalComment(goalId: String, content: String?, mediaUrl: String?, mediaType: MediaType?) async {
        do {
            _ = try await PostService.shared.addGoalComment(
                goalId: goalId,
                content: content,
                mediaUrl: mediaUrl,
                mediaType: mediaType
            )
            successMessage = "Comment added!"
        } catch {
            errorMessage = "Failed to add comment"
            print("Add goal comment error: \(error)")
        }
    }
}

// MARK: - Goal Comment Sheet

struct GoalCommentSheet: View {
    let goal: PendingGoal
    let onComment: (String?, String?, MediaType?) async -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var commentText = ""
    @State private var showingMediaCapture = false
    @State private var capturedMedia: CapturedMedia?
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(.orange)
                        Text(goal.title)
                            .fontWeight(.medium)
                    }
                }
                
                Section("Your Comment") {
                    TextField("Write something encouraging...", text: $commentText, axis: .vertical)
                        .lineLimit(4, reservesSpace: true)
                }
                
                Section("Add Media") {
                    if capturedMedia != nil {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.seenGreen)
                            Text("Media attached")
                            Spacer()
                            Button("Remove") {
                                capturedMedia = nil
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
                        Task { await submitComment() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Send Comment")
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(isSubmitting || (commentText.isEmpty && capturedMedia == nil))
                }
            }
            .navigationTitle("Comment on Goal")
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
        }
    }
    
    private func submitComment() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        var mediaUrl: String?
        var mediaType: MediaType?
        
        if let media = capturedMedia {
            mediaType = media.mediaType
            
            do {
                switch media.type {
                case .photo:
                    if let image = media.image {
                        mediaUrl = try await PhotoUploadService.shared.uploadPhoto(image: image, goalId: goal.id)
                    }
                case .video:
                    if let url = media.videoURL {
                        mediaUrl = try await PhotoUploadService.shared.uploadVideo(url: url, goalId: goal.id)
                    }
                case .audio:
                    if let url = media.audioURL {
                        mediaUrl = try await PhotoUploadService.shared.uploadAudio(url: url, goalId: goal.id)
                    }
                }
            } catch {
                print("Upload media error: \(error)")
            }
        }
        
        await onComment(
            commentText.isEmpty ? nil : commentText,
            mediaUrl,
            mediaType
        )
        
        dismiss()
    }
}

#Preview {
    MemberDetailSheet(
        member: MemberStatus(
            userId: "1",
            name: "Alex Johnson",
            avatarUrl: nil,
            todayStatus: .pending,
            currentStreak: 5,
            totalGoals: 2,
            completedToday: 1,
            pendingToday: 1,
            isCurrentUser: false
        ),
        podId: "test-pod",
        onDismiss: { }
    )
}
