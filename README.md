# Mis Portales

App iOS/iPadOS tipo navegador con 3 pestañas fijas para mis sistemas:

- **ECPC** — Drive ECPC (CRM) · https://drive.ecpc.com.mx/
- **CT** — CT Online · https://ctonline.mx/
- **CVA** — Grupo CVA · https://me2.grupocva.com/me/inicio.php

## Qué hace

- 3 pestañas que **no se recargan** al cambiar entre ellas (cada una mantiene su sesión).
- Cookies, caché y sesión **persistentes** (compartidas entre pestañas y guardadas al cerrar).
- User-agent de Safari real → los portales la ven como un navegador normal.
- Navegación: atrás/adelante, recargar, ir al inicio, barra de progreso, candado HTTPS.
- Gestos de deslizar para atrás/adelante y "tirar para recargar".
- Soporta ventanas emergentes (`window.open`), descargas y enlaces externos (tel/mailto).
- **Bóveda de contraseñas** cifrada en el Keychain, protegida con Face ID / Touch ID,
  con botón para **rellenar** el formulario de la página actual.
- Botón para **cerrar sesión en todo** (borra cookies/caché).

## Compilar sin Mac (GitHub Actions)

1. Sube este proyecto a un repositorio GitHub.
2. En **Actions** se ejecuta `Build IPA` (o lánzalo a mano con *Run workflow*).
3. Al terminar, descarga el artefacto **MisPortales-ipa** (contiene `MisPortales.ipa`).
4. Pásalo al iPad e instálalo con **TrollStore** (el .ipa va **sin firma**, a propósito).

## Compilar en Mac (opcional)

```bash
brew install xcodegen
cd MisPortales
xcodegen generate
open MisPortales.xcodeproj
```

## Estructura

| Archivo | Qué hace |
|---|---|
| `Portal.swift` | Definición de los 3 portales |
| `WebTab.swift` | Un WKWebView vivo por portal (delegados, descargas, popups) |
| `BrowserModel.swift` | Dueño de las pestañas + data store persistente |
| `WebViewContainer.swift` | Muestra un WKWebView existente en SwiftUI |
| `CredentialVault.swift` | Bóveda en Keychain + biometría |
| `ContentView.swift` | Interfaz principal (selector, barra, área web) |
| `VaultView.swift` | Pantalla de contraseñas + autorrelleno |
| `PopupView.swift` | Hoja para ventanas emergentes |
| `project.yml` | Proyecto para XcodeGen |
| `.github/workflows/build.yml` | Compila el .ipa sin firma |
