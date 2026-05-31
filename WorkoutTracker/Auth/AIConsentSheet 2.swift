//
//  AIConsentSheet 2.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 31.05.2026.
//


internal import SwiftUI

struct AIConsentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    @AppStorage(Constants.UserDefaultsKeys.hasConsentedToAI.rawValue)
    private var hasConsentedToAI = false


    var onConsent: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(LinearGradient(colors: [.purple, .cyan],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    Text(LocalizedStringKey("AI Coach & Data Processing"))
                        .font(.title2).bold()

                    Text(LocalizedStringKey("To answer your questions and build plans, the AI Coach sends the text you type (your messages and requests) to our secure cloud processing service. Your messages are linked to your account to enforce usage limits. Your body weight and Health data are never sent."))
                        .font(.body)
                        .foregroundColor(themeManager.current.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: Constants.Legal.privacyPolicyURL) {
                        HStack {
                            Image(systemName: "hand.raised.fill")
                            Text(LocalizedStringKey("Read our Privacy Policy"))
                        }
                    }
                    .font(.callout.weight(.semibold))
                    .tint(themeManager.current.primaryAccent)
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        hasConsentedToAI = true
                        onConsent?()
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("Agree & Continue"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(themeManager.current.primaryAccent)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text(LocalizedStringKey("Not Now"))
                            .font(.subheadline)
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(.regularMaterial)
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)   
        }
    }
}
