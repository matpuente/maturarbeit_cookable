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
///
/// `mussEnthalten`: Zutaten aus dem Vorrat, die jedes vorgeschlagene Rezept enthalten muss
/// (z. B. um ein bestimmtes Lebensmittel aufzubrauchen). Der übrige Vorrat zählt weiterhin für den Anteil.
enum RezeptVorschlaege {
    static func berechnen(
        rezepte: [RezeptUebersicht],
        vorrat: Set<Int>,
        kategorie: Kategorie?,
        zeit: Zeitfilter,
        mussEnthalten: Set<Int> = []
    ) -> [RezeptVorschlag] {
        rezepte
            .lazy
            .filter { (kategorie == nil || $0.kategorie == kategorie) && zeit.passt($0.zeitMinuten) }
            .filter { rezept in
                mussEnthalten.allSatisfy { rezept.zutaten.contains($0) || rezept.grundzutaten.contains($0) }
            }
            .compactMap { rezept -> RezeptVorschlag? in
                let vorhanden = rezept.zutaten.count { vorrat.contains($0) }
                // Nur Rezepte mit mindestens einer vorhandenen Zutat (oder einer gewählten Grundzutat)
                guard vorhanden > 0 || !mussEnthalten.isEmpty else { return nil }
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
