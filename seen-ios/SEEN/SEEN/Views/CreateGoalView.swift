//
//  CreateGoalView.swift
//  SEEN
//
//  Form to create a new goal within a pod
//

import SwiftUI

struct CreateGoalView: View {
    let podId: String
    let podName: String
    let onCreated: (Goal) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var description = ""
    @State private var frequencyType: FrequencyType = .DAILY
    @State private var selectedDays: Set<Int> = []
    @State private var deadlineTime = Date()
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var requiresProof = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return false }
        
        if frequencyType == .SPECIFIC_DAYS && selectedDays.isEmpty {
            return false
        }
        
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Goal Info
                Section {
                    TextField("What's your goal?", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("Description (optional)", text: $description, axis: .vertical)
                        .lineLimit(3...5)
                } header: {
                    Text("Goal")
                } footer: {
                    Text("Creating goal in \(podName)")
                }
                
                // Frequency
                Section {
                    Picker("Frequency", selection: $frequencyType) {
                        ForEach(FrequencyType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    
                    if frequencyType == .SPECIFIC_DAYS || frequencyType == .WEEKLY {
                        dayPicker
                    }
                } header: {
                    Text("Schedule")
                } footer: {
                    frequencyFooter
                }
                
                // Deadline
                Section {
                    DatePicker(
                        "Daily Deadline",
                        selection: $deadlineTime,
                        displayedComponents: .hourAndMinute
                    )
                } header: {
                    Text("Deadline")
                } footer: {
                    Text("Complete your goal before this time each day")
                }
                
                // Reminder
                Section {
                    Toggle("Enable Reminder", isOn: $reminderEnabled)
                    
                    if reminderEnabled {
                        DatePicker(
                            "Reminder Time",
                            selection: $reminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Reminder")
                }
                
                // Proof
                Section {
                    Toggle("Require Photo Proof", isOn: $requiresProof)
                } footer: {
                    Text("When enabled, check-ins require a photo")
                }
            }
            .navigationTitle("New Goal")
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
                            Task { await createGoal() }
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
    
    // MARK: - Day Picker
    
    private var dayPicker: some View {
        HStack(spacing: 8) {
            ForEach(Weekday.allCases, id: \.rawValue) { day in
                Button {
                    if frequencyType == .WEEKLY {
                        // Single selection for weekly
                        selectedDays = [day.rawValue]
                    } else {
                        // Multi selection for specific days
                        if selectedDays.contains(day.rawValue) {
                            selectedDays.remove(day.rawValue)
                        } else {
                            selectedDays.insert(day.rawValue)
                        }
                    }
                } label: {
                    Text(day.initial)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 44, height: 44) // Accessibility: 44pt min
                        .background(
                            selectedDays.contains(day.rawValue)
                                ? Color.accentColor
                                : Color(.systemGray5)
                        )
                        .foregroundStyle(
                            selectedDays.contains(day.rawValue)
                                ? .white
                                : .primary
                        )
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortName)
                .accessibilityAddTraits(selectedDays.contains(day.rawValue) ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Select days")
    }
    
    @ViewBuilder
    private var frequencyFooter: some View {
        switch frequencyType {
        case .DAILY:
            Text("Goal repeats every day")
        case .WEEKLY:
            Text("Goal repeats once per week")
        case .SPECIFIC_DAYS:
            if selectedDays.isEmpty {
                Text("Select at least one day")
                    .foregroundStyle(.red)
            } else {
                let days = selectedDays.sorted().compactMap { Weekday(rawValue: $0)?.shortName }
                Text("Goal repeats on \(days.joined(separator: ", "))")
            }
        }
    }
    
    // MARK: - Create Goal
    
    private func createGoal() async {
        isLoading = true
        defer { isLoading = false }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let deadlineStr = formatter.string(from: deadlineTime)
        let reminderStr = reminderEnabled ? formatter.string(from: reminderTime) : nil
        
        var days: [Int]? = nil
        if frequencyType == .SPECIFIC_DAYS || frequencyType == .WEEKLY {
            days = Array(selectedDays).sorted()
        }
        
        do {
            let goal = try await GoalService.shared.createGoal(
                podId: podId,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                description: description.isEmpty ? nil : description.trimmingCharacters(in: .whitespacesAndNewlines),
                frequencyType: frequencyType,
                frequencyDays: days,
                reminderTime: reminderStr,
                deadlineTime: deadlineStr,
                requiresProof: requiresProof
            )
            onCreated(goal)
            dismiss()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "Failed to create goal"
            print("Create goal error: \(error)")
        }
    }
}

#Preview {
    CreateGoalView(podId: "test", podName: "Test Pod") { _ in }
}
