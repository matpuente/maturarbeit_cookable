import SwiftData
import SwiftUI

@main
struct CookableApp: App {
    @State private var datenbank = Result { try RezeptDatenbank() }
    private let speicher: ModelContainer
    @State private var uebersetzer: Uebersetzer

    init() {
        // Fotos von Food.com zwischenspeichern: bis 100 MB auf dem Gerät, älteste werden automatisch gelöscht
        URLCache.shared = URLCache(memoryCapacity: 30_000_000, diskCapacity: 100_000_000)

        // Nutzerdaten (SwiftData): Vorrat und gespeicherte Übersetzungen
        do {
            speicher = try ModelContainer(for: VorratsEintrag.self, Uebersetzung.self)
        } catch {
            fatalError("Der Speicher für die Nutzerdaten konnte nicht geöffnet werden: \(error)")
        }
        _uebersetzer = State(initialValue: Uebersetzer(kontext: speicher.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            switch datenbank {
            case .success(let datenbank):
                HauptAnsicht()
                    .environment(datenbank)
                    .environment(uebersetzer)
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
        .modelContainer(speicher)
    }
}
