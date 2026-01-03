//
//  CreatePodView.swift
//  SEEN
//
//  Form to create a new pod
//

import SwiftUI

struct CreatePodView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onCreated: (Pod) -> Void
    
    @State private var name = ""
    @State private var description = ""
    @State private var stakes = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Pod Name", text: $name)
                        .textInputAutocapitalization(.words)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Pod Info")
                } footer: {
                    Text("Give your pod a memorable name")
                }
                
                Section {
                    TextField("What's at stake?", text: $stakes)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Stakes (Optional)")
                } footer: {
                    Text("e.g., \"$10 to group pot for each miss\" or \"Loser buys coffee\"")
                }
            }
            .navigationTitle("Create Pod")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Button("Create") {
                            Task { await createPod() }
                        }
                        .disabled(!isValid)
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .disabled(isLoading)
        }
    }
    
    private func createPod() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let pod = try await PodService.shared.createPod(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                stakes: stakes.isEmpty ? nil : stakes.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onCreated(pod)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to create pod"
            print("Create pod error: \(error)")
        }
    }
}

#Preview {
    CreatePodView { _ in }
}
