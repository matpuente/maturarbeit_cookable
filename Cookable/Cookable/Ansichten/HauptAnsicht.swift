import SwiftData
import SwiftUI

/// Tab-Navigation der App.
struct HauptAnsicht: View {
    enum Bereich: Hashable {
        case start, vorrat, rezepte, favoriten, einkauf
    }

    @Environment(\.modelContext) private var kontext
    @Environment(RezeptDatenbank.self) private var datenbank
    @State private var bereich = Bereich.start
    @Query(filter: #Predicate<EinkaufsEintrag> { !$0.erledigt }) private var offeneEinkaeufe: [EinkaufsEintrag]
    @Query private var vorrat: [VorratsEintrag]
    @Environment(MitteilungsEmpfaenger.self) private var mitteilungen
    @Environment(\.scenePhase) private var phase
    @AppStorage(AblaufMitteilungen.schluesselAn) private var mitteilungenAn = true
    @AppStorage(AblaufMitteilungen.schluesselTage) private var mitteilungenTage = AblaufMitteilungen.standardTage
    @AppStorage(AblaufMitteilungen.schluesselMinuten) private var mitteilungenMinuten = AblaufMitteilungen.standardMinuten

    /// Ändert sich, sobald sich Ablaufdaten oder Einstellungen ändern – dann werden die Mitteilungen neu geplant
    private var mitteilungsStand: String {
        let daten = vorrat.compactMap { eintrag in
            eintrag.ablaufdatum.map { "\(eintrag.name)|\($0.timeIntervalSince1970)" }
        }.sorted()
        return "\(mitteilungenAn)-\(mitteilungenTage)-\(mitteilungenMinuten)-\(daten.joined(separator: ";"))"
    }

    var body: some View {
        TabView(selection: $bereich) {
            Tab("Start", systemImage: "house", value: .start) {
                StartAnsicht(zeigeRezepte: { bereich = .rezepte }, zeigeVorrat: { bereich = .vorrat })
            }
            Tab("Vorrat", systemImage: "refrigerator", value: .vorrat) {
                VorratAnsicht()
            }
            Tab("Rezepte", systemImage: "fork.knife", value: .rezepte) {
                RezepteAnsicht()
            }
            Tab("Favoriten", systemImage: "heart", value: .favoriten) {
                FavoritenAnsicht()
            }
            Tab("Einkaufsliste", systemImage: "cart", value: .einkauf) {
                EinkaufslisteAnsicht()
            }
            .badge(offeneEinkaeufe.count)
        }
        .task {
            VorratVorbereitung.ausfuehren(kontext: kontext, datenbank: datenbank)
        }
        .task(id: mitteilungsStand) { await mitteilungenPlanen() }
        .onChange(of: phase) { _, neu in
            // z. B. nach Mitternacht oder nach dem Erlauben in den iOS-Einstellungen
            if neu == .active { Task { await mitteilungenPlanen() } }
        }
        .onChange(of: mitteilungen.startOeffnen) { bereich = .start }
    }

    private func mitteilungenPlanen() async {
        let zutaten = vorrat.compactMap { eintrag in
            eintrag.ablaufdatum.map { AblaufMitteilungen.Zutat(name: eintrag.anzeigename, ablaufdatum: $0) }
        }
        await AblaufMitteilungen.neuPlanen(zutaten: zutaten)
    }
}
