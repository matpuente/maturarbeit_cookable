import Foundation

/// Ein Rezept mit dem Abgleich gegen den Vorrat.
nonisolated struct RezeptVorschlag: Identifiable {
    let rezept: RezeptUebersicht
    /// Zutaten, die genau so im Vorrat sind
    let vorhanden: Int
    /// Zutaten, die durch eine austauschbare Zutat aus dem Vorrat ersetzt werden (z. B. Penne statt Spaghetti)
    let ersatz: Int
    let fehlend: Int
    /// Gewählte «Muss enthalten»-Zutaten, die das Rezept nur über einen Ersatz enthält
    let mussErsatz: Int
    /// Bei einer Suche: Suchtext kommt im Rezeptnamen vor (sonst nur in einer Zutat)
    var nameTreffer = false

    var id: Int { rezept.id }
    var verfuegbar: Int { vorhanden + ersatz }
    var benoetigt: Int { vorhanden + ersatz + fehlend }
    var anteil: Double { benoetigt == 0 ? 1 : Double(verfuegbar) / Double(benoetigt) }
}

/// Berechnet die Rezeptvorschläge (CLAUDE.md, Abschnitt 3, Funktion 2):
/// - normale Zutat im Vorrat: vorhanden; sonst Ersatz, falls eine Zutat derselben Austauschgruppe
///   im Vorrat ist; sonst fehlend
/// - Grundzutat im Vorrat: zählt nicht, sonst fehlend
/// - Zutat ausserhalb der Zutatenliste: fehlend
///
/// Sortierung: Anteil (Ersatz zählt als verfügbar), bei Gleichstand weniger Ersatz, weniger fehlende
/// Zutaten, beliebtere Rezepte zuerst.
///
/// `mussEnthalten`: Zutaten aus dem Vorrat, die jedes vorgeschlagene Rezept enthalten muss – genau oder als
/// austauschbare Zutat. Rezepte, die alle gewählten Zutaten genau enthalten, kommen zuerst.
///
/// `suche`: Suchtext für den Rezeptnamen oder eine Zutat. Bei einer Suche erscheinen auch Rezepte
/// ohne vorhandene Zutat; Treffer im Namen kommen vor Treffern in den Zutaten.
enum RezeptVorschlaege {
    nonisolated struct Suche {
        /// Suchtext in Vergleichsform (`String.suchform`)
        let text: String
        /// Zutaten, deren deutscher Name den Suchtext enthält
        let zutaten: Set<Int>
    }

    static func berechnen(
        rezepte: [RezeptUebersicht],
        vorrat: Set<Int>,
        austauschgruppe: [Int: Int],
        kategorie: Kategorie?,
        zeit: Zeitfilter,
        mussEnthalten: Set<Int> = [],
        suche: Suche? = nil
    ) -> [RezeptVorschlag] {
        let vorratGruppen = Set(vorrat.compactMap { austauschgruppe[$0] })

        return rezepte
            .lazy
            .filter { (kategorie == nil || $0.kategorie == kategorie) && zeit.passt($0.zeitMinuten) }
            .compactMap { rezept -> RezeptVorschlag? in
                var nameTreffer = false
                if let suche {
                    nameTreffer = rezept.suchname.contains(suche.text)
                    guard nameTreffer || rezept.zutaten.contains(where: suche.zutaten.contains) else { return nil }
                }

                // «Muss enthalten»: jede gewählte Zutat genau oder über ihre Austauschgruppe
                var mussErsatz = 0
                for muss in mussEnthalten where !rezept.zutaten.contains(muss) && !rezept.grundzutaten.contains(muss) {
                    guard let gruppe = austauschgruppe[muss],
                          rezept.zutaten.contains(where: { austauschgruppe[$0] == gruppe })
                    else { return nil }
                    mussErsatz += 1
                }

                var vorhanden = 0
                var ersatz = 0
                for zutat in rezept.zutaten {
                    if vorrat.contains(zutat) {
                        vorhanden += 1
                    } else if let gruppe = austauschgruppe[zutat], vorratGruppen.contains(gruppe) {
                        ersatz += 1
                    }
                }
                // Nur Rezepte mit mindestens einer verfügbaren Zutat (ausser bei einer Suche oder gewählter Grundzutat)
                guard vorhanden + ersatz > 0 || !mussEnthalten.isEmpty || suche != nil else { return nil }
                let fehlend = (rezept.zutaten.count - vorhanden - ersatz)
                    + rezept.grundzutaten.count { !vorrat.contains($0) }
                    + rezept.anzahlOhneListe
                return RezeptVorschlag(
                    rezept: rezept, vorhanden: vorhanden, ersatz: ersatz, fehlend: fehlend, mussErsatz: mussErsatz,
                    nameTreffer: nameTreffer
                )
            }
            .sorted { a, b in
                if a.mussErsatz != b.mussErsatz { return a.mussErsatz < b.mussErsatz }
                if a.nameTreffer != b.nameTreffer { return a.nameTreffer }
                if a.anteil != b.anteil { return a.anteil > b.anteil }
                if a.ersatz != b.ersatz { return a.ersatz < b.ersatz }
                if a.fehlend != b.fehlend { return a.fehlend < b.fehlend }
                return a.rezept.beliebtheit < b.rezept.beliebtheit
            }
    }
}
