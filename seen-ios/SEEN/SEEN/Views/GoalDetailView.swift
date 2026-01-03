//
//  GoalDetailView.swift
//  SEEN
//
//  Goal details with check-in history
//

import SwiftUI

struct GoalDetailView: View {
    let goalId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var goal: Goal?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingArchiveAlert = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let goal = goal {
                goalContent(goal)
            } else {
                ContentUnavailableView("Goal Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(goal?.title ?? "Goal")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await loadGoal()
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
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadGoal()
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
    
    private func archiveGoal() async {
        do {
            _ = try await GoalService.shared.archiveGoal(id: goalId)
            dismiss()
        } catch {
            errorMessage = "Failed to archive goal"
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
        // Simple date formatting - the date string is in ISO format
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
