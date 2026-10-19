import SwiftUI
import WebKit

/// Dueño de las pestañas. Crea un data store PERSISTENTE compartido por los 3
/// portales, de modo que cookies, caché y sesiones sobreviven al cierre de la app.
/// Ventana emergente pendiente de mostrar (hoja).
struct PopupItem: Identifiable {
    let id = UUID()
    let request: URLRequest
    let userAgent: String?
    let dataStore: WKWebsiteDataStore
}

final class BrowserModel: ObservableObject {
    @Published var tabs: [WebTab]
    @Published var seleccion: String
    @Published var popup: PopupItem?

    init() {
        let store = WKWebsiteDataStore.default()   // persistente en disco
        let creadas = Portal.todos.map { WebTab(portal: $0, dataStore: store) }
        self.tabs = creadas
        self.seleccion = creadas.first?.portal.id ?? ""

        for tab in creadas {
            let ua = tab.webView.customUserAgent
            tab.onPopup = { [weak self] req in
                self?.popup = PopupItem(request: req, userAgent: ua, dataStore: store)
            }
        }
    }

    var tabActual: WebTab? {
        tabs.first { $0.portal.id == seleccion }
    }

    /// Borra cookies/caché de todos los sitios (cerrar sesión en todo).
    func borrarDatosWeb(_ completion: @escaping () -> Void) {
        let tipos = WKWebsiteDataStore.allWebsiteDataTypes()
        WKWebsiteDataStore.default().removeData(
            ofTypes: tipos,
            modifiedSince: Date(timeIntervalSince1970: 0)
        ) {
            DispatchQueue.main.async { completion() }
        }
    }
}
