import Foundation
import SwiftData

/// Ein als Favorit gemerktes Rezept (CLAUDE.md, Funktion 8).
/// Die Rezept-ID stammt von Food.com und bleibt auch bei einer neuen Datenbank gleich.
@Model
final class Favorit {
    @Attribute(.unique) var rezeptID: Int
    var hinzugefuegtAm: Date

    init(rezeptID: Int) {
        self.rezeptID = rezeptID
        self.hinzugefuegtAm = .now
    }
}

extension ModelContext {
    /// Fügt das Rezept zu den Favoriten hinzu oder entfernt es wieder.
    func favoritUmschalten(_ rezeptID: Int) {
        let vorhanden = (try? fetch(FetchDescriptor<Favorit>(predicate: #Predicate { $0.rezeptID == rezeptID }))) ?? []
        if vorhanden.isEmpty {
            insert(Favorit(rezeptID: rezeptID))
        } else {
            vorhanden.forEach(delete)
        }
        try? save()
    }
}
