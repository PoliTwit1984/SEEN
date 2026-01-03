//
//  CheckInSelectionView.swift
//  SEEN
//
//  Select a goal and check in
//

import SwiftUI

struct CheckInSelectionView: View {
    let podId: String?
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedGoal: Goal?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your goals...")
                } else if goals.isEmpty {
                    emptyState
                } else {
                    goalList
                }
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadGoals()
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(item: $selectedGoal) { goal in
                QuickCheckInView(goal: goal) {
                    onComplete()
                    dismiss()
                }
            }
        }
    }
    
    private var goalList: some View {
        List {
            ForEach(groupedGoals.keys.sorted(), id: \.self) { podName in
                Section(podName) {
                    ForEach(groupedGoals[podName] ?? []) { goal in
                        GoalCheckInRow(goal: goal) {
                            selectedGoal = goal
                        }
                    }
                }
            }
        }
    }
    
    private var groupedGoals: [String: [Goal]] {
        Dictionary(grouping: goals) { $0.podName ?? "Unknown Pod" }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 48))
                .foregroundStyle(.seenGreen)
            
            Text("All Done!")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You've checked in on all your goals for today.\nGreat job! 🎉")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Close") {
                dismiss()
            }
            .buttonStyle(.glassPrimary)
            .padding(.top)
        }
        .padding()
    }
    
    private func loadGoals() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let allGoals = try await GoalService.shared.getMyGoals(podId: podId)

            // Filter out goals already checked in today
            goals = allGoals.filter { !($0.todayCheckedIn ?? false) }
        } catch {
            print("Failed to load goals: \(error)")
            errorMessage = "Failed to load goals"
        }
    }
}

// MARK: - Goal Check-In Row

struct GoalCheckInRow: View {
    let goal: Goal
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Goal icon
                Image(systemName: goal.requiresProof ?? false ? "camera.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(goal.requiresProof ?? false ? .seenBlue : .seenGreen)
                
                // Goal info
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        if let streak = goal.currentStreak, streak > 0 {
                            Label("\(streak) day streak", systemImage: "flame.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                        
                        if goal.requiresProof ?? false {
                            Label("Photo required", systemImage: "camera")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Quick Check-In View

struct QuickCheckInView: View {
    let goal: Goal
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var comment = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    
    var needsPhoto: Bool {
        goal.requiresProof ?? false
    }
    
    var canSubmit: Bool {
        !needsPhoto || selectedImage != nil
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Goal header
                    VStack(spacing: 8) {
                        Text(goal.title)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        if let description = goal.description {
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    
                    // Photo section
                    if needsPhoto {
                        photoSection
                    }
                    
                    // Comment
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Add a comment (optional)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        TextField("How did it go?", text: $comment, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...5)
                    }
                    .padding(.horizontal)
                    
                    // Submit button
                    Button {
                        Task { await submitCheckIn() }
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Mark Complete")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassPrimary)
                    .disabled(!canSubmit || isSubmitting)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
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
    
    private var photoSection: some View {
        VStack(spacing: 12) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        Button {
                            selectedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                        .padding(8),
                        alignment: .topTrailing
                    )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text("Photo proof required")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 16) {
                        Button {
                            showingCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                        .buttonStyle(.glassSecondary)
                        
                        Button {
                            showingImagePicker = true
                        } label: {
                            Label("Library", systemImage: "photo")
                        }
                        .buttonStyle(.glassSecondary)
                    }
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal)
    }
    
    private func submitCheckIn() async {
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            // Upload photo if present
            var proofUrl: String?
            if let image = selectedImage {
                proofUrl = try await PhotoUploadService.shared.uploadPhoto(image: image, goalId: goal.id)
            }

            // Submit check-in
            _ = try await CheckInService.shared.checkIn(
                goalId: goal.id,
                status: .COMPLETED,
                comment: comment.isEmpty ? nil : comment,
                proofUrl: proofUrl
            )

            onComplete()
            dismiss()
        } catch {
            print("Check-in failed: \(error)")
            errorMessage = "Failed to submit check-in"
        }
    }
}

#Preview {
    CheckInSelectionView(podId: nil, onComplete: {})
}
