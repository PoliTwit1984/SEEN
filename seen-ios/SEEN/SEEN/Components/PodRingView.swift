//
//  PodRingView.swift
//  SEEN
//
//  Pod ring component for stories-style navigation
//

import SwiftUI

// MARK: - Pod Ring Status

enum PodRingStatus {
    case allCompleted    // All members checked in - green
    case hasPending      // Some pending - orange
    case noGoals         // No active goals today - gray
    case hasNewActivity  // Unseen posts - adds dot indicator
    
    var ringColor: Color {
        switch self {
        case .allCompleted: return .seenGreen
        case .hasPending: return .orange
        case .noGoals: return .gray.opacity(0.5)
        case .hasNewActivity: return .seenGreen
        }
    }
}

// MARK: - Pod Ring Data

struct PodRingData: Identifiable, Equatable {
    let id: String
    let name: String
    let status: PodRingStatus
    let hasNewActivity: Bool
    let isAllPods: Bool
    let photoUrl: String?          // Latest check-in photo
    let memberAvatars: [String]    // Fallback: member avatar URLs
    
    init(id: String, name: String, status: PodRingStatus, hasNewActivity: Bool, isAllPods: Bool, photoUrl: String? = nil, memberAvatars: [String] = []) {
        self.id = id
        self.name = name
        self.status = status
        self.hasNewActivity = hasNewActivity
        self.isAllPods = isAllPods
        self.photoUrl = photoUrl
        self.memberAvatars = memberAvatars
    }
    
    static let allPods = PodRingData(
        id: "all",
        name: "All",
        status: .allCompleted,
        hasNewActivity: false,
        isAllPods: true
    )
    
    static func == (lhs: PodRingData, rhs: PodRingData) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Pod Ring View

struct PodRingView: View {
    let pod: PodRingData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack {
                    // Ring background with gradient for visual interest
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: isSelected 
                                    ? [pod.status.ringColor, pod.status.ringColor.opacity(0.7)]
                                    : [pod.status.ringColor.opacity(0.6), pod.status.ringColor.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: isSelected ? 3 : 2
                        )
                        .frame(width: 68, height: 68)
                    
                    // Inner content - photo, avatars, or icon
                    innerContent
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    
                    // New activity indicator
                    if pod.hasNewActivity {
                        Circle()
                            .fill(.seenGreen)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .strokeBorder(.white, lineWidth: 2)
                            )
                            .offset(x: 24, y: -24)
                    }
                }
                
                // Pod name
                Text(pod.name)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .frame(width: 72)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pod.name) pod")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(pod.hasNewActivity ? "Has new activity" : "")
    }
    
    @ViewBuilder
    private var innerContent: some View {
        if pod.isAllPods {
            // "All" icon
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .seenGreen : .secondary)
            }
        } else if let photoUrl = pod.photoUrl, let url = URL(string: photoUrl) {
            // Show latest check-in photo
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    fallbackContent
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    fallbackContent
                @unknown default:
                    fallbackContent
                }
            }
        } else if !pod.memberAvatars.isEmpty {
            // Show member avatar collage
            memberAvatarCollage
        } else {
            // Fallback to initial
            fallbackContent
        }
    }
    
    private var fallbackContent: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [pod.status.ringColor.opacity(0.3), pod.status.ringColor.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(String(pod.name.prefix(1)).uppercased())
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(pod.status.ringColor)
        }
    }
    
    private var memberAvatarCollage: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                
                // Show up to 3 avatars in a stacked layout
                let avatarsToShow = Array(pod.memberAvatars.prefix(3))
                ForEach(Array(avatarsToShow.enumerated()), id: \.offset) { index, avatarUrl in
                    if let url = URL(string: avatarUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 28, height: 28)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 1))
                            default:
                                Circle()
                                    .fill(Color.seenGreen.opacity(0.3))
                                    .frame(width: 28, height: 28)
                            }
                        }
                        .offset(
                            x: CGFloat(index - 1) * 12,
                            y: index == 1 ? -8 : 8
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Pod Rings Scroll View

struct PodRingsScrollView: View {
    let pods: [PodRingData]
    @Binding var selectedPodId: String
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // "All" option first
                PodRingView(
                    pod: .allPods,
                    isSelected: selectedPodId == "all"
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPodId = "all"
                    }
                }
                
                // Individual pods
                ForEach(pods) { pod in
                    PodRingView(
                        pod: pod,
                        isSelected: selectedPodId == pod.id
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedPodId = pod.id
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        PodRingsScrollView(
            pods: [
                PodRingData(
                    id: "1", 
                    name: "Fitness Squad", 
                    status: .allCompleted, 
                    hasNewActivity: true, 
                    isAllPods: false,
                    photoUrl: "https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?w=200"
                ),
                PodRingData(
                    id: "2", 
                    name: "Book Club", 
                    status: .hasPending, 
                    hasNewActivity: false, 
                    isAllPods: false,
                    memberAvatars: ["https://i.pravatar.cc/100?img=1", "https://i.pravatar.cc/100?img=2", "https://i.pravatar.cc/100?img=3"]
                ),
                PodRingData(
                    id: "3", 
                    name: "Morning Routines", 
                    status: .noGoals, 
                    hasNewActivity: true, 
                    isAllPods: false,
                    photoUrl: "https://images.unsplash.com/photo-1545389336-cf090694435e?w=200"
                ),
            ],
            selectedPodId: .constant("all")
        )
        Spacer()
    }
}
