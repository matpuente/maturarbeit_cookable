import Foundation
import SwiftData

/// Lagerort einer Zutat im Vorrat.
nonisolated enum Lagerort: String, Codable, CaseIterable, Identifiable {
    /// Dinge, die man immer hat (anfangs die Grundzutaten); ohne Ablaufdatum
    case immerZuhause
    case kuehlschrank
    case tiefkuehler
    case vorratsschrank

    var id: Self { self }

    var name: String {
        switch self {
        case .immerZuhause: "Immer zuhause"
        case .kuehlschrank: "Kühlschrank"
        case .tiefkuehler: "Tiefkühler"
        case .vorratsschrank: "Vorratsschrank"
        }
    }

    var symbol: String {
        switch self {
        case .immerZuhause: "house"
        case .kuehlschrank: "refrigerator"
        case .tiefkuehler: "snowflake"
        case .vorratsschrank: "cabinet"
        }
    }

    var hatAblaufdatum: Bool { self != .immerZuhause }
}

/// Eine Zutat im Vorrat des Nutzers (gespeichert mit SwiftData).
@Model
final class VorratsEintrag {
    /// `zutat.id` aus der Rezeptdatenbank
    var zutatID: Int
    /// Deutscher Name aus der Zutatenliste
    var name: String
    var lagerort: Lagerort
    var ablaufdatum: Date?
    var hinzugefuegtAm: Date

    init(zutatID: Int, name: String, lagerort: Lagerort, ablaufdatum: Date? = nil) {
        self.zutatID = zutatID
        self.name = name
        self.lagerort = lagerort
        self.ablaufdatum = lagerort.hatAblaufdatum ? ablaufdatum : nil
        self.hinzugefuegtAm = .now
    }

    var anzeigename: String { name.mitGrossemAnfang }
}
