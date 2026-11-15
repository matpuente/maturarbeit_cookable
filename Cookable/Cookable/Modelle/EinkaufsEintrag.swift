import Foundation
import SwiftData

/// Ein Eintrag auf der Einkaufsliste (CLAUDE.md, Funktion 6).
@Model
final class EinkaufsEintrag {
    /// Angezeigter Name (deutscher Begriff der Zutatenliste oder übersetzte Bezeichnung aus dem Rezept)
    var name: String
    /// z. B. "240 ml" oder "2 EL" (passend zur gewählten Portionenzahl), nil = ohne Menge
    var menge: String?
    /// Deutscher Begriff der Zutatenliste, falls bekannt – nötig für «Gekauft → in den Vorrat».
    /// Gespeichert wird der Name, nicht die ID (die IDs der Zutatenliste sind nicht dauerhaft).
    var zutatName: String?
    var rezeptID: Int?
    var rezeptName: String?
    var erledigt: Bool
    var hinzugefuegtAm: Date

    init(name: String, menge: String? = nil, zutatName: String? = nil, rezeptID: Int? = nil, rezeptName: String? = nil) {
        self.name = name
        self.menge = menge
        self.zutatName = zutatName
        self.rezeptID = rezeptID
        self.rezeptName = rezeptName
        self.erledigt = false
        self.hinzugefuegtAm = .now
    }

    var anzeigename: String { name.mitGrossemAnfang }
}
