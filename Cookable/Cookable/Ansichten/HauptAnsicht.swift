import SwiftData
import SwiftUI

/// Tab-Navigation der App.
struct HauptAnsicht: View {
    enum Bereich: Hashable {
        case start, vorrat, rezepte
    }

    @Environment(\.modelContext) private var kontext
    @Environment(RezeptDatenbank.self) private var datenbank
    @State private var bereich = Bereich.start

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
        }
        .task {
            VorratVorbereitung.ausfuehren(kontext: kontext, datenbank: datenbank)
        }
    }
}
