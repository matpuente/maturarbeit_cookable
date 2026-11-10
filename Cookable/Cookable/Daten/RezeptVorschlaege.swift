import Foundation

/// Ein Rezept mit dem Abgleich gegen den Vorrat.
nonisolated struct RezeptVorschlag: Identifiable {
    let rezept: RezeptUebersicht
    let vorhanden: Int
    let fehlend: Int

    var id: Int { rezept.id }
    var benoetigt: Int { vorhanden + fehlend }
    var anteil: Double { benoetigt == 0 ? 1 : Double(vorhanden) / Double(benoetigt) }
}

/// Berechnet die Rezeptvorschläge (CLAUDE.md, Abschnitt 3, Funktion 2):
/// - normale Zutat im Vorrat: vorhanden, sonst fehlend
/// - Grundzutat im Vorrat: zählt nicht, sonst fehlend
/// - Zutat ausserhalb der Zutatenliste: fehlend
enum RezeptVorschlaege {
    static func berechnen(
        rezepte: [RezeptUebersicht],
        vorrat: Set<Int>,
        kategorie: Kategorie?,
        zeit: Zeitfilter
    ) -> [RezeptVorschlag] {
        rezepte
            .lazy
            .filter { (kategorie == nil || $0.kategorie == kategorie) && zeit.passt($0.zeitMinuten) }
            .compactMap { rezept -> RezeptVorschlag? in
                let vorhanden = rezept.zutaten.count { vorrat.contains($0) }
                // Nur Rezepte mit mindestens einer vorhandenen Zutat
                guard vorhanden > 0 else { return nil }
                let fehlend = (rezept.zutaten.count - vorhanden)
                    + rezept.grundzutaten.count { !vorrat.contains($0) }
                    + rezept.anzahlOhneListe
                return RezeptVorschlag(rezept: rezept, vorhanden: vorhanden, fehlend: fehlend)
            }
            .sorted { a, b in
                if a.anteil != b.anteil { return a.anteil > b.anteil }
                if a.fehlend != b.fehlend { return a.fehlend < b.fehlend }
                return a.rezept.beliebtheit < b.rezept.beliebtheit
            }
    }
}
