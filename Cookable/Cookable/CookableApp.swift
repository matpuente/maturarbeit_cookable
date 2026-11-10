import SwiftData
import SwiftUI

@main
struct CookableApp: App {
    @State private var datenbank = Result { try RezeptDatenbank() }

    var body: some Scene {
        WindowGroup {
            switch datenbank {
            case .success(let datenbank):
                HauptAnsicht()
                    .environment(datenbank)
                    // Die Oberfläche ist komplett Deutsch (Datum, Zahlen) – unabhängig von der Geräteeinstellung
                    .environment(\.locale, Locale(identifier: "de_CH"))
            case .failure(let fehler):
                ContentUnavailableView(
                    "Rezepte nicht verfügbar",
                    systemImage: "exclamationmark.triangle",
                    description: Text(fehler.localizedDescription)
                )
            }
        }
        .modelContainer(for: VorratsEintrag.self)
    }
}
