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

        let zutaten = try abfragen("""
            SELECT id, name, grundzutat, haeufigkeit, austauschgruppe FROM zutat ORDER BY name
            """) { zeile in
            Zutat(
                id: Int(sqlite3_column_int64(zeile, 0)),
                name: String(cString: sqlite3_column_text(zeile, 1)),
                istGrundzutat: sqlite3_column_int(zeile, 2) == 1,
                haeufigkeit: Int(sqlite3_column_int64(zeile, 3)),
                austauschgruppe: sqlite3_column_text(zeile, 4).map { String(cString: $0) }
            )
        }
        self.zutaten = zutaten
        let gruppennamen = Array(Set(zutaten.compactMap(\.austauschgruppe))).sorted()
        let gruppenNummer = Dictionary(uniqueKeysWithValues: gruppennamen.enumerated().map { ($1, $0) })
        austauschgruppe = Dictionary(uniqueKeysWithValues: zutaten.compactMap { zutat in
            zutat.austauschgruppe.flatMap { gruppenNummer[$0] }.map { (zutat.id, $0) }
        })
        zutatenSuche = ZutatenSuche(zutaten: zutaten)
        rezepte = try ladeRezepte(grundzutaten: Set(zutaten.filter(\.istGrundzutat).map(\.id)))
    }

    deinit {
        sqlite3_close(verbindung)
    }

    /// Alle Zutaten der Zutatenliste (klein genug, um sie im Speicher zu halten)
    @ObservationIgnored private(set) var zutaten: [Zutat] = []
    @ObservationIgnored private(set) var zutatenSuche = ZutatenSuche(zutaten: [])
    /// Zutat-ID -> Nummer der Austauschgruppe (nur Zutaten, die zu einer Gruppe gehören)
    @ObservationIgnored private(set) var austauschgruppe: [Int: Int] = [:]
    /// Alle Rezepte mit ihren Zutaten für die Vorschlagsliste (15'000 Einträge, wenige MB)
    @ObservationIgnored private(set) var rezepte: [RezeptUebersicht] = []

    private func ladeRezepte(grundzutaten: Set<Int>) throws -> [RezeptUebersicht] {
        var rezepte = try abfragen("""
            SELECT id, name, gruppe, zeit_min, portionen, beliebtheit, anzahl_ohne_liste FROM rezept
            """) { zeile in
            RezeptUebersicht(
                id: Int(sqlite3_column_int64(zeile, 0)),
                name: String(cString: sqlite3_column_text(zeile, 1)),
                kategorie: Kategorie(rawValue: String(cString: sqlite3_column_text(zeile, 2))) ?? .hauptgericht,
                zeitMinuten: Int(sqlite3_column_int64(zeile, 3)),
                portionen: Int(sqlite3_column_int64(zeile, 4)),
                beliebtheit: Int(sqlite3_column_int64(zeile, 5)),
                anzahlOhneListe: Int(sqlite3_column_int64(zeile, 6))
            )
        }
        let position = Dictionary(uniqueKeysWithValues: rezepte.indices.map { (rezepte[$0].id, $0) })
        let paare = try abfragen("SELECT rezept_id, zutat_id FROM rezept_zutat") { zeile in
            (Int(sqlite3_column_int64(zeile, 0)), Int(sqlite3_column_int64(zeile, 1)))
        }
        for (rezeptID, zutatID) in paare {
            guard let index = position[rezeptID] else { continue }
            if grundzutaten.contains(zutatID) {
                rezepte[index].grundzutaten.append(zutatID)
            } else {
                rezepte[index].zutaten.append(zutatID)
            }
        }
        return rezepte
    }

    var grundzutaten: [Zutat] {
        zutaten.filter(\.istGrundzutat).sorted { $0.haeufigkeit > $1.haeufigkeit }
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
