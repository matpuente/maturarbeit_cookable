import Foundation
import SwiftData

/// Lagerort einer Zutat im Vorrat.
enum Lagerort: String, Codable, CaseIterable, Identifiable {
    case kuehlschrank
    case tiefkuehler
    case vorratsschrank

    var id: Self { self }

    var name: String {
        switch self {
        case .kuehlschrank: "Kühlschrank"
        case .tiefkuehler: "Tiefkühler"
        case .vorratsschrank: "Vorratsschrank"
        }
    }

    var symbol: String {
        switch self {
        case .kuehlschrank: "refrigerator"
        case .tiefkuehler: "snowflake"
        case .vorratsschrank: "cabinet"
        }
    }
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
        self.ablaufdatum = ablaufdatum
        self.hinzugefuegtAm = .now
    }
}
