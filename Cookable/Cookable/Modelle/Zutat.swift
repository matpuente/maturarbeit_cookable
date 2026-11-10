import Foundation

/// Eine Zutat aus der Zutatenliste der Rezeptdatenbank (Tabelle `zutat`).
nonisolated struct Zutat: Identifiable, Hashable {
    let id: Int
    /// Deutscher Begriff wie in der Zutatenliste, z. B. "brauner Zucker"
    let name: String
    let istGrundzutat: Bool
    /// Anzahl Rezepte, in denen die Zutat vorkommt
    let haeufigkeit: Int

    /// Für die Anzeige mit grossem Anfangsbuchstaben ("Brauner Zucker")
    var anzeigename: String { name.mitGrossemAnfang }
}

nonisolated extension String {
    var mitGrossemAnfang: String {
        prefix(1).uppercased() + dropFirst()
    }

    /// Vergleichsform für die Suche: ohne Gross-/Kleinschreibung und Akzente
    var suchform: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_CH"))
    }
}
