internal import SwiftUI
import WebKit

struct GifImageView: UIViewRepresentable {
    let urlString: String
    @Binding var hasError: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        webView.configuration.userContentController.add(context.coordinator, name: "error")
        context.coordinator.didRegisterErrorHandler = true
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.parent = self

        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async { hasError = true }
            return
        }

        // Avoid WKWebView HTML reload + handler churn on every SwiftUI pass.
        if context.coordinator.lastLoadedURLString == url.absoluteString {
            return
        }
        context.coordinator.lastLoadedURLString = url.absoluteString

        let html = """
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <style>
                body {
                    margin: 0;
                    padding: 0;
                    background-color: transparent;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                }
                img {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                }
            </style>
        </head>
        <body>
            <img src="\(url.absoluteString)" onerror="window.webkit.messageHandlers.error.postMessage('error')" />
        </body>
        </html>
        """

        uiView.loadHTMLString(html, baseURL: nil)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        if coordinator.didRegisterErrorHandler {
            uiView.configuration.userContentController.removeScriptMessageHandler(forName: "error")
            coordinator.didRegisterErrorHandler = false
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: GifImageView
        var lastLoadedURLString: String?
        var didRegisterErrorHandler = false

        init(_ parent: GifImageView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.hasError = true }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.hasError = true }
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "error" {
                DispatchQueue.main.async { self.parent.hasError = true }
            }
        }
    }
}
