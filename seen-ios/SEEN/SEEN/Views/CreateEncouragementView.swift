//
//  CreateEncouragementView.swift
//  SEEN
//
//  Create an encouragement post for pod members
//

import SwiftUI

struct CreateEncouragementView: View {
    let podId: String?
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPodId: String?
    @State private var pods: [PodListItem] = []
    @State private var members: [PodMember] = []
    @State private var selectedMember: PodMember?
    @State private var postType: PostType = .ENCOURAGEMENT
    @State private var message = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    private var canSubmit: Bool {
        selectedPodId != nil && (!message.isEmpty || selectedImage != nil)
    }
    
    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Encourage")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task { await loadData() }
                .onChange(of: selectedPodId) { _, newValue in
                    if let podId = newValue {
                        Task { await loadMembers(for: podId) }
                    }
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
                .alert("Error", isPresented: .constant(errorMessage != nil)) {
                    Button("OK") { errorMessage = nil }
                } message: {
                    Text(errorMessage ?? "")
                }
        }
    }
    
    private var formContent: some View {
        Form {
            postTypeSection
            podSelectionSection
            recipientSection
            messageSection
            photoSection
            submitSection
        }
    }
    
    private var postTypeSection: some View {
        Section("Type") {
            Picker("Post Type", selection: $postType) {
                Text("Encourage").tag(PostType.ENCOURAGEMENT)
                Text("Nudge").tag(PostType.NUDGE)
                Text("Celebrate").tag(PostType.CELEBRATION)
            }
            .pickerStyle(.segmented)
        }
    }
    
    @ViewBuilder
    private var podSelectionSection: some View {
        if podId == nil {
            Section("Pod") {
                if isLoading {
                    ProgressView()
                } else {
                    Picker("Select Pod", selection: $selectedPodId) {
                        Text("Select a pod").tag(nil as String?)
                        ForEach(pods) { pod in
                            Text(pod.name).tag(pod.id as String?)
                        }
                    }
                }
            }
        }
    }
    
    private var recipientSection: some View {
        Section {
            Picker("Send to", selection: $selectedMember) {
                Text("Everyone in pod").tag(nil as PodMember?)
                ForEach(members) { member in
                    Text(member.name).tag(member as PodMember?)
                }
            }
        } header: {
            Text("Recipient")
        } footer: {
            Text(footerText)
        }
    }
    
    private var footerText: String {
        postType == .NUDGE ? "Nudges are sent directly to the selected member" : "Leave empty to share with the whole pod"
    }
    
    private var messageSection: some View {
        Section("Message") {
            TextField("What do you want to say?", text: $message, axis: .vertical)
                .lineLimit(3...6)
        }
    }
    
    private var photoSection: some View {
        Section {
            if let image = selectedImage {
                photoPreview(image: image)
            } else {
                photoButtons
            }
        } header: {
            Text("Add Photo (optional)")
        }
    }
    
    private func photoPreview(image: UIImage) -> some View {
        HStack {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Spacer()
            
            Button("Remove", role: .destructive) {
                selectedImage = nil
            }
        }
    }
    
    private var photoButtons: some View {
        HStack {
            Button {
                showingCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
            }
            
            Spacer()
            
            Button {
                showingImagePicker = true
            } label: {
                Label("Library", systemImage: "photo")
            }
        }
    }
    
    private var submitSection: some View {
        Section {
            Button {
                Task { await submit() }
            } label: {
                HStack {
                    Spacer()
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Label(submitButtonText, systemImage: postType.icon)
                    }
                    Spacer()
                }
            }
            .disabled(!canSubmit || isSubmitting)
        }
    }
    
    private var submitButtonText: String {
        "Post \(postType.displayName)"
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        if let podId = podId {
            selectedPodId = podId
            await loadMembers(for: podId)
        } else {
            pods = [
                PodListItem(id: "pod1", name: "Fitness Squad", description: nil, stakes: nil, memberCount: 4, maxMembers: 6, role: .MEMBER, joinedAt: "", createdAt: ""),
                PodListItem(id: "pod2", name: "Book Club", description: nil, stakes: nil, memberCount: 3, maxMembers: 5, role: .MEMBER, joinedAt: "", createdAt: ""),
                PodListItem(id: "pod3", name: "Morning Routines", description: nil, stakes: nil, memberCount: 5, maxMembers: 8, role: .MEMBER, joinedAt: "", createdAt: ""),
            ]
        }
    }
    
    private func loadMembers(for podId: String) async {
        members = [
            PodMember(id: "user1", name: "Sarah", avatarUrl: "https://i.pravatar.cc/100?img=5", role: .MEMBER, joinedAt: ""),
            PodMember(id: "user2", name: "Mike", avatarUrl: "https://i.pravatar.cc/100?img=12", role: .MEMBER, joinedAt: ""),
            PodMember(id: "user3", name: "Emma", avatarUrl: "https://i.pravatar.cc/100?img=23", role: .MEMBER, joinedAt: ""),
            PodMember(id: "user4", name: "Alex", avatarUrl: "https://i.pravatar.cc/100?img=8", role: .OWNER, joinedAt: ""),
        ]
    }
    
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        onComplete()
        dismiss()
    }
}

// MARK: - PostType Extension

extension PostType {
    var icon: String {
        switch self {
        case .ENCOURAGEMENT: return "heart.fill"
        case .NUDGE: return "hand.point.up.fill"
        case .CELEBRATION: return "party.popper.fill"
        case .CHECK_IN: return "checkmark.circle.fill"
        }
    }
}

#Preview {
    CreateEncouragementView(podId: nil, onComplete: {})
}
