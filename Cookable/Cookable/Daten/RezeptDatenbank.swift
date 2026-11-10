import Foundation
import Observation
import SQLite3

/// Lesender Zugriff auf die mitgelieferte Rezeptdatenbank (`rezepte.sqlite`).
///
/// Die Datei wird in `Datenaufbereitung/skripte/` erzeugt und nur gelesen, nie verändert.
@Observable
final class RezeptDatenbank {
    enum Fehler: LocalizedError {
        case dateiFehlt
        case oeffnenFehlgeschlagen(String)
        case abfrageFehlgeschlagen(String)

        var errorDescription: String? {
            switch self {
            case .dateiFehlt:
                "Die Rezeptdatenbank fehlt in der App."
            case .oeffnenFehlgeschlagen(let meldung):
                "Die Rezeptdatenbank konnte nicht geöffnet werden: \(meldung)"
            case .abfrageFehlgeschlagen(let meldung):
                "Fehler beim Lesen der Rezeptdatenbank: \(meldung)"
            }
        }
    }

    @ObservationIgnored
    nonisolated(unsafe) private let verbindung: OpaquePointer

    init() throws {
        guard let url = Bundle.main.url(forResource: "rezepte", withExtension: "sqlite") else {
            throw Fehler.dateiFehlt
        }
        var zeiger: OpaquePointer?
        // immutable=1: Die Datei ändert sich nie, SQLite braucht keine Sperren
        let uri = "file:\(url.path(percentEncoded: true))?immutable=1"
        let ergebnis = sqlite3_open_v2(uri, &zeiger, SQLITE_OPEN_READONLY | SQLITE_OPEN_URI, nil)
        guard ergebnis == SQLITE_OK, let zeiger else {
            let meldung = zeiger.map { String(cString: sqlite3_errmsg($0)) } ?? "Code \(ergebnis)"
            sqlite3_close(zeiger)
            throw Fehler.oeffnenFehlgeschlagen(meldung)
        }
        verbindung = zeiger
    }

    deinit {
        sqlite3_close(verbindung)
    }

    /// Anzahl Zeilen einer Tabelle, z. B. `anzahl(in: "rezept")`.
    func anzahl(in tabelle: String) throws -> Int {
        try abfragen("SELECT COUNT(*) FROM \(tabelle)") { Int(sqlite3_column_int64($0, 0)) }.first ?? 0
    }

    /// Führt eine Abfrage aus und wandelt jede Ergebniszeile mit `zeile` um.
    func abfragen<T>(_ sql: String, zeile: (OpaquePointer) -> T) throws -> [T] {
        var anweisung: OpaquePointer?
        guard sqlite3_prepare_v2(verbindung, sql, -1, &anweisung, nil) == SQLITE_OK, let anweisung else {
            throw Fehler.abfrageFehlgeschlagen(String(cString: sqlite3_errmsg(verbindung)))
        }
        defer { sqlite3_finalize(anweisung) }

        var ergebnisse: [T] = []
        while true {
            switch sqlite3_step(anweisung) {
            case SQLITE_ROW:
                ergebnisse.append(zeile(anweisung))
            case SQLITE_DONE:
                return ergebnisse
            default:
                throw Fehler.abfrageFehlgeschlagen(String(cString: sqlite3_errmsg(verbindung)))
            }
        }
    }
}
