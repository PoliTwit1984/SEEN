//
//  PodRingsView.swift
//  SEEN
//
//  Horizontal scrolling pod rings with activity indicators (Instagram Stories style)
//

import SwiftUI

struct PodRingsView: View {
    let pods: [PodWithStatus]
    let onAddTap: () -> Void
    let onPodTap: (PodWithStatus) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Add new pod button
                AddPodButton(action: onAddTap)
                
                // Pod rings
                ForEach(pods) { pod in
                    PodRing(pod: pod) {
                        onPodTap(pod)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Add Pod Button

private struct AddPodButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            Color.secondary.opacity(0.3),
                            style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                        )
                        .frame(width: 68, height: 68)
                    
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                
                Text("New Pod")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 76)
        }
        .accessibilityLabel("Create or join a pod")
        .accessibilityHint("Double tap to add a new pod")
    }
}

// MARK: - Pod Ring

private struct PodRing: View {
    let pod: PodWithStatus
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    // Activity ring (green if new activity)
                    Circle()
                        .strokeBorder(
                            pod.hasNewActivity 
                                ? LinearGradient(
                                    colors: [Color.seenGreen, Color.seenMint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                : LinearGradient(
                                    colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                            lineWidth: 3
                        )
                        .frame(width: 68, height: 68)
                    
                    // Pod avatar (photo or initial)
                    if let photoUrl = pod.latestCheckInPhoto, let url = URL(string: photoUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure, .empty:
                                podInitial
                            @unknown default:
                                podInitial
                            }
                        }
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                    } else {
                        podInitial
                    }
                    
                    // Pending goals badge (small dot)
                    if pod.myPendingGoals > 0 {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Text("\(pod.myPendingGoals)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 26, y: -26)
                    }
                }
                
                Text(pod.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(width: 76)
        }
        .accessibilityLabel("\(pod.name), \(pod.memberCount) members")
        .accessibilityHint(pod.hasNewActivity ? "Has new activity, double tap to view" : "Double tap to view pod stories")
        .accessibilityValue(pod.myPendingGoals > 0 ? "\(pod.myPendingGoals) goals due" : "")
    }
    
    private var podInitial: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Color.seenGreen.opacity(0.3), Color.seenMint.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 60, height: 60)
            .overlay(
                Text(String(pod.name.prefix(1)).uppercased())
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.seenGreen)
            )
    }
}

#Preview {
    VStack {
        PodRingsView(
            pods: [
                PodWithStatus(id: "1", name: "Run Club", memberCount: 4, maxMembers: 8, hasNewActivity: true, latestCheckInPhoto: nil, unreadCount: 3, myPendingGoals: 1),
                PodWithStatus(id: "2", name: "Early Risers", memberCount: 5, maxMembers: 8, hasNewActivity: true, latestCheckInPhoto: nil, unreadCount: 1, myPendingGoals: 0),
                PodWithStatus(id: "3", name: "Work Goals", memberCount: 3, maxMembers: 8, hasNewActivity: false, latestCheckInPhoto: nil, unreadCount: 0, myPendingGoals: 2),
            ],
            onAddTap: {},
            onPodTap: { _ in }
        )
        Spacer()
    }
    .background(Color(.systemBackground))
}
