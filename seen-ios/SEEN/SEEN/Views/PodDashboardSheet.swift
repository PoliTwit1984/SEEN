//
//  PodDashboardSheet.swift
//  SEEN
//
//  Full pod dashboard showing members, health, and activity
//

import SwiftUI

struct PodDashboardSheet: View {
    let podId: String

    @Environment(\.dismiss) private var dismiss
    @State private var pod: Pod?
    @State private var members: [MemberWithStatus] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingInvite = false
    @State private var selectedMember: MemberWithStatus?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    ProgressView("Loading...")
                        .padding(.top, 100)
                } else if let pod = pod {
                    VStack(spacing: 24) {
                        // Pod header
                        podHeader(pod)
                        
                        // Health summary
                        healthSummary
                        
                        // Members grid
                        membersSection
                        
                        // Actions
                        actionsSection
                    }
                    .padding()
                }
            }
            .navigationTitle(pod?.name ?? "Pod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingInvite = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                }
            }
            .task {
                await loadData()
            }
            .sheet(isPresented: $showingInvite) {
                if let pod = pod {
                    InviteSheet(inviteCode: pod.inviteCode ?? "", podName: pod.name)
                }
            }
            .sheet(item: $selectedMember) { member in
                SimpleMemberDetailSheet(member: member)
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func podHeader(_ pod: Pod) -> some View {
        VStack(spacing: 12) {
            // Pod avatar (could be photo or initials)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.seenGreen, .seenMint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(pod.name.prefix(1)).uppercased())
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                )
            
            Text(pod.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let description = pod.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let stakes = pod.stakes, !stakes.isEmpty {
                HStack {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text(stakes)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }
    
    private var healthSummary: some View {
        VStack(spacing: 16) {
            Text("TODAY'S PROGRESS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 24) {
                StatBox(value: "\(checkedInCount)/\(totalWithGoals)", label: "Checked In", color: .seenGreen)
                StatBox(value: "\(pendingCount)", label: "Pending", color: .orange)
                StatBox(value: "\(members.count)", label: "Members", color: .seenBlue)
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.seenGreen)
                        .frame(width: geo.size.width * completionRate, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MEMBERS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                ForEach(members) { member in
                    MemberCard(member: member) {
                        selectedMember = member
                    }
                }
            }
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            // Encourage those who need it
            if !membersNeedingEncouragement.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("NEEDS ENCOURAGEMENT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    
                    ForEach(membersNeedingEncouragement) { member in
                        HStack {
                            AsyncImage(url: URL(string: member.avatarUrl ?? "")) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Circle().fill(Color.seenGreen.opacity(0.3))
                            }
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())
                            
                            Text(member.name)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Button("Nudge") {
                                // Send nudge
                            }
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.seenMint.opacity(0.2))
                            .clipShape(Capsule())
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
    
    // Computed properties
    private var checkedInCount: Int { members.filter { $0.status == .completed }.count }
    private var pendingCount: Int { members.filter { $0.status == .pending }.count }
    private var totalWithGoals: Int { members.filter { $0.status != .noGoals }.count }
    private var completionRate: CGFloat {
        guard totalWithGoals > 0 else { return 0 }
        return CGFloat(checkedInCount) / CGFloat(totalWithGoals)
    }
    private var membersNeedingEncouragement: [MemberWithStatus] {
        members.filter { $0.status == .pending }
    }
    
    private func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Fetch pod details and member statuses in parallel
            async let podTask = PodService.shared.getPod(id: podId)
            async let membersTask = PostService.shared.getMemberStatuses(podId: podId)

            let (fetchedPod, memberStatuses) = try await (podTask, membersTask)
            pod = fetchedPod

            // Map MemberStatusWithGoals to MemberWithStatus
            members = memberStatuses.map { status in
                MemberWithStatus(
                    id: status.userId,
                    name: status.name,
                    avatarUrl: status.avatarUrl,
                    status: mapStatus(status.todayStatus),
                    streak: status.currentStreak,
                    role: .MEMBER // Role not available in status response
                )
            }
        } catch {
            print("Failed to load pod data: \(error)")
            errorMessage = "Failed to load pod data"
        }
    }

    private func mapStatus(_ status: MemberTodayStatus) -> MemberWithStatus.MemberStatus {
        switch status {
        case .completed: return .completed
        case .pending: return .pending
        case .missed: return .missed
        case .no_goals: return .noGoals
        }
    }
}

// MARK: - Member with Status

struct MemberWithStatus: Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let status: MemberStatus
    let streak: Int
    let role: MemberRole
    
    enum MemberStatus {
        case completed
        case pending
        case missed
        case noGoals
        
        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .pending: return "clock.fill"
            case .missed: return "xmark.circle.fill"
            case .noGoals: return "minus.circle"
            }
        }
        
        var color: Color {
            switch self {
            case .completed: return .seenGreen
            case .pending: return .orange
            case .missed: return .red
            case .noGoals: return .gray
            }
        }
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Member Card

struct MemberCard: View {
    let member: MemberWithStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: member.avatarUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.seenGreen.opacity(0.3), .seenBlue.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Text(String(member.name.prefix(1)))
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.primary)
                            )
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(member.status.color, lineWidth: 2)
                    )
                    
                    Image(systemName: member.status.icon)
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(member.status.color)
                        .clipShape(Circle())
                        .offset(x: 4, y: 4)
                }
                
                Text(member.name)
                    .font(.caption)
                    .lineLimit(1)
                
                if member.streak > 0 {
                    Text("🔥\(member.streak)")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple Member Detail Sheet (for Pod Dashboard)

struct SimpleMemberDetailSheet: View {
    let member: MemberWithStatus
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Avatar
                AsyncImage(url: URL(string: member.avatarUrl ?? "")) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.seenGreen.opacity(0.3))
                        .overlay(
                            Text(String(member.name.prefix(1)))
                                .font(.largeTitle)
                                .fontWeight(.bold)
                        )
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                
                Text(member.name)
                    .font(.title)
                    .fontWeight(.bold)
                
                // Stats
                HStack(spacing: 32) {
                    VStack {
                        Text("\(member.streak)")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.orange)
                        Text("Day Streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    VStack {
                        Image(systemName: member.status.icon)
                            .font(.title)
                            .foregroundStyle(member.status.color)
                        Text(statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Actions
                VStack(spacing: 12) {
                    Button {
                        // Send encouragement
                    } label: {
                        Label("Send Encouragement", systemImage: "heart.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassPrimary)
                    
                    Button {
                        // Send nudge
                    } label: {
                        Label("Send Nudge", systemImage: "hand.point.up.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassSecondary)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 32)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusText: String {
        switch member.status {
        case .completed: return "Checked In"
        case .pending: return "Pending"
        case .missed: return "Missed"
        case .noGoals: return "No Goals"
        }
    }
}

// MARK: - Invite Sheet

struct InviteSheet: View {
    let inviteCode: String
    let podName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.seenGreen)
                
                Text("Invite to \(podName)")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Share this code with friends to invite them to your pod")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                // Code display
                HStack {
                    Text(inviteCode)
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                    
                    Button {
                        UIPasteboard.general.string = inviteCode
                        withAnimation { copied = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .foregroundStyle(copied ? .seenGreen : .secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if copied {
                    Text("Copied!")
                        .font(.caption)
                        .foregroundStyle(.seenGreen)
                }
                
                Button {
                    // Share sheet
                    let shareText = "Join my pod \"\(podName)\" on SEEN! Use code: \(inviteCode)"
                    let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                       let window = scene.windows.first,
                       let rootVC = window.rootViewController {
                        rootVC.present(av, animated: true)
                    }
                } label: {
                    Label("Share Invite", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassPrimary)
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PodDashboardSheet(podId: "pod1")
}
