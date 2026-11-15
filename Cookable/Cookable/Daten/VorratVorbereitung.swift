import Foundation
import SwiftData

/// Wird beim Start der App einmal ausgeführt (unabhängig davon, welcher Tab offen ist).
enum VorratVorbereitung {
    private static let schluesselGrundzutaten = "grundzutatenAngelegt"

    static func ausfuehren(kontext: ModelContext, datenbank: RezeptDatenbank) {
        let eintraege = (try? kontext.fetch(FetchDescriptor<VorratsEintrag>())) ?? []
        idsAbgleichen(eintraege, kontext: kontext, datenbank: datenbank)
        grundzutatenAnlegen(kontext: kontext, datenbank: datenbank)
    }

    /// Beim ersten Start die Grundzutaten in «Immer zuhause» eintragen.
    private static func grundzutatenAnlegen(kontext: ModelContext, datenbank: RezeptDatenbank) {
        guard !UserDefaults.standard.bool(forKey: schluesselGrundzutaten) else { return }
        for zutat in datenbank.grundzutaten {
            kontext.insert(VorratsEintrag(zutatID: zutat.id, name: zutat.name, lagerort: .immerZuhause))
        }
        try? kontext.save()
        UserDefaults.standard.set(true, forKey: schluesselGrundzutaten)
    }

    /// Die IDs in `zutat` können sich ändern, wenn die Zutatenliste neu in die Datenbank übernommen wird.
    /// Massgebend ist deshalb der deutsche Name: passt die gespeicherte ID nicht mehr dazu, wird sie korrigiert.
    /// Wurde ein Begriff umbenannt oder zusammengefasst (z. B. «Vollrahm» -> «Rahm»), wird der Eintrag nachgeführt;
    /// steht die Zutat danach doppelt am selben Lagerort, bleibt nur ein Eintrag.
    private static func idsAbgleichen(_ eintraege: [VorratsEintrag], kontext: ModelContext, datenbank: RezeptDatenbank) {
        let nachID = Dictionary(uniqueKeysWithValues: datenbank.zutaten.map { ($0.id, $0.name) })
        let nachName = Dictionary(datenbank.zutaten.map { ($0.name, $0.id) }, uniquingKeysWith: { erste, _ in erste })
        var geaendert = false
        for eintrag in eintraege where nachID[eintrag.zutatID] != eintrag.name {
            if let id = nachName[eintrag.name] {
                eintrag.zutatID = id
            } else if let id = datenbank.alteNamen[eintrag.name], let neuerName = nachID[id] {
                eintrag.zutatID = id
                eintrag.name = neuerName
            } else {
                continue
            }
            geaendert = true
        }
        guard geaendert else { return }
        var gesehen = Set<String>()
        for eintrag in eintraege where !gesehen.insert("\(eintrag.zutatID)-\(eintrag.lagerort.rawValue)").inserted {
            kontext.delete(eintrag)
        }
        try? kontext.save()
    }
}
