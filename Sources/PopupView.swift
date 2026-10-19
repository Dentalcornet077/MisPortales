import SwiftUI
import WebKit

/// Hoja para abrir enlaces que piden ventana nueva (window.open / target=_blank),
/// típicos de descargas de facturas o vistas de detalle en los mayoristas.
struct PopupView: View {
    let request: URLRequest?
    let userAgent: String?
    let dataStore: WKWebsiteDataStore

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            PopupWeb(request: request, userAgent: userAgent, dataStore: dataStore)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Ventana emergente")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cerrar") { dismiss() }
                    }
                }
        }
    }
}

private struct PopupWeb: UIViewRepresentable {
    let request: URLRequest?
    let userAgent: String?
    let dataStore: WKWebsiteDataStore

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore   // misma sesión que la pestaña
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = userAgent
        wv.allowsBackForwardNavigationGestures = true
        if let request { wv.load(request) }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
