import SwiftUI

/// Un portal = una pestaña fija de la app.
struct Portal: Identifiable, Hashable {
    let id: String
    let nombre: String        // etiqueta corta en la barra
    let nombreLargo: String   // título completo
    let url: URL
    let sistema: String       // SF Symbol para el icono
    let color: Color

    static let todos: [Portal] = [
        Portal(
            id: "ecpc",
            nombre: "ECPC",
            nombreLargo: "Drive ECPC (CRM)",
            url: URL(string: "https://drive.ecpc.com.mx/")!,
            sistema: "chart.bar.doc.horizontal",
            color: .blue
        ),
        Portal(
            id: "ctonline",
            nombre: "CT",
            nombreLargo: "CT Online",
            url: URL(string: "https://ctonline.mx/")!,
            sistema: "shippingbox",
            color: .orange
        ),
        Portal(
            id: "cva",
            nombre: "CVA",
            nombreLargo: "Grupo CVA",
            url: URL(string: "https://me2.grupocva.com/me/inicio.php")!,
            sistema: "building.2",
            color: .green
        )
    ]
}
