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
    }
}
