import SwiftData
import SwiftUI

/// Detailansicht eines Rezepts: Foto, Portionsrechner, Zutaten, Anleitung und Nährwerte.
struct RezeptDetailAnsicht: View {
    let vorschlag: RezeptVorschlag

    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(Uebersetzer.self) private var uebersetzer
    @Environment(\.modelContext) private var kontext
    @Query private var vorrat: [VorratsEintrag]
    @Query private var favoriten: [Favorit]
    @Query private var einkauf: [EinkaufsEintrag]
    @State private var details: RezeptDetails?
    @State private var portionen: Int
    @State private var uebersetzung: Uebersetzung?
    @State private var uebersetzungsFehler: DeepLDienst.Fehler?
    @State private var uebersetztGerade = false
    @State private var zeigeOriginal = false

    init(vorschlag: RezeptVorschlag) {
        self.vorschlag = vorschlag
        _portionen = State(initialValue: vorschlag.rezept.portionen)
    }

    private var rezept: RezeptUebersicht { vorschlag.rezept }
    private var faktor: Double { Double(portionen) / Double(rezept.portionen) }
    private var hoechstePortionen: Int { min(100, max(rezept.portionen * 4, 1)) }

    /// Übersetzte Texte nur, wenn vorhanden und nicht «Original» gewählt ist
    private var deutsch: Uebersetzung? { zeigeOriginal ? nil : uebersetzung }
    private var anzeigename: String { deutsch?.name ?? rezept.name }
    private var istFavorit: Bool { favoriten.contains { $0.rezeptID == rezept.id } }

    var body: some View {
        List {
            Section {
                foto
                    .listRowInsets(EdgeInsets())
            }
            if let uebersetzungsFehler {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(uebersetzungsFehler.localizedDescription, systemImage: "exclamationmark.bubble")
                            .font(.footnote)
                        if uebersetzungsFehler != .nichtEingerichtet && uebersetzungsFehler != .schluesselUngueltig {
                            Button("Erneut versuchen") { Task { await uebersetzen() } }
                                .font(.footnote)
                        }
                    }
                }
            }
            kopf
            if let details {
                portionenAbschnitt
                zutatenAbschnitt(details.zeilen)
                anleitungAbschnitt(details.anleitung)
                naehrwerteAbschnitt(details)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .listSectionSpacing(.compact)
        .navigationTitle(anzeigename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation { kontext.favoritUmschalten(rezept.id) }
                } label: {
                    // Farbe am Symbol selbst, sonst färbt die Werkzeugleiste es einheitlich ein
                    Image(systemName: istFavorit ? "heart.fill" : "heart")
                        .foregroundStyle(istFavorit ? Color.red : Color.primary)
                        .symbolEffect(.bounce, value: istFavorit)
                }
                .accessibilityLabel(istFavorit ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen")
                .sensoryFeedback(.selection, trigger: istFavorit)
            }
            if uebersetzung?.zutaten != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button(zeigeOriginal ? "Deutsch" : "Original") { zeigeOriginal.toggle() }
                        .accessibilityHint(zeigeOriginal ? "Zeigt die deutsche Übersetzung" : "Zeigt den englischen Originaltext")
                }
            }
        }
        .task(id: rezept.id) {
            details = try? datenbank.details(zu: rezept.id)
            await uebersetzen()
        }
    }

    // MARK: - Übersetzung

    /// Übersetzt Name, Zutaten und Anleitung (nur beim ersten Öffnen; danach aus dem Speicher).
    private func uebersetzen() async {
        guard let details else { return }
        uebersetzung = uebersetzer.gespeichert(rezept.id)
        uebersetzungsFehler = nil
        uebersetztGerade = true
        defer { uebersetztGerade = false }
        do {
            uebersetzung = try await uebersetzer.rezeptUebersetzen(
                rezeptID: rezept.id,
                name: rezept.name,
                zutaten: details.zeilen.map(englischeBeschreibung),
                anleitung: details.anleitung
            )
        } catch {
            uebersetzungsFehler = error
        }
    }

    // MARK: - Foto und Kopf

    private var foto: some View {
        RezeptFoto(url: details?.bildURL, geladen: details != nil)
            .frame(height: 240)
        .frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }

    private var kopf: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(anzeigename)
                    .font(.title2.bold())
                HStack(spacing: 16) {
                    Label(rezept.zeitText, systemImage: "clock")
                    Label(rezept.kategorie.rawValue, systemImage: "tag")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                Text(verfuegbarText)
                    .font(.subheadline)
                if uebersetztGerade {
                    Label("Wird übersetzt …", systemImage: "character.bubble")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var verfuegbarText: String {
        let text = "\(vorschlag.verfuegbar) von \(vorschlag.benoetigt) Zutaten vorhanden"
        return vorschlag.ersatz == 0 ? text : text + " · \(vorschlag.ersatz) Ersatz"
    }

    // MARK: - Portionsrechner

    private var portionenAbschnitt: some View {
        Section {
            Stepper(value: $portionen, in: 1...hoechstePortionen) {
                Text(portionen == 1 ? "1 Portion" : "\(portionen) Portionen")
                    .font(.headline)
            }
            if portionen != rezept.portionen {
                Button("Zurück auf \(rezept.portionen) Portionen") { portionen = rezept.portionen }
            }
        } header: {
            Text("Portionen")
        } footer: {
            if portionen != rezept.portionen {
                Text("Alle Mengen sind auf \(portionen) statt \(rezept.portionen) Portionen umgerechnet.")
            }
        }
    }

    // MARK: - Zutaten

    private func zutatenAbschnitt(_ zeilen: [ZutatenZeile]) -> some View {
        let vorratIDs = Set(vorrat.map(\.zutatID))
        return Section("Zutaten") {
            ForEach(Array(zeilen.enumerated()), id: \.element.id) { index, zeile in
                let status = status(von: zeile, vorratIDs: vorratIDs)
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Group {
                        switch status {
                        case .vorhanden:
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        case .ersatz:
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill").foregroundStyle(.orange)
                        case .fehlt:
                            Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(Mengenangabe.text(fuer: zeile, faktor: faktor))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .frame(minWidth: 70, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(beschreibung(von: zeile, index: index))
                        if case .ersatz(let name) = status {
                            Text("Ersatz: du hast \(name)")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        } else if case .fehlt = status {
                            Text("fehlt")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contextMenu {
                    Button("Auf die Einkaufsliste", systemImage: "cart.badge.plus") {
                        aufEinkaufsliste([(index, zeile)], nurFehlende: false, vorratIDs: vorratIDs)
                    }
                }
            }
            einkaufsKnopf(zeilen, vorratIDs: vorratIDs)
        }
    }

    // MARK: - Einkaufsliste

    /// Knopf unter den Zutaten: alle fehlenden Zutaten auf die Einkaufsliste
    @ViewBuilder
    private func einkaufsKnopf(_ zeilen: [ZutatenZeile], vorratIDs: Set<Int>) -> some View {
        let fehlende = zeilen.enumerated().filter {
            if case .fehlt = status(von: $0.element, vorratIDs: vorratIDs) { true } else { false }
        }
        if einkauf.contains(where: { $0.rezeptID == rezept.id && !$0.erledigt }) {
            Label("Auf der Einkaufsliste", systemImage: "checkmark.circle")
                .foregroundStyle(.tint)
        } else if !fehlende.isEmpty {
            Button {
                aufEinkaufsliste(fehlende.map { ($0.offset, $0.element) }, nurFehlende: true, vorratIDs: vorratIDs)
            } label: {
                Label("Fehlende Zutaten auf die Einkaufsliste (\(fehlende.count))", systemImage: "cart.badge.plus")
            }
        }
    }

    /// Legt Einkaufseinträge an – mit Menge passend zur gewählten Portionenzahl. Zutaten der Zutatenliste
    /// erhalten den deutschen Begriff (für «Gekauft → in den Vorrat»), andere die Bezeichnung aus dem Rezept.
    private func aufEinkaufsliste(_ zeilen: [(index: Int, zeile: ZutatenZeile)], nurFehlende: Bool, vorratIDs: Set<Int>) {
        let zutaten = Dictionary(uniqueKeysWithValues: datenbank.zutaten.map { ($0.id, $0) })
        for (index, zeile) in zeilen {
            let menge = Mengenangabe.text(fuer: zeile, faktor: faktor)
            // "salt and pepper": eine Zeile, zwei Zutaten – nur die fehlenden
            let bekannte = zeile.zutatIDs
                .filter { !nurFehlende || !vorratIDs.contains($0) }
                .compactMap { zutaten[$0] }
            if bekannte.isEmpty {
                let name = einkaufsname(von: zeile, index: index)
                kontext.insert(EinkaufsEintrag(name: name, menge: menge.isEmpty ? nil : menge,
                                               grundname: zeile.ohneListe.first,
                                               rezeptID: rezept.id, rezeptName: anzeigename))
            } else {
                for (nummer, zutat) in bekannte.enumerated() {
                    kontext.insert(EinkaufsEintrag(name: zutat.name, menge: nummer == 0 && !menge.isEmpty ? menge : nil,
                                                   zutatName: zutat.name, rezeptID: rezept.id, rezeptName: anzeigename))
                }
            }
        }
        try? kontext.save()
    }

    private enum Status {
        case vorhanden
        case ersatz(String)
        case fehlt
    }

    /// Vorhanden (auch vorhandene Grundzutaten), Ersatz aus derselben Austauschgruppe oder fehlt
    /// (auch Zutaten, die nicht in der Zutatenliste stehen).
    private func status(von zeile: ZutatenZeile, vorratIDs: Set<Int>) -> Status {
        if zeile.zutatIDs.contains(where: vorratIDs.contains)
            || zeile.ohneListe.contains(where: { grundname in vorrat.contains { $0.grundname == grundname } }) {
            return .vorhanden
        }
        for zutatID in zeile.zutatIDs {
            guard let gruppe = datenbank.austauschgruppe[zutatID] else { continue }
            if let ersatz = vorrat.first(where: { datenbank.austauschgruppe[$0.zutatID] == gruppe }) {
                return .ersatz(ersatz.anzeigename)
            }
        }
        return .fehlt
    }

    /// Name und Zusatz auf Englisch – so wird die Zeile an DeepL geschickt
    private func englischeBeschreibung(von zeile: ZutatenZeile) -> String {
        [zeile.name, zeile.zusatz].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    /// Übersetzter Name und Zusatz (sonst Englisch), dazu die Grösse auf Deutsch
    private func beschreibung(von zeile: ZutatenZeile, index: Int) -> String {
        var text = deutsch?.zutaten.flatMap { index < $0.count ? $0[index] : nil } ?? englischeBeschreibung(von: zeile)
        if let groesse = zeile.groesse {
            text += ", " + Mengenangabe.groesseAufDeutsch(groesse)
        }
        return text
    }

    /// Kurzer Name für die Einkaufsliste: ohne Zusatz in Klammern oder nach dem Komma
    /// ("Cajun-Gewürzmischung (aus deinem Rezept …)" → "Cajun-Gewürzmischung")
    private func einkaufsname(von zeile: ZutatenZeile, index: Int) -> String {
        (deutsch?.zutaten.flatMap { index < $0.count ? $0[index] : nil } ?? zeile.name).einkaufsKurzform
    }

    // MARK: - Anleitung

    private func anleitungAbschnitt(_ englisch: [String]) -> some View {
        let schritte = deutsch?.anleitung.flatMap { $0.count == englisch.count ? $0 : nil } ?? englisch
        return Section {
            ForEach(Array(schritte.enumerated()), id: \.offset) { nummer, schritt in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(nummer + 1)")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(.tint))
                        .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
                    Text(schritt)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Anleitung")
        } footer: {
            if deutsch?.anleitung != nil {
                Text("Übersetzt mit DeepL")
            }
        }
    }

    // MARK: - Nährwerte

    private func naehrwerteAbschnitt(_ details: RezeptDetails) -> some View {
        let werte = details.naehrwerte
        return Section {
            naehrwert("Energie", "\(Int(werte.kalorien.rounded())) kcal")
            naehrwert("Fett", gramm(werte.fett))
            naehrwert("davon gesättigte Fettsäuren", gramm(werte.gesaettigteFette), eingerueckt: true)
            naehrwert("Kohlenhydrate", gramm(werte.kohlenhydrate))
            naehrwert("davon Zucker", gramm(werte.zucker), eingerueckt: true)
            naehrwert("Nahrungsfasern", gramm(werte.ballaststoffe))
            naehrwert("Eiweiss", gramm(werte.protein))
            naehrwert("Cholesterin", "\(Int(werte.cholesterin.rounded())) mg")
            naehrwert("Natrium", "\(Int(werte.natrium.rounded())) mg")
        } header: {
            Text("Nährwerte pro Portion")
        } footer: {
            if let gewicht = details.portionsgewicht {
                Text("Eine Portion wiegt etwa \(Int(gewicht.rounded())) g. Die Nährwerte gelten pro Portion und ändern sich mit dem Portionsrechner nicht.")
            } else {
                Text("Die Nährwerte gelten pro Portion und ändern sich mit dem Portionsrechner nicht.")
            }
        }
    }

    private func naehrwert(_ titel: String, _ wert: String, eingerueckt: Bool = false) -> some View {
        LabeledContent {
            Text(wert).monospacedDigit()
        } label: {
            Text(titel)
                .padding(.leading, eingerueckt ? 16 : 0)
                .foregroundStyle(eingerueckt ? .secondary : .primary)
        }
    }

    private func gramm(_ wert: Double) -> String {
        wert.formatted(.number.precision(.fractionLength(0...1)).locale(Locale(identifier: "de_CH"))) + " g"
    }
}
