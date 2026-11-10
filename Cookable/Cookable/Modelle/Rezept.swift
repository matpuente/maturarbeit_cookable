import Foundation

/// Kategoriegruppe eines Rezepts (CLAUDE.md, Abschnitt 3). Der Rohwert entspricht `rezept.gruppe`.
nonisolated enum Kategorie: String, CaseIterable, Identifiable {
    case fruehstueck = "Frühstück"
    case hauptgericht = "Hauptgericht"
    case beilage = "Beilage"
    case dessert = "Dessert"
    case snack = "Snack"

    var id: Self { self }
}

/// Filter für die Zubereitungszeit.
nonisolated enum Zeitfilter: String, CaseIterable, Identifiable {
    case alle, bis15, bis30, bis60, ueber60

    var id: Self { self }

    var titel: String {
        switch self {
        case .alle: "Alle"
        case .bis15: "≤ 15"
        case .bis30: "≤ 30"
        case .bis60: "≤ 60"
        case .ueber60: "> 60"
        }
    }

    func passt(_ minuten: Int) -> Bool {
        switch self {
        case .alle: true
        case .bis15: minuten <= 15
        case .bis30: minuten <= 30
        case .bis60: minuten <= 60
        case .ueber60: minuten > 60
        }
    }
}

/// Die Angaben eines Rezepts, die für die Vorschlagsliste nötig sind (beim Start in den Speicher geladen).
nonisolated struct RezeptUebersicht: Identifiable, Hashable {
    let id: Int
    /// Englisch, wird in Etappe 5 übersetzt
    let name: String
    /// Name in Vergleichsform für die Suche (beim Laden einmal berechnet)
    var suchname = ""
    let kategorie: Kategorie
    let zeitMinuten: Int
    let portionen: Int
    /// Rang nach Anzahl Bewertungen (1 = meistbewertet); nur für die Sortierung, wird nicht angezeigt
    let beliebtheit: Int
    /// Zutaten der Zutatenliste, die keine Grundzutaten sind
    var zutaten: [Int] = []
    /// Grundzutaten, die das Rezept braucht
    var grundzutaten: [Int] = []
    /// Zutaten, die nicht in der Zutatenliste stehen (zählen immer als fehlend)
    let anzahlOhneListe: Int

    /// "45 Min.", "1 Std. 30 Min." oder ab zwei Tagen "10 Tage"
    var zeitText: String {
        if zeitMinuten >= 2 * 24 * 60 {
            return "\(Int((Double(zeitMinuten) / (24 * 60)).rounded())) Tage"
        }
        let stunden = zeitMinuten / 60
        let minuten = zeitMinuten % 60
        switch (stunden, minuten) {
        case (0, _): return "\(minuten) Min."
        case (_, 0): return "\(stunden) Std."
        default: return "\(stunden) Std. \(minuten) Min."
        }
    }
}
