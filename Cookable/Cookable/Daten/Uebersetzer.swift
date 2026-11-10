import Foundation
import Observation
import SwiftData

/// Koordiniert die Übersetzungen: fragt nur an, was noch nicht gespeichert ist, und bündelt Rezeptnamen
/// aus der Liste zu Paketen.
@Observable
final class Uebersetzer {
    /// Letzter Fehler beim Übersetzen der Rezeptnamen (für die Meldung über der Liste)
    private(set) var namenFehler: DeepLDienst.Fehler?

    @ObservationIgnored private let dienst = DeepLDienst()
    @ObservationIgnored private let kontext: ModelContext
    @ObservationIgnored private var wartendeNamen: [Int: String] = [:]
    @ObservationIgnored private var laufendeNamen: Set<Int> = []
    @ObservationIgnored private var paketAufgabe: Task<Void, Never>?
    /// Nach einem Fehler eine Weile keine neuen Anfragen, damit DeepL nicht dauernd angefragt wird
    @ObservationIgnored private var pauseBis = Date.distantPast

    init(kontext: ModelContext) {
        self.kontext = kontext
    }

    var istEingerichtet: Bool { dienst.istEingerichtet }

    func gespeichert(_ rezeptID: Int) -> Uebersetzung? {
        try? kontext.fetch(FetchDescriptor<Uebersetzung>(predicate: #Predicate { $0.rezeptID == rezeptID })).first
    }

    // MARK: - Rezeptnamen in der Liste

    /// Merkt einen sichtbaren Rezeptnamen vor; nach einer kurzen Pause werden alle vorgemerkten zusammen übersetzt.
    func nameAnfordern(rezeptID: Int, englisch: String) {
        guard dienst.istEingerichtet, Date.now >= pauseBis,
              !laufendeNamen.contains(rezeptID), wartendeNamen[rezeptID] == nil else { return }
        wartendeNamen[rezeptID] = englisch
        paketAufgabe?.cancel()
        paketAufgabe = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.namenUebersetzen()
        }
    }

    /// Erlaubt nach einem Fehler sofort einen neuen Versuch.
    func erneutVersuchen() {
        pauseBis = .distantPast
        namenFehler = nil
    }

    private func namenUebersetzen() async {
        let paket = wartendeNamen.filter { gespeichert($0.key) == nil }
        wartendeNamen.removeAll()
        guard !paket.isEmpty else { return }
        let ids = Array(paket.keys)
        laufendeNamen.formUnion(ids)
        defer { laufendeNamen.subtract(ids) }
        do {
            let deutsch = try await dienst.uebersetzen(ids.map { paket[$0]! })
            for (id, name) in zip(ids, deutsch) where gespeichert(id) == nil {
                kontext.insert(Uebersetzung(rezeptID: id, name: name))
            }
            try? kontext.save()
            namenFehler = nil
        } catch {
            namenFehler = error
            pauseBis = .now.addingTimeInterval(30)
        }
    }

    // MARK: - Ganzes Rezept

    /// Übersetzt Name, Zutaten und Anleitung eines Rezepts – nur was noch fehlt – und speichert das Ergebnis.
    func rezeptUebersetzen(
        rezeptID: Int, name: String, zutaten: [String], anleitung: [String]
    ) async throws(DeepLDienst.Fehler) -> Uebersetzung {
        if let vorhanden = gespeichert(rezeptID),
           vorhanden.istVollstaendig(zeilen: zutaten.count, schritte: anleitung.count) {
            return vorhanden
        }
        let bekannterName = gespeichert(rezeptID)?.name
        let texte = (bekannterName == nil ? [name] : []) + zutaten + anleitung
        let deutsch = try await dienst.uebersetzen(texte)

        let versatz = bekannterName == nil ? 1 : 0
        let uebersetzung = gespeichert(rezeptID) ?? {
            let neu = Uebersetzung(rezeptID: rezeptID, name: deutsch[0])
            kontext.insert(neu)
            return neu
        }()
        uebersetzung.zutaten = Array(deutsch[versatz..<versatz + zutaten.count])
        uebersetzung.anleitung = Array(deutsch[(versatz + zutaten.count)...])
        uebersetzung.datum = .now
        try? kontext.save()
        return uebersetzung
    }
}
