import Foundation
import SwiftData

/// Gespeicherte Übersetzung eines Rezepts (CLAUDE.md, Abschnitt 6: jedes Rezept wird nur einmal übersetzt).
///
/// Für die Vorschlagsliste wird zuerst nur der Name übersetzt; Zutaten und Anleitung kommen beim ersten
/// Öffnen des Rezepts dazu.
@Model
final class Uebersetzung {
    @Attribute(.unique) var rezeptID: Int
    var name: String
    /// Name und Zusatz jeder Zutatenzeile, in der Reihenfolge von `zutatenzeile.position`
    var zutaten: [String]?
    var anleitung: [String]?
    var datum: Date

    init(rezeptID: Int, name: String) {
        self.rezeptID = rezeptID
        self.name = name
        self.datum = .now
    }

    /// Zutaten und Anleitung sind übersetzt (und passen zur Anzahl Zeilen bzw. Schritte)
    func istVollstaendig(zeilen: Int, schritte: Int) -> Bool {
        zutaten?.count == zeilen && anleitung?.count == schritte
    }
}
