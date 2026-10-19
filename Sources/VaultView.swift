import SwiftUI
import WebKit

struct VaultView: View {
    @EnvironmentObject var vault: CredentialVault
    @EnvironmentObject var browser: BrowserModel
    @Environment(\.dismiss) private var dismiss

    @State private var editando: Credencial?
    @State private var mostrarNueva = false
    @State private var mensaje: String?

    var body: some View {
        NavigationView {
            Group {
                if vault.desbloqueada {
                    lista
                } else {
                    bloqueo
                }
            }
            .navigationTitle("Contraseñas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if vault.desbloqueada {
                        Button { mostrarNueva = true } label: { Image(systemName: "plus") }
                    }
                }
            }
            .sheet(isPresented: $mostrarNueva) {
                EditorCredencial(credencial: nil, portalSugerido: browser.seleccion)
                    .environmentObject(vault)
            }
            .sheet(item: $editando) { cred in
                EditorCredencial(credencial: cred, portalSugerido: cred.portalID)
                    .environmentObject(vault)
            }
            .overlay(alignment: .bottom) {
                if let mensaje {
                    Text(mensaje)
                        .font(.footnote).padding(10)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(.opacity)
                }
            }
        }
        .onAppear {
            if !vault.desbloqueada { vault.desbloquear { _ in } }
        }
    }

    private var bloqueo: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield").font(.system(size: 54)).foregroundColor(.secondary)
            Text("Bóveda bloqueada").font(.headline)
            Button {
                vault.desbloquear { _ in }
            } label: {
                Label("Desbloquear con Face ID / código", systemImage: "faceid")
                    .padding(.horizontal, 20).padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.blue.opacity(0.15)))
            }
        }.padding()
    }

    private var lista: some View {
        List {
            ForEach(Portal.todos) { portal in
                let creds = vault.paraPortal(portal.id)
                Section(portal.nombreLargo) {
                    if creds.isEmpty {
                        Text("Sin credenciales guardadas").foregroundColor(.secondary).font(.footnote)
                    }
                    ForEach(creds) { cred in fila(cred, portal: portal) }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func fila(_ cred: Credencial, portal: Portal) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(cred.usuario).font(.system(size: 16, weight: .semibold))
            if !cred.nota.isEmpty {
                Text(cred.nota).font(.footnote).foregroundColor(.secondary)
            }
            HStack(spacing: 10) {
                boton("Usuario", "person") {
                    UIPasteboard.general.string = cred.usuario; avisar("Usuario copiado")
                }
                boton("Clave", "key") {
                    UIPasteboard.general.string = cred.password; avisar("Contraseña copiada")
                }
                if browser.seleccion == portal.id {
                    boton("Rellenar", "arrow.down.doc", resaltado: true) {
                        autofill(cred); avisar("Rellenado en la página")
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .swipeActions {
            Button(role: .destructive) { vault.eliminar(cred) } label: { Label("Eliminar", systemImage: "trash") }
            Button { editando = cred } label: { Label("Editar", systemImage: "pencil") }.tint(.blue)
        }
    }

    private func boton(_ titulo: String, _ icono: String, resaltado: Bool = false, _ accion: @escaping () -> Void) -> some View {
        Button(action: accion) {
            Label(titulo, systemImage: icono)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 8)
                    .fill(resaltado ? Color.blue.opacity(0.18) : Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
    }

    private func avisar(_ t: String) {
        withAnimation { mensaje = t }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { if mensaje == t { mensaje = nil } }
        }
    }

    /// Rellena, lo mejor posible, el usuario y la contraseña del formulario visible.
    /// Solo escribe en los campos; NO envía el formulario (lo haces tú).
    private func autofill(_ cred: Credencial) {
        guard let wv = browser.tabActual?.webView else { return }
        let u = cred.usuario.replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "'", with: "\\'")
        let p = cred.password.replacingOccurrences(of: "\\", with: "\\\\")
                             .replacingOccurrences(of: "'", with: "\\'")
        let js = """
        (function(){
          function set(el,val){
            if(!el) return false;
            var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');
            d && d.set ? d.set.call(el,val) : (el.value=val);
            el.dispatchEvent(new Event('input',{bubbles:true}));
            el.dispatchEvent(new Event('change',{bubbles:true}));
            return true;
          }
          var pass=document.querySelector("input[type='password']");
          var user=null;
          if(pass){
            var form=pass.form||document;
            var cands=form.querySelectorAll("input[type='text'],input[type='email'],input[name*='user' i],input[name*='mail' i],input[id*='user' i],input[id*='mail' i]");
            user=cands.length?cands[0]:null;
          }
          var okU=set(user,'\(u)');
          var okP=set(pass,'\(p)');
          return okU||okP;
        })();
        """
        wv.evaluateJavaScript(js, completionHandler: nil)
    }
}

// MARK: - Editor

struct EditorCredencial: View {
    @EnvironmentObject var vault: CredentialVault
    @Environment(\.dismiss) private var dismiss

    @State private var portalID: String
    @State private var usuario: String
    @State private var password: String
    @State private var nota: String
    @State private var verClave = false
    private let idExistente: UUID?

    init(credencial: Credencial?, portalSugerido: String) {
        _portalID = State(initialValue: credencial?.portalID ?? portalSugerido)
        _usuario  = State(initialValue: credencial?.usuario ?? "")
        _password = State(initialValue: credencial?.password ?? "")
        _nota     = State(initialValue: credencial?.nota ?? "")
        idExistente = credencial?.id
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Portal") {
                    Picker("Portal", selection: $portalID) {
                        ForEach(Portal.todos) { Text($0.nombreLargo).tag($0.id) }
                    }
                }
                Section("Credenciales") {
                    TextField("Usuario o correo", text: $usuario)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        if verClave { TextField("Contraseña", text: $password) }
                        else { SecureField("Contraseña", text: $password) }
                        Button { verClave.toggle() } label: {
                            Image(systemName: verClave ? "eye.slash" : "eye")
                        }
                    }
                    TextField("Nota (opcional)", text: $nota)
                }
            }
            .navigationTitle(idExistente == nil ? "Nueva" : "Editar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        var c = Credencial(portalID: portalID, usuario: usuario,
                                           password: password, nota: nota)
                        if let idExistente { c.id = idExistente }
                        vault.guardar(c)
                        dismiss()
                    }
                    .disabled(usuario.isEmpty && password.isEmpty)
                }
            }
        }
    }
}
