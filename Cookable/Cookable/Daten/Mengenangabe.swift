import Foundation

/// Formatiert die Menge einer Zutatenzeile für die gewünschte Portionenzahl (CLAUDE.md, Abschnitt 6):
/// Cups, Pints usw. in ml, Ounces und Pounds in g; Ess- und Teelöffel bleiben EL und TL.
nonisolated enum Mengenangabe {
    /// z. B. "240 ml", "1½ EL", "2 Dosen (425 g)", "1–2", "" (ohne Menge)
    static func text(fuer zeile: ZutatenZeile, faktor: Double) -> String {
        guard let menge = zeile.menge else { return "" }
        let bis = zeile.mengeBis

        // Butter in "sticks" (USA): 1 stick = 113 g
        if zeile.einheit == "stick", zeile.name.contains("butter") {
            return gewicht(menge * 113 * faktor, bis: bis.map { $0 * 113 * faktor })
        }

        switch zeile.einheit {
        case "tablespoon":
            return bereich(menge * faktor, bis.map { $0 * faktor }) + " EL"
        case "teaspoon":
            return bereich(menge * faktor, bis.map { $0 * faktor }) + " TL"
        default:
            break
        }

        if let metrisch = zeile.mengeMetrisch, let einheit = zeile.einheitMetrisch {
            let bisMetrisch = zeile.mengeBisMetrisch.map { $0 * faktor }
            switch einheit {
            case "ml": return volumen(metrisch * faktor, bis: bisMetrisch)
            case "g": return gewicht(metrisch * faktor, bis: bisMetrisch)
            case "cm": return bereich(metrisch * faktor, bisMetrisch) + " cm"
            default: break
            }
        }

        let anzahl = menge * faktor
        var text = bereich(anzahl, bis.map { $0 * faktor })
        if let einheit = zeile.einheit {
            text += " " + einheitAufDeutsch(einheit, mehrzahl: (bis ?? menge) * faktor > 1)
        }
        if let packung = zeile.packungMetrisch, let packungEinheit = zeile.packungEinheitMetrisch {
            text += " (" + (packungEinheit == "ml" ? volumen(packung, bis: nil) : packungEinheit == "g"
                ? gewicht(packung, bis: nil) : "\(gerundet(packung)) \(packungEinheit)") + ")"
        }
        return text
    }

    // MARK: - Volumen und Gewicht

    /// Rundung, damit keine Werte wie "37,5 ml" oder "113,4 g" erscheinen:
    /// unter 10 auf 1, unter 50 auf 5, sonst auf 10; ab 1000 in l bzw. kg.
    static func gerundet(_ wert: Double) -> Double {
        let schritt: Double = wert < 10 ? 1 : wert < 50 ? 5 : 10
        return max(schritt, (wert / schritt).rounded() * schritt)
    }

    private static func volumen(_ wert: Double, bis: Double?) -> String {
        metrisch(wert, bis: bis, klein: "ml", gross: "l")
    }

    private static func gewicht(_ wert: Double, bis: Double?) -> String {
        metrisch(wert, bis: bis, klein: "g", gross: "kg")
    }

    private static func metrisch(_ wert: Double, bis: Double?, klein: String, gross: String) -> String {
        let oben = bis ?? wert
        if oben >= 1000 {
            let unten = bis == nil ? "" : dezimal(wert / 1000) + "–"
            return unten + dezimal(oben / 1000) + " " + gross
        }
        let unten = bis == nil ? "" : "\(Int(gerundet(wert)))–"
        return unten + "\(Int(gerundet(oben))) \(klein)"
    }

    /// Eine Nachkommastelle (Schweizer Schreibweise mit Punkt), ohne ".0": 1.5 -> "1.5", 2.0 -> "2"
    private static func dezimal(_ wert: Double) -> String {
        let gerundet = (wert * 10).rounded() / 10
        return gerundet.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_CH")))
    }

    // MARK: - Stückzahlen und Löffel

    private static func bereich(_ wert: Double, _ bis: Double?) -> String {
        guard let bis else { return bruch(wert) }
        return bruch(wert) + "–" + bruch(bis)
    }

    /// 0.5 -> "½", 1.333 -> "1⅓", 2.4 -> "2.4"
    static func bruch(_ wert: Double) -> String {
        let brueche: [(Double, String)] = [(0, ""), (1 / 8, "⅛"), (1 / 4, "¼"), (1 / 3, "⅓"), (1 / 2, "½"),
                                           (2 / 3, "⅔"), (3 / 4, "¾"), (1, "")]
        let ganz = wert.rounded(.down)
        let rest = wert - ganz
        guard let (anteil, zeichen) = brueche.min(by: { abs($0.0 - rest) < abs($1.0 - rest) }),
              abs(anteil - rest) < 0.05 else {
            return dezimal(wert)
        }
        let ganzzahl = Int(ganz) + (anteil == 1 ? 1 : 0)
        if zeichen.isEmpty { return "\(max(ganzzahl, 0))" }
        return ganzzahl == 0 ? zeichen : "\(ganzzahl)\(zeichen)"
    }

    private static func einheitAufDeutsch(_ einheit: String, mehrzahl: Bool) -> String {
        let woerter: [String: (String, String)] = [
            "can": ("Dose", "Dosen"), "package": ("Packung", "Packungen"), "jar": ("Glas", "Gläser"),
            "slice": ("Scheibe", "Scheiben"), "clove": ("Zehe", "Zehen"), "pinch": ("Prise", "Prisen"),
            "dash": ("Spritzer", "Spritzer"), "drop": ("Tropfen", "Tropfen"), "bunch": ("Bund", "Bund"),
            "head": ("Kopf", "Köpfe"), "sprig": ("Zweig", "Zweige"), "stalk": ("Stange", "Stangen"),
            "leaf": ("Blatt", "Blätter"), "piece": ("Stück", "Stück"), "stick": ("Stange", "Stangen"),
            "square": ("Stück", "Stück"), "cube": ("Würfel", "Würfel"), "envelope": ("Päckchen", "Päckchen"),
            "packet": ("Päckchen", "Päckchen"), "bottle": ("Flasche", "Flaschen"), "box": ("Schachtel", "Schachteln"),
            "bag": ("Beutel", "Beutel"), "container": ("Becher", "Becher"), "carton": ("Packung", "Packungen"),
            "loaf": ("Laib", "Laibe"), "fillet": ("Filet", "Filets"),
        ]
        guard let (einzahl, mehr) = woerter[einheit] else { return einheit }
        return mehrzahl ? mehr : einzahl
    }

    /// Grössenangabe auf Deutsch für den Zusatz
    static func groesseAufDeutsch(_ groesse: String) -> String {
        ["large": "gross", "medium": "mittelgross", "small": "klein", "whole": "ganz",
         "extra large": "sehr gross", "jumbo": "sehr gross"][groesse] ?? groesse
    }
}
