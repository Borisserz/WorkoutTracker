//
//  CommunityGuidelinesGate.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 30.05.2026.
//

internal import SwiftUI

/// Persisted flag: has the user accepted the UGC terms at least once.
enum UGCConsent {
    static let storageKey = "hasAcceptedUGCTerms_v1"
}

/// Mandatory acceptance sheet shown before the user can publish UGC.
struct CommunityGuidelinesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(UGCConsent.storageKey) private var hasAccepted = false
    @State private var agreed = false

    /// Called only after the user explicitly agrees.
    let onAccept: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStringKey("Community Guidelines"))
                        .font(.title2).bold()

                    Text(LocalizedStringKey("Before you share content with the community, please agree to our rules. We have a ZERO-TOLERANCE policy for objectionable content and abusive behavior."))

                    VStack(alignment: .leading, spacing: 8) {
                        Label(LocalizedStringKey("No sexual, hateful, violent, or illegal content"), systemImage: "xmark.octagon.fill")
                        Label(LocalizedStringKey("No harassment, spam, or others’ personal data"), systemImage: "xmark.octagon.fill")
                        Label(LocalizedStringKey("Violations lead to content removal and bans"), systemImage: "exclamationmark.shield.fill")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                    HStack(spacing: 16) {
                        Link(LocalizedStringKey("Terms of Use"), destination: Constants.Legal.eulaURL)
                        Link(LocalizedStringKey("Privacy Policy"), destination: Constants.Legal.privacyPolicyURL)
                    }
                    .font(.footnote)

                    Toggle(isOn: $agreed) {
                        Text(LocalizedStringKey("I agree to the Terms of Use and Community Guidelines, and I understand that objectionable content is not tolerated."))
                            .font(.subheadline)
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle(LocalizedStringKey("Before You Share"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("Agree & Continue")) {
                        hasAccepted = true
                        dismiss()
                        onAccept()
                    }
                    .disabled(!agreed)
                }
            }
            .interactiveDismissDisabled(true) // must make an explicit choice
        }
    }
}

/// Drop-in modifier to gate any share action behind EULA acceptance.
struct RequireUGCConsentModifier: ViewModifier {
    @AppStorage(UGCConsent.storageKey) private var hasAccepted = false
    @Binding var isPresentingGate: Bool
    let onConsented: () -> Void

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresentingGate) {
                CommunityGuidelinesSheet(onAccept: onConsented)
            }
    }
}
