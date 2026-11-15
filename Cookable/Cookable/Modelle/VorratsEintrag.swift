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

/// Stand des Ablaufdatums (CLAUDE.md, Funktion 7): orange ab 3 Tagen vor Ablauf, rot wenn abgelaufen.
nonisolated enum AblaufStatus: Equatable {
    /// Läuft in 0 bis 3 Tagen ab (0 = heute)
    case bald(tage: Int)
    /// Seit so vielen Tagen abgelaufen (mindestens 1)
    case abgelaufen(tage: Int)

    static let warnTage = 3

    var text: String {
        switch self {
        case .bald(0): "läuft heute ab"
        case .bald(1): "noch 1 Tag"
        case .bald(let tage): "noch \(tage) Tage"
        case .abgelaufen(1): "abgelaufen seit 1 Tag"
        case .abgelaufen(let tage): "abgelaufen seit \(tage) Tagen"
        }
    }
}

extension VorratsEintrag {
    /// nil, wenn kein Ablaufdatum gesetzt ist oder es noch mehr als 3 Tage dauert
    func ablaufStatus(heute: Date = .now) -> AblaufStatus? {
        guard let ablaufdatum else { return nil }
        let kalender = Calendar.current
        let tage = kalender.dateComponents([.day], from: kalender.startOfDay(for: heute),
                                           to: kalender.startOfDay(for: ablaufdatum)).day ?? 0
        if tage < 0 { return .abgelaufen(tage: -tage) }
        if tage <= AblaufStatus.warnTage { return .bald(tage: tage) }
        return nil
    }
}
