import SwiftUI

/// Rezeptvorschläge (Platzhalter, folgt in Etappe 3). Zeigt vorerst, dass die Datenbank lesbar ist.
struct RezepteAnsicht: View {
    @Environment(RezeptDatenbank.self) private var datenbank

    var body: some View {
        NavigationStack {
            List {
                Section("Rezeptdatenbank") {
                    zeile("Rezepte", tabelle: "rezept")
                    zeile("Zutaten", tabelle: "zutat")
                    zeile("Zutatenzeilen", tabelle: "zutatenzeile")
                }
            }
            .navigationTitle("Rezepte")
        }
    }

    private func zeile(_ titel: String, tabelle: String) -> some View {
        LabeledContent(titel) {
            if let anzahl = try? datenbank.anzahl(in: tabelle) {
                Text(anzahl, format: .number)
            } else {
                Text("Fehler").foregroundStyle(.red)
            }
        }
    }
}
