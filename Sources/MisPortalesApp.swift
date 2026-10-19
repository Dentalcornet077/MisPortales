import SwiftUI

@main
struct MisPortalesApp: App {
    @StateObject private var browser = BrowserModel()
    @StateObject private var vault = CredentialVault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(browser)
                .environmentObject(vault)
                .preferredColorScheme(nil)   // respeta claro/oscuro del sistema
        }
    }
}
