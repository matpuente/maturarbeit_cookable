import Foundation

/// Autovervollständigung über die Zutatenliste (CLAUDE.md, Abschnitt 6).
struct ZutatenSuche {
    private let eintraege: [(zutat: Zutat, suchform: String, woerter: [Substring], gruppe: String)]

    init(zutaten: [Zutat]) {
        eintraege = zutaten.map { zutat in
            let form = zutat.name.suchform
            return (zutat, form, form.split(whereSeparator: { !$0.isLetter }), zutat.austauschgruppe?.suchform ?? "")
        }
    }

    /// Treffer in dieser Reihenfolge: Name beginnt mit der Eingabe, ein Wort beginnt mit der
    /// Eingabe, Eingabe kommt irgendwo vor, Austauschgruppe beginnt mit der Eingabe ("Pasta" findet
    /// Penne, Spaghetti …). Innerhalb einer Stufe häufige Zutaten zuerst.
    func treffer(fuer eingabe: String, hoechstens: Int = 50) -> [Zutat] {
        let gesucht = eingabe.trimmingCharacters(in: .whitespaces).suchform
        guard !gesucht.isEmpty else { return [] }

        let bewertet: [(zutat: Zutat, stufe: Int)] = eintraege.compactMap { eintrag in
            if eintrag.suchform.hasPrefix(gesucht) {
                return (eintrag.zutat, 0)
            }
            if eintrag.woerter.contains(where: { $0.hasPrefix(gesucht) }) {
                return (eintrag.zutat, 1)
            }
            if eintrag.suchform.contains(gesucht) {
                return (eintrag.zutat, 2)
            }
            if eintrag.gruppe.hasPrefix(gesucht) {
                return (eintrag.zutat, 3)
            }
            return nil
        }
        return bewertet
            .sorted { ($0.stufe, -$0.zutat.haeufigkeit, $0.zutat.name) < ($1.stufe, -$1.zutat.haeufigkeit, $1.zutat.name) }
            .prefix(hoechstens)
            .map(\.zutat)
    }
}
