internal import SwiftUI

struct SisterAppsPromoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AtmosphericGymBackdropView(style: .overview)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        HapticManager.shared.impact(.light)
                        dismiss()
                    } label: {
                        ChromeDismissMark()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("More from us")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textPrimary)

                    Text("Apps from the same team — take a look.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(PastelTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(SisterAppsCatalog.all) { app in
                            SisterAppTile(app: app)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }

                Button {
                    HapticManager.shared.impact(.medium)
                    dismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(PastelTheme.textOnOat)
                        .frame(maxWidth: .infinity)
                        .frame(height: PastelTheme.ButtonMetrics.heroHeight)
                        .background(PastelTheme.pastelOat)
                        .clipShape(RoundedRectangle(cornerRadius: PastelTheme.ButtonMetrics.heroRadius, style: .continuous))
                }
                .buttonStyle(BouncyButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .preferredColorScheme(.dark)
        .accessibilityIdentifier("wt.sister.promo")
    }
}
