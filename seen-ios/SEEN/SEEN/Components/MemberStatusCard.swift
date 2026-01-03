import SwiftUI

struct MemberStatusCard: View {
    let member: MemberStatus
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Avatar with status ring
                ZStack {
                    // Status ring
                    Circle()
                        .strokeBorder(statusColor, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    
                    // Avatar
                    if let avatarUrl = member.avatarUrl, let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            initialsView
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                    } else {
                        initialsView
                    }
                    
                    // Streak badge
                    if member.currentStreak > 0 {
                        Text("🔥\(member.currentStreak)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .offset(x: 20, y: -24)
                    }
                }
                
                // Name
                Text(member.isCurrentUser == true ? "You" : member.name.components(separatedBy: " ").first ?? member.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                
                // Status indicator
                Text(member.todayStatus.emoji)
                    .font(.caption)
            }
            .frame(width: 80)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(member.name), \(member.todayStatus.displayText), \(member.currentStreak) day streak")
            .accessibilityHint("Double tap to view details and send encouragement")
        }
        .buttonStyle(.plain)
    }
    
    private var initialsView: some View {
        Circle()
            .fill(Color.seenBlue.opacity(0.2))
            .frame(width: 56, height: 56)
            .overlay {
                Text(String(member.name.prefix(1)))
                    .font(.title2)
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
}

// MARK: - Needs Encouragement Card

struct NeedsEncouragementCard: View {
    let member: NeedsEncouragementMember
    let onCheer: () -> Void
    let onNudge: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(Color.seenBlue.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay {
                    Text(String(member.name.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
            
            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(member.pendingGoals) goal\(member.pendingGoals == 1 ? "" : "s") pending")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                Button {
                    onNudge()
                } label: {
                    Image(systemName: "hand.point.right.fill")
                        .font(.title3)
                        .foregroundStyle(.orange)
                        .frame(width: 44, height: 44)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Nudge \(member.name)")
                
                Button {
                    onCheer()
                } label: {
                    Image(systemName: "hands.clap.fill")
                        .font(.title3)
                        .foregroundStyle(.seenGreen)
                        .frame(width: 44, height: 44)
                        .background(Color.seenGreen.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Cheer for \(member.name)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Pod Health Indicator

struct PodHealthIndicator: View {
    let health: PodHealth
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pod Health")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(health.completedToday)/\(health.membersWithGoals) checked in")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Health dots
            HStack(spacing: 6) {
                ForEach(0..<health.totalMembers, id: \.self) { index in
                    Circle()
                        .fill(dotColor(for: index))
                        .frame(width: 12, height: 12)
                }
            }
            .accessibilityLabel("\(health.completedToday) completed, \(health.pendingToday) pending, \(health.missedToday) missed")
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func dotColor(for index: Int) -> Color {
        if index < health.completedToday {
            return .seenGreen
        } else if index < health.completedToday + health.pendingToday {
            return .orange
        } else if index < health.completedToday + health.pendingToday + health.missedToday {
            return .red
        } else {
            return .gray.opacity(0.3)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack {
            MemberStatusCard(
                member: MemberStatus(
                    userId: "1",
                    name: "Alex Johnson",
                    avatarUrl: nil,
                    todayStatus: .completed,
                    currentStreak: 5,
                    totalGoals: 2,
                    completedToday: 2,
                    pendingToday: 0,
                    isCurrentUser: false
                )
            ) { }
            
            MemberStatusCard(
                member: MemberStatus(
                    userId: "2",
                    name: "Sam Smith",
                    avatarUrl: nil,
                    todayStatus: .pending,
                    currentStreak: 0,
                    totalGoals: 1,
                    completedToday: 0,
                    pendingToday: 1,
                    isCurrentUser: false
                )
            ) { }
            
            MemberStatusCard(
                member: MemberStatus(
                    userId: "3",
                    name: "You",
                    avatarUrl: nil,
                    todayStatus: .completed,
                    currentStreak: 3,
                    totalGoals: 1,
                    completedToday: 1,
                    pendingToday: 0,
                    isCurrentUser: true
                )
            ) { }
        }
        
        NeedsEncouragementCard(
            member: NeedsEncouragementMember(
                userId: "2",
                name: "Sam Smith",
                avatarUrl: nil,
                status: .pending,
                pendingGoals: 2
            ),
            onCheer: { },
            onNudge: { }
        )
        
        PodHealthIndicator(
            health: PodHealth(
                totalMembers: 5,
                membersWithGoals: 4,
                completedToday: 2,
                pendingToday: 1,
                missedToday: 1
            )
        )
    }
    .padding()
}
