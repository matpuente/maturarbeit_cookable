import Foundation

/// Nährwerte pro Portion (aus dem Hauptdatensatz).
nonisolated struct Naehrwerte {
    let kalorien: Double
    let fett: Double
    let gesaettigteFette: Double
    /// in mg
    let cholesterin: Double
    /// in mg
    let natrium: Double
    let kohlenhydrate: Double
    let ballaststoffe: Double
    let zucker: Double
    let protein: Double
}

/// Eine Zutatenzeile eines Rezepts (Tabelle `zutatenzeile`).
nonisolated struct ZutatenZeile: Identifiable {
    let position: Int
    let original: String
    let menge: Double?
    let mengeBis: Double?
    /// vereinheitlichte Originaleinheit: cup, tablespoon, ounce, can …
    let einheit: String?
    let mengeMetrisch: Double?
    let mengeBisMetrisch: Double?
    /// g, ml oder cm
    let einheitMetrisch: String?
    let packungMetrisch: Double?
    let packungEinheitMetrisch: String?
    /// large, medium, small, whole …
    let groesse: String?
    /// Englisch, wird in Etappe 5 übersetzt
    let name: String
    let zusatz: String?
    /// Zutaten der Zutatenliste, die in dieser Zeile vorkommen ("salt and pepper" -> zwei)
    let zutatIDs: [Int]

    var id: Int { position }
}

/// Alles, was die Detailansicht braucht und nicht schon in `RezeptUebersicht` steht.
nonisolated struct RezeptDetails {
    /// Schritte auf Englisch, Temperaturen bereits in °C
    let anleitung: [String]
    let bildURL: URL?
    let portionsgewicht: Double?
    let naehrwerte: Naehrwerte
    var zeilen: [ZutatenZeile] = []
}
