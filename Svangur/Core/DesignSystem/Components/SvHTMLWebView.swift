import SwiftUI
import WebKit

struct SvHTMLWebView: UIViewRepresentable {
    let html: String
    let baseURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.scrollView.showsVerticalScrollIndicator = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(html, baseURL: baseURL)
    }
}
