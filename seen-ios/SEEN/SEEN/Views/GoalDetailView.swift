//
//  GoalDetailView.swift
//  SEEN
//
//  Goal details with check-in history and check-in button - HIG Compliant
//

import SwiftUI

struct GoalDetailView: View {
    let goalId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingArchiveAlert = false
    @State private var isCheckedInToday = false
    @State private var isCheckingIn = false
    @State private var showingCheckInSheet = false
    @State private var checkInSuccess = false
    
    var body: some View {
        ZStack {
            Group {
                if isLoading {
                    ProgressView("Loading...")
                } else if let goal = goal {
                    goalContent(goal)
                } else {
                    ContentUnavailableView("Goal Not Found", systemImage: "exclamationmark.triangle")
                }
            }
            
            // Floating check-in button
            if let goal = goal, !isCheckedInToday {
                VStack {
                    Spacer()
                    
                    Button {
                        if goal.needsProof {
                            showingCheckInSheet = true
                        } else {
                            Task { await quickCheckIn() }
                        }
                    } label: {
                        HStack {
                            if isCheckingIn {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Check In")
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44) // Accessibility: 44pt min
                        .padding()
                        .background(Color.seenGreen)
                        .cornerRadius(16)
                    }
                    .disabled(isCheckingIn)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
                    .accessibilityLabel("Check in")
                    .accessibilityHint(goal.needsProof ? "Double tap to add photo proof" : "Double tap to complete today's goal")
                }
            }
        }
        .navigationTitle(goal?.title ?? "Goal")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadGoal()
            await checkTodayStatus()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Archive Goal?", isPresented: $showingArchiveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                Task { await archiveGoal() }
            }
        } message: {
            Text("This goal will be hidden from your active goals. You can't undo this.")
        }
        .alert("Checked In! ✅", isPresented: $checkInSuccess) {
            Button("OK") { }
        } message: {
            if let goal = goal {
                Text("🔥 Streak: \(goal.currentStreak)")
            }
        }
        .sheet(isPresented: $showingCheckInSheet) {
            CheckInWithProofView(goalId: goalId) { response in
                isCheckedInToday = true
                // Update goal streaks
                if var g = goal {
                    g = Goal(
                        id: g.id, podId: g.podId, podName: g.podName,
                        userId: g.userId, userName: g.userName, userAvatarUrl: g.userAvatarUrl,
                        title: g.title, description: g.description,
                        frequencyType: g.frequencyType, frequencyDays: g.frequencyDays,
                        reminderTime: g.reminderTime, deadlineTime: g.deadlineTime,
                        timezone: g.timezone, requiresProof: g.requiresProof,
                        startDate: g.startDate, endDate: g.endDate,
                        currentStreak: response.currentStreak,
                        longestStreak: response.longestStreak,
                        totalCheckIns: g.totalCheckIns, completedCheckIns: g.completedCheckIns,
                        isArchived: g.isArchived, createdAt: g.createdAt, checkIns: g.checkIns
                    )
                    goal = g
                }
                checkInSuccess = true
            }
        }
    }
    
    @ViewBuilder
    private func goalContent(_ goal: Goal) -> some View {
        List {
            // Stats Section
            Section {
                HStack {
                    StatCard(
                        value: "\(goal.currentStreak)",
                        label: "Current Streak",
                        icon: "flame.fill",
                        color: .orange
                    )
                    
                    StatCard(
                        value: "\(goal.longestStreak)",
                        label: "Best Streak",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }
            
            // Today's Status
            Section {
                HStack {
                    if isCheckedInToday {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.title2)
                        Text("Completed today!")
                            .fontWeight(.medium)
                    } else {
                        Image(systemName: "circle.dotted")
                            .foregroundStyle(.orange)
                            .font(.title2)
                        Text("Not yet checked in")
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
            }
            
            // Details Section
            Section {
                if let description = goal.description {
                    Text(description)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                Label(goal.displayFrequency, systemImage: "calendar")
                
                if let days = goal.frequencyDays, !days.isEmpty {
                    let dayNames = days.sorted().compactMap { Weekday(rawValue: $0)?.shortName }
                    Label(dayNames.joined(separator: ", "), systemImage: "calendar.badge.clock")
                }
                
                if let deadline = goal.deadlineTime {
                    Label("Deadline: \(deadline)", systemImage: "clock")
                }
                
                if let reminder = goal.reminderTime {
                    Label("Reminder: \(reminder)", systemImage: "bell")
                }
                
                if goal.needsProof {
                    Label("Photo proof required", systemImage: "camera")
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Details")
            }
            
            // Check-in History
            Section {
                if let checkIns = goal.checkIns, !checkIns.isEmpty {
                    ForEach(checkIns) { checkIn in
                        CheckInRow(checkIn: checkIn)
                    }
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.badge.questionmark")
                            .foregroundStyle(.secondary)
                        Text("No check-ins yet")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Recent Check-ins")
            }
            
            // Actions
            Section {
                Button(role: .destructive) {
                    showingArchiveAlert = true
                } label: {
                    Label("Archive Goal", systemImage: "archivebox")
                }
            }
            
            // Spacer for floating button
            Section {
                Color.clear.frame(height: 60)
            }
            .listRowBackground(Color.clear)
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadGoal()
            await checkTodayStatus()
        }
    }
    
    private func loadGoal() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            goal = try await GoalService.shared.getGoal(id: goalId)
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load goal"
            print("Load goal error: \(error)")
        }
    }
    
    private func checkTodayStatus() async {
        do {
            let status = try await CheckInService.shared.getTodayStatus(goalId: goalId)
            isCheckedInToday = status.checkedIn
        } catch {
            print("Check today status error: \(error)")
        }
    }
    
    private func quickCheckIn() async {
        isCheckingIn = true
        defer { isCheckingIn = false }
        
        do {
            let response = try await CheckInService.shared.checkIn(goalId: goalId)
            isCheckedInToday = true
            
            // Update goal streaks locally
            goal?.currentStreak = response.currentStreak
            goal?.longestStreak = response.longestStreak
            goal?.todayCheckedIn = true
            
            checkInSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to check in"
            print("Check-in error: \(error)")
        }
    }
    
    private func archiveGoal() async {
        do {
            _ = try await GoalService.shared.archiveGoal(id: goalId)
            dismiss()
        } catch {
            errorMessage = "Failed to archive goal"
        }
    }
}

// MARK: - Check-in With Proof View

struct CheckInWithProofView: View {
    let goalId: String
    let onSuccess: (CheckInResponse) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var comment = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingSourcePicker = false
    
    private var hasPhoto: Bool { capturedImage != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                photoSection
                if hasPhoto {
                    previewSection
                }
                commentSection
            }
            .navigationTitle("Check In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    submitButton
                }
            }
            .confirmationDialog("Add Photo", isPresented: $showingSourcePicker) {
                Button("Take Photo") { showingCamera = true }
                Button("Choose from Library") { showingPhotoLibrary = true }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera) { image in
                    capturedImage = image
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary) { image in
                    capturedImage = image
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
        Section {
            Button {
                showingSourcePicker = true
            } label: {
                HStack {
                    Image(systemName: hasPhoto ? "checkmark.circle.fill" : "camera.fill")
                        .foregroundStyle(hasPhoto ? .green : .secondary)
                    Text(hasPhoto ? "Photo captured" : "Add Photo Proof")
                    Spacer()
                    if hasPhoto {
                        Text("Change")
                    } else {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .tint(.primary)
        } header: {
            Text("Photo Proof")
        } footer: {
            Text("This goal requires photo proof to complete")
        }
    }
    
    @ViewBuilder
    private var previewSection: some View {
        Section {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(8)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }
    
    private var commentSection: some View {
        Section {
            TextField("Add a note (optional)", text: $comment, axis: .vertical)
                .lineLimit(3...5)
        } header: {
            Text("Comment")
        }
    }
    
    @ViewBuilder
    private var submitButton: some View {
        if isLoading {
            ProgressView()
        } else {
            Button("Submit") {
                Task { await submitCheckIn() }
            }
            .disabled(!hasPhoto)
        }
    }
    
    private func submitCheckIn() async {
        isLoading = true
        defer { isLoading = false }
        
        var proofUrl: String? = nil
        
        // Upload photo if captured
        if let image = capturedImage {
            do {
                proofUrl = try await PhotoUploadService.shared.uploadPhoto(image: image, goalId: goalId)
            } catch {
                errorMessage = "Failed to upload photo: \(error.localizedDescription)"
                return
            }
        }
        
        do {
            let response = try await CheckInService.shared.checkIn(
                goalId: goalId,
                comment: comment.isEmpty ? nil : comment,
                proofUrl: proofUrl
            )
            onSuccess(response)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to check in"
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .accessibilityHidden(true)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

// MARK: - Check-in Row

struct CheckInRow: View {
    let checkIn: CheckIn
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading) {
                Text(formattedDate)
                    .font(.body)
                
                if let comment = checkIn.comment {
                    Text(comment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if checkIn.proofUrl != nil {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch checkIn.status {
        case .COMPLETED:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .MISSED:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .SKIPPED:
            Image(systemName: "forward.circle.fill")
                .foregroundStyle(.orange)
        }
    }
    
    private var formattedDate: String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        
        if let date = isoFormatter.date(from: String(checkIn.date.prefix(10))) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return checkIn.date
    }
}

#Preview {
    NavigationStack {
        GoalDetailView(goalId: "preview-id")
    }
}
