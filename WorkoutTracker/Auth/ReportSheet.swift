//
//  ReportSheet.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 30.05.2026.
//

//
//  ReportSheet.swift
//  WorkoutTracker
//
//  Sheet UI for reporting shared workouts. Required by App Review Guideline
//  1.2 — UGC must offer per-item reporting and per-user blocking.
//

internal import SwiftUI
import OSLog

enum ReportReason: String, CaseIterable, Identifiable {
    case spam
    case hate
    case harassment
    case sexual
    case violence
    case dangerous
    case other

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .spam:       return String(localized: "Spam")
        case .hate:       return String(localized: "Hate Speech")
        case .harassment: return String(localized: "Harassment")
        case .sexual:     return String(localized: "Sexual Content")
        case .violence:   return String(localized: "Violence")
        case .dangerous:  return String(localized: "Dangerous Content")
        case .other:      return String(localized: "Other")
        }
    }
}

/// Sheet shown from a shared workout's overflow menu.
/// Submits a report and optionally blocks the creator.
struct ReportSheet: View {

    let workoutId: String
    let creatorUid: String

    @Environment(\.dismiss) private var dismiss

    @State private var selectedReason: ReportReason = .spam
    @State private var details: String = ""
    @State private var alsoBlock: Bool = true
    @State private var isSubmitting: Bool = false
    @State private var error: String?
    @State private var didSubmit: Bool = false

    private let log = Logger(subsystem: "com.borisdev.WorkoutTracker", category: "Report")

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Select a reason", selection: $selectedReason) {
                        ForEach(ReportReason.allCases) { reason in
                            Text(reason.localizedTitle).tag(reason)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Reason")
                } footer: {
                    Text("Why are you reporting this workout?")
                }

                Section {
                    TextField("Additional details...", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Details")
                }

                Section {
                    Toggle("Also block this user", isOn: $alsoBlock)
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle("Report Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("Submit")
                        }
                    }
                    .disabled(isSubmitting || didSubmit)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .alert("Report Submitted", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text("Thank you for your report.")
            }
        }
    }

    @MainActor
    private func submit() async {
        isSubmitting = true
        error = nil

        do {

            try await FirestoreProgramService.shared.reportWorkout(
                id: workoutId,
                reason: selectedReason.rawValue,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines)
            )

            if alsoBlock {
                try await BlockedUsersStore.shared.block(uid: creatorUid)
            }

            log.info("Report submitted workoutId=\(workoutId, privacy: .public) reason=\(selectedReason.rawValue, privacy: .public) block=\(alsoBlock)")
            didSubmit = true
        } catch {
            log.error("Report failed: \(error.localizedDescription, privacy: .public)")
            self.error = error.localizedDescription
        }

        isSubmitting = false
    }
}
