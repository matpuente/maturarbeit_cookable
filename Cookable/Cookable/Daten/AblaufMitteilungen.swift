import Foundation
import Observation
import OSLog
import UIKit
import UserNotifications

/// Lokale Mitteilungen vor dem Ablaufen (CLAUDE.md, Funktion 7).
///
/// Höchstens eine Mitteilung pro Tag, mit allen Zutaten, die an diesem Tag gemeldet werden sollen.
/// Die Mitteilungen werden bei jedem Start und bei jeder Änderung am Vorrat neu geplant.
enum AblaufMitteilungen {
    // Einstellungen (@AppStorage)
    static let schluesselAn = "mitteilungenAn"
    static let schluesselTage = "mitteilungenTage"
    static let schluesselMinuten = "mitteilungenMinuten"
    static let standardTage = "1"
    static let standardMinuten = 17 * 60

    /// Wählbare Zeitpunkte: so viele Tage vor dem Ablaufdatum
    static let vorlaufOptionen = [0, 1, 3]

    private static let kennung = "ablauf-"
    /// Wie weit im Voraus geplant wird (iOS erlaubt höchstens 64 geplante Mitteilungen pro App)
    private static let planTage = 60

    nonisolated struct Zutat: Sendable {
        let name: String
        let ablaufdatum: Date
    }

    /// "0,1,3" → [0, 1, 3]
    static func vorlauf(aus text: String) -> Set<Int> {
        Set(text.split(separator: ",").compactMap { Int($0) }.filter(vorlaufOptionen.contains))
    }

    static func text(aus vorlauf: Set<Int>) -> String {
        vorlauf.sorted().map(String.init).joined(separator: ",")
    }

    static func titel(vorlauf: Int) -> String {
        switch vorlauf {
        case 0: "Am Ablauftag"
        case 1: "1 Tag vorher"
        default: "\(vorlauf) Tage vorher"
        }
    }

    // MARK: - Erlaubnis

    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Fragt nur, wenn noch nie gefragt wurde. Gibt zurück, ob Mitteilungen erlaubt sind.
    @discardableResult
    static func erlaubnisAnfragen() async -> Bool {
        let zentrale = UNUserNotificationCenter.current()
        switch await status() {
        case .notDetermined:
            return (try? await zentrale.requestAuthorization(options: [.alert, .sound])) ?? false
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    // MARK: - Planen

    /// Ein geplanter Tag: Zeitpunkt und Text der Mitteilung
    nonisolated struct Plan: Sendable {
        let zeitpunkt: Date
        let titel: String
        let text: String
    }

    /// Berechnet die Mitteilungen (ohne sie zu planen) – auch für die Vorschau im Einstellungsfenster.
    static func plaene(fuer zutaten: [Zutat], vorlauf: Set<Int>, minuten: Int, jetzt: Date = .now) -> [Plan] {
        let kalender = Calendar.current
        let heute = kalender.startOfDay(for: jetzt)
        // Ablaufdatum (Tagesbeginn) -> Namen
        var nachTag: [Date: [String]] = [:]
        for zutat in zutaten {
            let tag = kalender.startOfDay(for: zutat.ablaufdatum)
            guard tag >= heute else { continue }  // bereits abgelaufen: keine neue Mitteilung
            if !(nachTag[tag]?.contains(zutat.name) ?? false) {
                nachTag[tag, default: []].append(zutat.name)
            }
        }

        var plaene: [Plan] = []
        for versatz in 0..<planTage {
            guard let tag = kalender.date(byAdding: .day, value: versatz, to: heute),
                  let zeitpunkt = kalender.date(byAdding: .minute, value: minuten, to: tag),
                  zeitpunkt > jetzt
            else { continue }
            // Gruppen dieses Tages: «heute», «morgen», «in 3 Tagen»
            let gruppen: [(vorlauf: Int, namen: [String])] = vorlauf.sorted().compactMap { tage in
                guard let ablauf = kalender.date(byAdding: .day, value: tage, to: tag),
                      let namen = nachTag[ablauf], !namen.isEmpty
                else { return nil }
                return (tage, namen.sorted())
            }
            guard !gruppen.isEmpty else { continue }

            if gruppen.count == 1, let gruppe = gruppen.first {
                plaene.append(Plan(zeitpunkt: zeitpunkt,
                                   titel: "\(wann(gruppe.vorlauf)) \(gruppe.namen.count == 1 ? "läuft" : "laufen") ab: \(gruppe.namen.joined(separator: ", "))",
                                   text: "Tippe hier für Rezepte zum Aufbrauchen."))
            } else {
                let zeilen = gruppen.map { "\(wann($0.vorlauf)): \($0.namen.joined(separator: ", "))" }
                plaene.append(Plan(zeitpunkt: zeitpunkt, titel: "Bald ablaufend",
                                   text: zeilen.joined(separator: "\n") + "\nTippe hier für Rezepte zum Aufbrauchen."))
            }
        }
        return plaene
    }

    private static func wann(_ vorlauf: Int) -> String {
        switch vorlauf {
        case 0: "Heute"
        case 1: "Morgen"
        default: "In \(vorlauf) Tagen"
        }
    }

    /// Entfernt alle geplanten Ablauf-Mitteilungen und plant sie neu.
    static func neuPlanen(zutaten: [Zutat]) async {
        let zentrale = UNUserNotificationCenter.current()
        let alte = await zentrale.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(kennung) }
        zentrale.removePendingNotificationRequests(withIdentifiers: alte)

        let einstellungen = UserDefaults.standard
        let an = einstellungen.object(forKey: schluesselAn) as? Bool ?? true
        let vorlauf = vorlauf(aus: einstellungen.string(forKey: schluesselTage) ?? standardTage)
        let minuten = einstellungen.object(forKey: schluesselMinuten) as? Int ?? standardMinuten
        guard an, !vorlauf.isEmpty else { return }
        switch await status() {
        case .authorized, .provisional, .ephemeral: break
        default: return
        }

        let kalender = Calendar.current
        for plan in plaene(fuer: zutaten, vorlauf: vorlauf, minuten: minuten) {
            let inhalt = UNMutableNotificationContent()
            inhalt.title = plan.titel
            inhalt.body = plan.text
            inhalt.sound = .default
            let komponenten = kalender.dateComponents([.year, .month, .day, .hour, .minute], from: plan.zeitpunkt)
            let anfrage = UNNotificationRequest(
                identifier: kennung + ISO8601DateFormatter().string(from: plan.zeitpunkt),
                content: inhalt,
                trigger: UNCalendarNotificationTrigger(dateMatching: komponenten, repeats: false)
            )
            try? await zentrale.add(anfrage)
        }
    }
}

/// Antippen einer Mitteilung öffnet die Startseite; im Vordergrund erscheint die Mitteilung als Banner.
@Observable
final class MitteilungsEmpfaenger: NSObject, UNUserNotificationCenterDelegate {
    /// Wird bei jedem Antippen erhöht – `HauptAnsicht` wechselt dann zum Tab «Start»
    var startOeffnen = 0

    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Mit Abschlussblock statt `async`: iOS verlangt, dass er auf dem Haupt-Thread aufgerufen wird
    // (die `async`-Fassung endet auf einem Hintergrund-Thread – auf dem iPhone stürzte die App beim Antippen ab).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        DispatchQueue.main.async { completionHandler([.banner, .list, .sound]) }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        Logger(subsystem: "Maturarbeit.cookable", category: "Mitteilungen").info("Mitteilung angetippt")
        DispatchQueue.main.async {
            MainActor.assumeIsolated { self.startOeffnen += 1 }
            completionHandler()
        }
    }
}
