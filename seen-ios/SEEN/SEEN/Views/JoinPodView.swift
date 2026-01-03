//
//  JoinPodView.swift
//  SEEN
//
//  Enter invite code to join a pod - HIG Compliant
//

import SwiftUI

struct JoinPodView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onJoined: (Pod) async -> Void
    
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var joinedPod: Pod?
    @State private var showingSuccess = false
    
    var isValid: Bool {
        inviteCode.trimmingCharacters(in: .whitespacesAndNewlines).count == 6
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.secondary)
                    
                    Text("Join a Pod")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Enter the 6-character invite code")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                
                // Code input
                TextField("ABCDEF", text: $inviteCode)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.center)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 48)
                    .accessibilityLabel("Invite code")
                    .accessibilityHint("Enter the 6-character invite code")
                    .onChange(of: inviteCode) { _, newValue in
                        // Limit to 6 characters
                        if newValue.count > 6 {
                            inviteCode = String(newValue.prefix(6))
                        }
                    }
                
                Spacer()
                
                // Join button
                Button(action: { Task { await joinPod() } }) {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Join Pod")
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44) // Accessibility: 44pt min
                .padding()
                .background(isValid ? Color.accentColor : Color.gray)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .disabled(!isValid || isLoading)
                .accessibilityLabel("Join pod")
                .accessibilityHint(isValid ? "Double tap to join with this invite code" : "Enter a valid 6-character code first")
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Joined!", isPresented: $showingSuccess) {
                Button("OK") {
                    Task {
                        if let pod = joinedPod {
                            await onJoined(pod)
                        }
                        dismiss()
                    }
                }
            } message: {
                if let pod = joinedPod {
                    Text("You joined \(pod.name)!")
                }
            }
        }
    }
    
    private func joinPod() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let pod = try await PodService.shared.joinPod(
                inviteCode: inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            joinedPod = pod
            showingSuccess = true
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to join pod"
            print("Join pod error: \(error)")
        }
    }
}

#Preview {
    JoinPodView { _ in }
}
