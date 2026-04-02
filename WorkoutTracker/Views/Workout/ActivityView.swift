internal import SwiftUI
import UIKit

// Структура-обертка для URL, чтобы соответствовать Identifiable (оставляем как есть)
struct SharedFileWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityViewController: UIViewControllerRepresentable {
    // 👇 ИСПРАВЛЕНИЕ: Меняем [URL] обратно на [Any], чтобы делиться и картинками
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
