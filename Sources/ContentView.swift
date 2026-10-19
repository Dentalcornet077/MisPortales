import SwiftUI
import WebKit

struct ContentView: View {
    @EnvironmentObject var browser: BrowserModel
    @EnvironmentObject var vault: CredentialVault

    @State private var mostrarVault = false

    var body: some View {
        VStack(spacing: 0) {
            selectorPortales
            barraNavegacion
            progreso
            Divider()
            areaWeb
        }
        .background(Color(.systemGroupedBackground))
        .onAppear { browser.tabActual?.cargarSiHaceFalta() }
        .onChange(of: browser.seleccion) { _ in
            browser.tabActual?.cargarSiHaceFalta()
        }
        .sheet(isPresented: $mostrarVault) {
            VaultView()
                .environmentObject(vault)
                .environmentObject(browser)
        }
        .sheet(item: $browser.popup) { item in
            PopupView(request: item.request,
                      userAgent: item.userAgent,
                      dataStore: item.dataStore)
        }
    }

    // MARK: - Selector de portales (pestañas superiores)

    private var selectorPortales: some View {
        HStack(spacing: 8) {
            ForEach(browser.tabs) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        browser.seleccion = tab.portal.id
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.portal.sistema)
                            .font(.system(size: 14, weight: .semibold))
                        Text(tab.portal.nombre)
                            .font(.system(size: 14, weight: .semibold))
                        if tab.cargando {
                            ProgressView().scaleEffect(0.6)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(browser.seleccion == tab.portal.id
                                  ? tab.portal.color.opacity(0.18)
                                  : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(browser.seleccion == tab.portal.id
                                    ? tab.portal.color : .clear, lineWidth: 1.5)
                    )
                    .foregroundColor(browser.seleccion == tab.portal.id
                                     ? tab.portal.color : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    // MARK: - Barra de navegación

    private var barraNavegacion: some View {
        let tab = browser.tabActual
        return HStack(spacing: 14) {
            Button { tab?.atras() } label: { Image(systemName: "chevron.left") }
                .disabled(tab?.puedeAtras != true)
            Button { tab?.adelante() } label: { Image(systemName: "chevron.right") }
                .disabled(tab?.puedeAdelante != true)
            Button { tab?.recargar() } label: {
                Image(systemName: tab?.cargando == true ? "xmark" : "arrow.clockwise")
            }
            Button { tab?.irAInicio() } label: { Image(systemName: "house") }

            HStack(spacing: 5) {
                Image(systemName: tab?.seguro == true ? "lock.fill" : "lock.open")
                    .font(.system(size: 11))
                    .foregroundColor(tab?.seguro == true ? .green : .orange)
                Text(dominio(tab?.urlActual ?? ""))
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))

            Button { mostrarVault = true } label: { Image(systemName: "key.fill") }

            Menu {
                Button { tab?.irAInicio() } label: { Label("Ir al inicio del portal", systemImage: "house") }
                Button {
                    if let u = tab?.urlActual, let url = URL(string: u) {
                        UIPasteboard.general.string = url.absoluteString
                    }
                } label: { Label("Copiar enlace", systemImage: "doc.on.doc") }
                Divider()
                Button(role: .destructive) {
                    browser.borrarDatosWeb {
                        for t in browser.tabs { t.irAInicio() }
                    }
                } label: { Label("Cerrar sesión en todo (borrar cookies)", systemImage: "trash") }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .font(.system(size: 17, weight: .medium))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var progreso: some View {
        GeometryReader { geo in
            let p = browser.tabActual?.progreso ?? 0
            let visible = (browser.tabActual?.cargando ?? false) && p < 1
            Rectangle()
                .fill(browser.tabActual?.portal.color ?? .blue)
                .frame(width: geo.size.width * CGFloat(p))
                .opacity(visible ? 1 : 0)
                .animation(.linear(duration: 0.2), value: p)
        }
        .frame(height: 2)
    }

    // MARK: - Área web (todas las pestañas vivas, solo se ve la activa)

    private var areaWeb: some View {
        ZStack {
            ForEach(browser.tabs) { tab in
                WebViewContainer(webView: tab.webView)
                    .opacity(browser.seleccion == tab.portal.id ? 1 : 0)
                    .allowsHitTesting(browser.seleccion == tab.portal.id)
            }
        }
        .ignoresSafeArea(.container, edges: .bottom)
    }

    private func dominio(_ s: String) -> String {
        guard let u = URL(string: s), let h = u.host else { return s }
        return h.replacingOccurrences(of: "www.", with: "")
    }
}
