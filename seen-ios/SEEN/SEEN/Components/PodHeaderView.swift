//
//  PodHeaderView.swift
//  SEEN
//
//  Collapsible header showing pod details when a pod is selected
//

import SwiftUI

struct PodHeaderView: View {
    let pod: PodRingData
    let podItem: PodListItem
    let onViewDetails: () -> Void
    
    @State private var isExpanded = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Main header content
            HStack(spacing: 12) {
                // Pod info
                VStack(alignment: .leading, spacing: 4) {
                    Text(podItem.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    if isExpanded, let description = podItem.description {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // Member avatars stack
                MemberAvatarsStack(avatars: podItem.memberAvatars ?? [])
                
                // Expand/collapse button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            
            // Expanded content
            if isExpanded {
                VStack(spacing: 12) {
                    // Health status bar
                    HStack(spacing: 16) {
                        // Status indicator
                        StatusPill(
                            icon: statusIcon,
                            text: podItem.healthStatus,
                            color: pod.status.ringColor
                        )
                        
                        Spacer()
                        
                        // View details button
                        Button {
                            onViewDetails()
                        } label: {
                            HStack(spacing: 4) {
                                Text("View All")
                                Image(systemName: "chevron.right")
                            }
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.seenGreen)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Stakes if present
                    if let stakes = podItem.stakes, !stakes.isEmpty {
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("Stakes: \(stakes)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 12)
            }
        }
        .background(.ultraThinMaterial)
    }
    
    private var statusIcon: String {
        switch pod.status {
        case .allCompleted: return "checkmark.circle.fill"
        case .hasPending: return "clock.fill"
        case .noGoals: return "minus.circle.fill"
        case .hasNewActivity: return "sparkles"
        }
    }
}

// MARK: - Member Avatars Stack

struct MemberAvatarsStack: View {
    let avatars: [String]
    let maxDisplay = 4
    
    var body: some View {
        HStack(spacing: -8) {
            ForEach(Array(avatars.prefix(maxDisplay).enumerated()), id: \.offset) { index, avatarUrl in
                AsyncImage(url: URL(string: avatarUrl)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        Circle()
                            .fill(Color.seenGreen.opacity(0.3))
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                .zIndex(Double(maxDisplay - index))
            }
            
            // +N indicator if more members
            if avatars.count > maxDisplay {
                Text("+\(avatars.count - maxDisplay)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.seenBlue)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
            }
        }
    }
}

// MARK: - Status Pill

struct StatusPill: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}

#Preview {
    VStack {
        PodHeaderView(
            pod: PodRingData(
                id: "1",
                name: "Fitness Squad",
                status: .allCompleted,
                hasNewActivity: true,
                isAllPods: false,
                photoUrl: nil
            ),
            podItem: PodListItem(
                id: "1",
                name: "Fitness Squad",
                description: "Daily workouts and fitness challenges. Let's get fit together! 💪",
                stakes: "Loser buys coffee",
                memberCount: 4,
                maxMembers: 6,
                role: .MEMBER,
                joinedAt: "",
                createdAt: "",
                memberAvatars: ["https://i.pravatar.cc/100?img=5", "https://i.pravatar.cc/100?img=8", "https://i.pravatar.cc/100?img=12", "https://i.pravatar.cc/100?img=23"],
                checkedInCount: 3,
                totalMembersWithGoals: 4
            ),
            onViewDetails: {}
        )
        Spacer()
    }
}
