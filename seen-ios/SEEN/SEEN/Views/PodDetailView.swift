//
//  PodDetailView.swift
//  SEEN
//
//  Pod details with members and goals
//

import SwiftUI

struct PodDetailView: View {
    let podId: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var pod: Pod?
    @State private var goals: [Goal] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingInviteCode = false
    @State private var copiedCode = false
    @State private var showingCreateGoal = false
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading...")
            } else if let pod = pod {
                podContent(pod)
            } else {
                ContentUnavailableView("Pod Not Found", systemImage: "exclamationmark.triangle")
            }
        }
        .navigationTitle(pod?.name ?? "Pod")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if pod != nil {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateGoal) {
            if let pod = pod {
                CreateGoalView(podId: podId, podName: pod.name) { newGoal in
                    goals.insert(newGoal, at: 0)
                }
            }
        }
        .task {
            await loadData()
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private func podContent(_ pod: Pod) -> some View {
        List {
            // Description & Stakes
            if pod.description != nil || pod.stakes != nil {
                Section {
                    if let description = pod.description {
                        Text(description)
                            .font(.body)
                    }
                    if let stakes = pod.stakes {
                        Label(stakes, systemImage: "flame.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Goals Section
            Section {
                if goals.isEmpty {
                    Button {
                        showingCreateGoal = true
                    } label: {
                        HStack {
                            Image(systemName: "target")
                                .foregroundStyle(.secondary)
                            Text("Add your first goal")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "plus.circle")
                                .tint(.accentColor)
                        }
                    }
                    .tint(.primary)
                } else {
                    ForEach(goals) { goal in
                        NavigationLink(destination: GoalDetailView(goalId: goal.id)) {
                            GoalRow(goal: goal)
                        }
                    }
                }
            } header: {
                HStack {
                    Text("Goals")
                    Spacer()
                    if !goals.isEmpty {
                        Text("\(goals.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Members
            Section {
                ForEach(pod.members ?? []) { member in
                    HStack {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 40, height: 40)
                            .overlay {
                                Text(String(member.name.prefix(1)))
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                        
                        VStack(alignment: .leading) {
                            Text(member.name)
                                .font(.body)
                            
                            Text(member.role == .OWNER ? "Owner" : "Member")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            } header: {
                let count = pod.members?.count ?? 0
                Text("Members (\(count)/\(pod.maxMembers))")
            }
            
            // Invite Code
            Section {
                Button(action: { showInviteCode(pod.inviteCode ?? "") }) {
                    HStack {
                        Label("Invite Code", systemImage: "ticket")
                        Spacer()
                        if showingInviteCode {
                            Text(pod.inviteCode ?? "")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.medium)
                        } else {
                            Text("Tap to reveal")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .tint(.primary)
                
                if showingInviteCode {
                    Button(action: { copyInviteCode(pod.inviteCode ?? "") }) {
                        HStack {
                            Label(copiedCode ? "Copied!" : "Copy Code", systemImage: copiedCode ? "checkmark" : "doc.on.doc")
                            Spacer()
                        }
                    }
                    .tint(copiedCode ? .green : .accentColor)
                }
            } header: {
                Text("Invite Friends")
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let podTask = PodService.shared.getPod(id: podId)
            async let goalsTask = GoalService.shared.getPodGoals(podId: podId)
            
            pod = try await podTask
            goals = try await goalsTask
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to load pod"
            print("Load pod error: \(error)")
        }
    }
    
    private func showInviteCode(_ code: String) {
        withAnimation {
            showingInviteCode.toggle()
        }
    }
    
    private func copyInviteCode(_ code: String) {
        UIPasteboard.general.string = code
        withAnimation {
            copiedCode = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                copiedCode = false
            }
        }
    }
}

// MARK: - Goal Row

struct GoalRow: View {
    let goal: Goal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(goal.title)
                    .font(.headline)
                
                Spacer()
                
                if goal.currentStreak > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(goal.currentStreak)")
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
            }
            
            HStack {
                if let userName = goal.userName {
                    Label(userName, systemImage: "person")
                } else {
                    Label(goal.displayFrequency, systemImage: "calendar")
                }
                
                if goal.needsProof {
                    Label("Photo", systemImage: "camera")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PodDetailView(podId: "preview-id")
    }
}
