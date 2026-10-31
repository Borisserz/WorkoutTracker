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
                        .foregroundStyle(PastelTheme.pastelLavender)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                    Text("ИИ-тренер и обработка данных")
                        .font(.title2.bold())
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Чтобы отвечать на вопросы и составлять планы тренировок, ИИ-тренер отправляет ваши сообщения в защищённый облачный сервис. Сообщения привязаны к аккаунту для учёта лимитов. Данные веса и Apple Health никогда не передаются третьим лицам.")
                        .font(.body)
                        .foregroundColor(PastelTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: Constants.Legal.privacyPolicyURL) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                            Text("Политика конфиденциальности")
                        }
                    }
                    .font(.callout.weight(.semibold))
                    .tint(PastelTheme.pastelSlate)
                }
                .padding(24)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Button {
                        HapticManager.shared.impact(.light)
                        hasConsentedToAI = true
                        onConsent?()
                        dismiss()
                    } label: {
                        Text("Принять и продолжить")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                            .background(PastelTheme.pastelOat)
                            .foregroundColor(PastelTheme.textOnOat)
                            .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Не сейчас")
                            .font(.subheadline)
                            .foregroundColor(PastelTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .background(PastelTheme.canvas.opacity(0.95))
            }
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(true)   
        }
    }
}
