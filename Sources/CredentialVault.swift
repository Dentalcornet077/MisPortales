import Foundation
import Security
import LocalAuthentication

/// Credencial guardada por el usuario (sus propias cuentas).
struct Credencial: Identifiable, Codable, Hashable {
    var id = UUID()
    var portalID: String
    var usuario: String
    var password: String
    var nota: String = ""
}

/// Bóveda de contraseñas cifrada en el Keychain del dispositivo.
/// El Keychain solo entrega los datos cuando el dispositivo está desbloqueado,
/// y además pedimos Face ID / Touch ID antes de revelar las contraseñas.
final class CredentialVault: ObservableObject {
    @Published private(set) var credenciales: [Credencial] = []
    @Published var desbloqueada: Bool = false

    private let servicio = "com.misportales.vault"
    private let cuentaBlob = "credenciales_v1"

    init() { cargarSilencioso() }

    // MARK: - Biometría

    var biometriaDisponible: Bool {
        var error: NSError?
        return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }

    func desbloquear(_ completion: @escaping (Bool) -> Void) {
        let ctx = LAContext()
        ctx.localizedReason = "Desbloquear tus contraseñas"
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Sin biometría ni código: igual mostramos (el Keychain ya protege en reposo)
            DispatchQueue.main.async { self.desbloqueada = true; completion(true) }
            return
        }
        ctx.evaluatePolicy(.deviceOwnerAuthentication,
                           localizedReason: "Desbloquear tus contraseñas") { ok, _ in
            DispatchQueue.main.async {
                self.desbloqueada = ok
                completion(ok)
            }
        }
    }

    func bloquear() { desbloqueada = false }

    // MARK: - CRUD

    func guardar(_ cred: Credencial) {
        if let i = credenciales.firstIndex(where: { $0.id == cred.id }) {
            credenciales[i] = cred
        } else {
            credenciales.append(cred)
        }
        persistir()
    }

    func eliminar(_ cred: Credencial) {
        credenciales.removeAll { $0.id == cred.id }
        persistir()
    }

    func paraPortal(_ portalID: String) -> [Credencial] {
        credenciales.filter { $0.portalID == portalID }
    }

    // MARK: - Keychain (todo el blob cifrado como un solo item)

    private func persistir() {
        guard let data = try? JSONEncoder().encode(credenciales) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuentaBlob
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }

    private func cargarSilencioso() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: servicio,
            kSecAttrAccount as String: cuentaBlob,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        if SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
           let data = item as? Data,
           let lista = try? JSONDecoder().decode([Credencial].self, from: data) {
            credenciales = lista
        }
    }
}
