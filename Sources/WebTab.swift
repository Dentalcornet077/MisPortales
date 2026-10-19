import SwiftUI
import WebKit

/// Mantiene vivo un WKWebView por cada portal, con su propia barra de estado
/// (progreso, URL actual, si puede ir atrás/adelante). Los WebView se crean
/// una sola vez y se comparten, así cambiar de pestaña NO recarga la página.
final class WebTab: NSObject, ObservableObject, Identifiable, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate {
    var id: String { portal.id }
    let portal: Portal
    let webView: WKWebView

    /// Se llama cuando la página pide abrir una ventana nueva (window.open / target=_blank).
    var onPopup: ((URLRequest) -> Void)?

    @Published var progreso: Double = 0
    @Published var cargando: Bool = false
    @Published var puedeAtras: Bool = false
    @Published var puedeAdelante: Bool = false
    @Published var titulo: String = ""
    @Published var urlActual: String = ""
    @Published var seguro: Bool = true
    @Published var yaCargoUnaVez: Bool = false

    private var observadores: [NSKeyValueObservation] = []

    // User-agent de Safari en Mac: los portales sirven la versión de ESCRITORIO,
    // no la móvil. Se combina con preferredContentMode = .desktop (abajo).
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Safari/605.1.15"

    init(portal: Portal, dataStore: WKWebsiteDataStore) {
        self.portal = portal

        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore            // cookies + caché PERSISTENTES y compartidas
        config.allowsInlineMediaPlayback = true
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let prefs = WKPreferences()
        prefs.javaScriptCanOpenWindowsAutomatically = true
        config.preferences = prefs

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()

        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true
        webView.navigationDelegate = self
        webView.uiDelegate = self

        // Barra de "pull to refresh"
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(recargarTirando(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = rc

        observar()
    }

    private func observar() {
        observadores = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                self?.progreso = wv.estimatedProgress
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] wv, _ in
                self?.cargando = wv.isLoading
                if !wv.isLoading { wv.scrollView.refreshControl?.endRefreshing() }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] wv, _ in
                self?.puedeAtras = wv.canGoBack
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] wv, _ in
                self?.puedeAdelante = wv.canGoForward
            },
            webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                self?.titulo = wv.title ?? ""
            },
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                self?.urlActual = wv.url?.absoluteString ?? ""
                self?.seguro = (wv.url?.scheme == "https")
            }
        ]
    }

    /// Carga la página de inicio la primera vez que se muestra la pestaña.
    func cargarSiHaceFalta() {
        guard !yaCargoUnaVez else { return }
        yaCargoUnaVez = true
        webView.load(URLRequest(url: portal.url))
    }

    func recargar() {
        if webView.url == nil { webView.load(URLRequest(url: portal.url)) }
        else { webView.reload() }
    }

    func irAInicio() { webView.load(URLRequest(url: portal.url)) }
    func atras()     { webView.goBack() }
    func adelante()  { webView.goForward() }

    @objc private func recargarTirando(_ sender: UIRefreshControl) {
        webView.reload()
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 preferences: WKWebpagePreferences,
                 decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void) {
        // Modo escritorio: viewport y comportamiento de web de escritorio,
        // con la resolución real del iPad (no una ventana diminuta).
        preferences.preferredContentMode = .desktop

        if let url = navigationAction.request.url {
            // Esquemas que debe abrir el sistema (teléfono, correo, apps externas)
            let externos = ["tel", "mailto", "facetime", "sms", "itms-apps", "maps"]
            if let scheme = url.scheme?.lowercased(), externos.contains(scheme) {
                UIApplication.shared.open(url)
                decisionHandler(.cancel, preferences); return
            }
        }
        decisionHandler(.allow, preferences)
    }

    // Descargas (iOS 15+)
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        if navigationResponse.canShowMIMEType {
            decisionHandler(.allow)
        } else {
            decisionHandler(.download)
        }
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView,
                 navigationAction: WKNavigationAction,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    // Aceptar certificados HTTPS estándar (cadena válida del sistema).
    func webView(_ webView: WKWebView,
                 didReceive challenge: URLAuthenticationChallenge,
                 completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.performDefaultHandling, nil)
    }

    // MARK: - WKUIDelegate (popups window.open / target=_blank)

    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url, navigationAction.targetFrame == nil {
            // Abrir el popup en una hoja dentro de la app
            onPopup?(URLRequest(url: url))
        }
        return nil
    }

    // MARK: - WKDownloadDelegate

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let carpeta = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Descargas", isDirectory: true)
        try? FileManager.default.createDirectory(at: carpeta, withIntermediateDirectories: true)
        var destino = carpeta.appendingPathComponent(suggestedFilename)
        if FileManager.default.fileExists(atPath: destino.path) {
            let base = destino.deletingPathExtension().lastPathComponent
            let ext = destino.pathExtension
            let stamp = Int(Date().timeIntervalSince1970)
            destino = carpeta.appendingPathComponent("\(base)-\(stamp).\(ext)")
        }
        completionHandler(destino)
    }

    func downloadDidFinish(_ download: WKDownload) {}
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {}
}
