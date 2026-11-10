import Foundation

/// Übersetzt Texte über die DeepL API (CLAUDE.md, Abschnitt 6).
///
/// Der Schlüssel steht in `Geheim/DeepL.plist` (Schlüssel "Schluessel"); der Ordner ist in `.gitignore`
/// ausgeschlossen. Vorlage: `Cookable/DeepL-Vorlage.plist`.
nonisolated struct DeepLDienst: Sendable {
    enum Fehler: LocalizedError, Equatable {
        case nichtEingerichtet
        case schluesselUngueltig
        case kontingentAufgebraucht
        case keinInternet
        case zuVieleAnfragen
        case unbekannt(String)

        var errorDescription: String? {
            switch self {
            case .nichtEingerichtet, .schluesselUngueltig:
                "Übersetzung nicht eingerichtet – das Rezept wird auf Englisch angezeigt."
            case .kontingentAufgebraucht:
                "Das monatliche Übersetzungskontingent ist aufgebraucht – das Rezept wird auf Englisch angezeigt."
            case .keinInternet:
                "Keine Internetverbindung – das Rezept wird auf Englisch angezeigt."
            case .zuVieleAnfragen:
                "Zu viele Übersetzungen auf einmal – bitte gleich nochmals versuchen."
            case .unbekannt:
                "Die Übersetzung hat nicht geklappt – das Rezept wird auf Englisch angezeigt."
            }
        }
    }

    /// Höchstens 50 Texte pro Anfrage (Vorgabe von DeepL)
    private static let paketGroesse = 50

    private let schluessel: String?

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "DeepL", withExtension: "plist")
        let inhalt = url.flatMap { NSDictionary(contentsOf: $0) }
        let wert = (inhalt?["Schluessel"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        schluessel = (wert?.isEmpty == false && wert?.hasPrefix("HIER-") == false) ? wert : nil
    }

    var istEingerichtet: Bool { schluessel != nil }

    /// Übersetzt die Texte vom Englischen ins Deutsche (Du-Form, Schweizer Begriffe). Reihenfolge bleibt erhalten.
    func uebersetzen(_ texte: [String]) async throws(Fehler) -> [String] {
        guard let schluessel else { throw .nichtEingerichtet }
        var ergebnis: [String] = []
        for start in stride(from: 0, to: texte.count, by: Self.paketGroesse) {
            let paket = Array(texte[start..<min(start + Self.paketGroesse, texte.count)])
            ergebnis += try await anfrage(paket, schluessel: schluessel).map(Self.schweizerisch)
        }
        return ergebnis
    }

    private func anfrage(_ texte: [String], schluessel: String) async throws(Fehler) -> [String] {
        // Schlüssel der Gratis-Version enden auf ":fx" und verwenden einen eigenen Server
        let server = schluessel.hasSuffix(":fx") ? "api-free.deepl.com" : "api.deepl.com"
        var anfrage = URLRequest(url: URL(string: "https://\(server)/v2/translate")!)
        anfrage.httpMethod = "POST"
        anfrage.timeoutInterval = 20
        anfrage.setValue("DeepL-Auth-Key \(schluessel)", forHTTPHeaderField: "Authorization")
        anfrage.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let inhalt: [String: Any] = [
            "text": texte,
            "source_lang": "EN",
            "target_lang": "DE",
            "formality": "prefer_less",
            "context": "Text from a cooking recipe: recipe titles, ingredient names and cooking instructions.",
        ]
        anfrage.httpBody = try? JSONSerialization.data(withJSONObject: inhalt)

        let daten: Data
        let antwort: URLResponse
        do {
            (daten, antwort) = try await URLSession.shared.data(for: anfrage)
        } catch let fehler as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut,
                                                .cannotFindHost, .cannotConnectToHost, .dataNotAllowed]
            .contains(fehler.code) {
            throw .keinInternet
        } catch {
            throw .unbekannt(error.localizedDescription)
        }

        switch (antwort as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200: break
        case 403: throw .schluesselUngueltig
        case 456: throw .kontingentAufgebraucht
        case 429: throw .zuVieleAnfragen
        case let code: throw .unbekannt("HTTP \(code)")
        }

        struct Antwort: Decodable {
            struct Uebersetzung: Decodable { let text: String }
            let translations: [Uebersetzung]
        }
        guard let ergebnis = try? JSONDecoder().decode(Antwort.self, from: daten),
              ergebnis.translations.count == texte.count else {
            throw .unbekannt("Unerwartete Antwort")
        }
        return ergebnis.translations.map(\.text)
    }

    // MARK: - Schweizer Begriffe

    /// Längere Begriffe zuerst, damit "Schlagsahne" nicht zu "SchlagRahm" wird. Sahne ist weiblich, Rahm
    /// männlich: Die häufigsten Artikel werden mit angepasst ("die Sahne unterrühren" -> "den Rahm unterrühren").
    private static let ersetzungen: [(String, String)] = [
        ("die saure Sahne", "den Sauerrahm"), ("der sauren Sahne", "dem Sauerrahm"),
        ("saure Sahne", "Sauerrahm"), ("Saure Sahne", "Sauerrahm"),
        ("die Schlagsahne", "den Schlagrahm"), ("der Schlagsahne", "dem Schlagrahm"), ("Schlagsahne", "Schlagrahm"),
        ("die Sahne", "den Rahm"), ("Die Sahne", "Den Rahm"), ("der Sahne", "dem Rahm"), ("Sahne", "Rahm"), ("Hähnchenbrust", "Pouletbrust"), ("Hühnerbrust", "Pouletbrust"),
        ("Hähnchen", "Poulet"), ("Paprikaschote", "Peperoni"), ("Zucchini", "Zucchetti"),
        ("Feldsalat", "Nüsslisalat"), ("Brötchen", "Brötli"),
    ]

    static func schweizerisch(_ text: String) -> String {
        var ergebnis = text
        for (alt, neu) in ersetzungen {
            ergebnis = ergebnis.replacingOccurrences(of: alt, with: neu)
        }
        return ergebnis.replacingOccurrences(of: "ß", with: "ss")
    }
}
