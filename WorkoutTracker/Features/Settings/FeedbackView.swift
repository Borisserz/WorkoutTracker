//
//  FeedbackView.swift
//  WorkoutTracker
//
//  Created by Boris Serzhanovich on 27.12.25.
//

internal import SwiftUI
import MessageUI

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @State private var feedbackType: FeedbackType = .general
    @State private var subject: String = ""
    @State private var message: String = ""
    @State private var showMailComposer = false
    @State private var showMailError = false
    @State private var mailErrorMessage = ""
    
    enum FeedbackType: String, CaseIterable {
        case general = "General Feedback"
        case bug = "Bug Report"
        case feature = "Feature Request"
        case other = "Other"
        
        var localizedKey: String {
            switch self {
            case .general: return "General Feedback"
            case .bug: return "Bug Report"
            case .feature: return "Feature Request"
            case .other: return "Other"
            }
        }
    }
    
        @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Form {
            Section(header: Text(LocalizedStringKey("Feedback Type"))) {
                Picker(LocalizedStringKey("Type"), selection: $feedbackType) {
                    ForEach(FeedbackType.allCases, id: \.self) { type in
                        Text(LocalizedStringKey(type.localizedKey)).tag(type)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section(header: Text(LocalizedStringKey("Subject"))) {
                TextField(LocalizedStringKey("Enter subject"), text: $subject)
                    .textInputAutocapitalization(.sentences)
            }
            
            Section(header: Text(LocalizedStringKey("Message")), footer: Text(LocalizedStringKey("Please describe your feedback, bug report, or feature request in detail."))) {
                TextEditor(text: $message)
                    .frame(minHeight: 200)
                    .textInputAutocapitalization(.sentences)
            }
            
            Section {
                Button {
                    sendFeedback()
                } label: {
                    HStack {
                        Spacer()
                        Label(LocalizedStringKey("Send Feedback"), systemImage: "paperplane.fill")
                        Spacer()
                    }
                }
                .disabled(subject.isEmpty || message.isEmpty)
            }
            
            Section(header: Text(LocalizedStringKey("Alternative Contact"))) {
                Button {
                    if let url = URL(string: "mailto:support@workouttracker.app?subject=Feedback") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Label(LocalizedStringKey("Email Support"), systemImage: "envelope.fill")
                            .foregroundColor(themeManager.current.primaryText)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                            .foregroundColor(themeManager.current.secondaryText)
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("Feedback"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showMailComposer) {
            MailComposeView(
                subject: getEmailSubject(),
                messageBody: getEmailBody(),
                isPresented: $showMailComposer,
                result: { result in
                    handleMailResult(result)
                }
            )
        }
        .alert(LocalizedStringKey("Error"), isPresented: $showMailError) {
            Button(LocalizedStringKey("OK"), role: .cancel) { }
        } message: {
            Text(mailErrorMessage)
        }
    }
    
    private func sendFeedback() {
        guard !subject.isEmpty && !message.isEmpty else { return }
        
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            // Если Mail не настроен, предлагаем альтернативу
            mailErrorMessage = NSLocalizedString("Mail is not configured on this device. Please use the email support option below or configure Mail in Settings.", comment: "Mail not configured error")
            showMailError = true
        }
    }
    
    private func getEmailSubject() -> String {
        let typePrefix: String
        switch feedbackType {
        case .bug:
            typePrefix = "[Bug Report]"
        case .feature:
            typePrefix = "[Feature Request]"
        case .general:
            typePrefix = "[Feedback]"
        case .other:
            typePrefix = "[Other]"
        }
        return "\(typePrefix) \(subject)"
    }
    
    private func getEmailBody() -> String {
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        let deviceModel = UIDevice.current.model
        let systemVersion = UIDevice.current.systemVersion
        
        return """
        \(message)
        
        ---
        Device Information:
        App Version: \(appVersion) (\(buildNumber))
        Device: \(deviceModel)
        iOS Version: \(systemVersion)
        """
    }
    
    private func handleMailResult(_ result: Result<MFMailComposeResult, Error>) {
        switch result {
        case .success(let mailResult):
            switch mailResult {
            case .sent:
                dismiss()
            case .cancelled:
                break
            case .failed:
                mailErrorMessage = NSLocalizedString("Failed to send email. Please try again.", comment: "Email send failed")
                showMailError = true
            case .saved:
                dismiss()
            @unknown default:
                break
            }
        case .failure(let error):
            mailErrorMessage = error.localizedDescription
            showMailError = true
        }
    }
}

// MARK: - Mail Compose View

struct MailComposeView: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    @Binding var isPresented: Bool
    let result: (Result<MFMailComposeResult, Error>) -> Void
    
    // Возвращаем строго MFMailComposeViewController, так как защита стоит на уровне FeedbackView
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)
        composer.setToRecipients(["support@workouttracker.app"])
        
        // Фикс для темной темы в UIKit внутри SwiftUI
        composer.overrideUserInterfaceStyle = .unspecified
        
        return composer
    }
        
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: MailComposeView
        
        init(_ parent: MailComposeView) { self.parent = parent }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error { parent.result(.failure(error)) }
            else { parent.result(.success(result)) }
            parent.isPresented = false
        }
    }
}
