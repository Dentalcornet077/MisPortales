import SwiftUI
import WebKit

/// Envuelve un WKWebView YA EXISTENTE (no lo recrea), para que al cambiar de
/// pestaña la página siga cargada en su mismo estado.
struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView

    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
