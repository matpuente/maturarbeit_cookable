import SwiftUI

/// Detailansicht eines Rezepts (Platzhalter; Zutaten, Anleitung, Nährwerte und Portionsrechner folgen in Etappe 4).
struct RezeptDetailAnsicht: View {
    let vorschlag: RezeptVorschlag

    private var rezept: RezeptUebersicht { vorschlag.rezept }

    var body: some View {
        List {
            Section {
                LabeledContent("Kategorie", value: rezept.kategorie.rawValue)
                LabeledContent("Zubereitungszeit", value: rezept.zeitText)
                LabeledContent("Portionen", value: "\(rezept.portionen)")
                LabeledContent("Zutaten vorhanden", value: "\(vorschlag.verfuegbar) von \(vorschlag.benoetigt)")
                if vorschlag.ersatz > 0 {
                    LabeledContent("Davon mit Ersatz", value: "\(vorschlag.ersatz)")
                }
            }
            Section {
                Text("Zutaten, Anleitung, Nährwerte und Portionsrechner folgen.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(rezept.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
