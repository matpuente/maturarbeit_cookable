import SwiftData
import SwiftUI

/// Einkaufsliste mit «Gekauft → in den Vorrat» (CLAUDE.md, Funktion 6).
struct EinkaufslisteAnsicht: View {
    enum Gruppierung: String, CaseIterable, Identifiable {
        case zutaten, rezepte

        var id: Self { self }
        var titel: String {
            switch self {
            case .zutaten: "Alle Zutaten"
            case .rezepte: "Nach Rezept"
            }
        }
    }

    /// Eine Zeile der Liste: gleiche Zutaten aus mehreren Rezepten werden in «Alle Zutaten» zusammengefasst
    private struct Zeile: Identifiable {
        let eintraege: [EinkaufsEintrag]
        var id: PersistentIdentifier { eintraege[0].persistentModelID }
        var name: String { eintraege[0].anzeigename }
        var erledigt: Bool { eintraege.allSatisfy(\.erledigt) }
        var mengen: String? {
            let liste = eintraege.compactMap(\.menge)
            return liste.isEmpty ? nil : liste.joined(separator: " + ")
        }
        var rezepte: String? {
            let namen = Array(Set(eintraege.compactMap(\.rezeptName))).sorted()
            return namen.isEmpty ? nil : namen.joined(separator: ", ")
        }
    }

    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(\.modelContext) private var kontext
    @Query(sort: \EinkaufsEintrag.hinzugefuegtAm) private var eintraege: [EinkaufsEintrag]
    @Query private var vorrat: [VorratsEintrag]
    @AppStorage("einkaufGruppierung") private var gruppierung = Gruppierung.zutaten
    @State private var zeigeHinzufuegen = false
    @State private var meldung: String?
    /// Gekaufte Rezeptzutaten ohne Zutat der Zutatenliste – werden im Fenster «Zutat zuordnen» behandelt
    @State private var zuordnen: [EinkaufsEintrag] = []

    private var offen: [EinkaufsEintrag] { eintraege.filter { !$0.erledigt } }
    private var erledigt: [EinkaufsEintrag] { eintraege.filter(\.erledigt) }

    var body: some View {
        NavigationStack {
            Group {
                if eintraege.isEmpty {
                    ContentUnavailableView {
                        Label("Einkaufsliste ist leer", systemImage: "cart")
                    } description: {
                        Text("Füge fehlende Zutaten in einem Rezept hinzu – oder tippe auf +.")
                    }
                } else {
                    liste
                }
            }
            .navigationTitle("Einkaufsliste")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Hinzufügen", systemImage: "plus") { zeigeHinzufuegen = true }
                }
                if !eintraege.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu("Mehr", systemImage: "ellipsis") {
                            ShareLink(item: teilText) {
                                Label("Liste teilen", systemImage: "square.and.arrow.up")
                            }
                            .disabled(offen.isEmpty)
                            Button("Erledigte entfernen", systemImage: "checkmark.circle") {
                                loeschen(erledigt)
                            }
                            .disabled(erledigt.isEmpty)
                            Button("Alles löschen", systemImage: "trash", role: .destructive) {
                                loeschen(eintraege)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $zeigeHinzufuegen) {
                EinkaufHinzufuegen()
            }
            .sheet(isPresented: Binding(get: { !zuordnen.isEmpty }, set: { if !$0 { zuordnen = [] } })) {
                ZutatZuordnen(eintraege: zuordnen.map(ZutatZuordnen.Angaben.init)) { zuordnen = [] }
            }
            .overlay(alignment: .bottom) {
                if let meldung {
                    Text(meldung)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: - Liste

    private var liste: some View {
        List {
            Section {
                Picker("Gruppierung", selection: $gruppierung) {
                    ForEach(Gruppierung.allCases) { Text($0.titel).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            switch gruppierung {
            case .zutaten:
                let offeneZeilen = zusammengefasst(offen)
                if !offeneZeilen.isEmpty {
                    Section(offeneZeilen.count == 1 ? "1 Zutat" : "\(offeneZeilen.count) Zutaten") {
                        zeilen(offeneZeilen, mitRezept: true)
                    }
                }
            case .rezepte:
                ForEach(nachRezept(offen), id: \.titel) { gruppe in
                    Section(gruppe.titel) {
                        zeilen(gruppe.eintraege.map { Zeile(eintraege: [$0]) }, mitRezept: false)
                    }
                }
            }

            if !erledigt.isEmpty {
                Section {
                    zeilen(gruppierung == .zutaten ? zusammengefasst(erledigt) : erledigt.map { Zeile(eintraege: [$0]) },
                           mitRezept: false)
                    Button {
                        inDenVorrat()
                    } label: {
                        Label("Gekaufte in den Vorrat (\(zusammengefasst(erledigt).count))", systemImage: "refrigerator")
                    }
                } header: {
                    Text("Im Wagen")
                } footer: {
                    Text("Zutaten der Zutatenliste kommen an ihren gewohnten Lagerort, Grundzutaten zu «Immer zuhause». Nicht erkannte Rezeptzutaten ordnest du selbst einer Zutat zu. Eigene Einträge werden nur von der Liste entfernt.")
                }
            }
        }
    }

    private func zeilen(_ zeilen: [Zeile], mitRezept: Bool) -> some View {
        ForEach(zeilen) { zeile in
            Button {
                withAnimation {
                    let neu = !zeile.erledigt
                    zeile.eintraege.forEach { $0.erledigt = neu }
                    try? kontext.save()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: zeile.erledigt ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(zeile.erledigt ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(zeile.name)
                                .strikethrough(zeile.erledigt)
                                .foregroundStyle(zeile.erledigt ? .secondary : .primary)
                            Spacer()
                            if let mengen = zeile.mengen {
                                Text(mengen)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        if mitRezept, let rezepte = zeile.rezepte {
                            Text(rezepte)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if zeile.eintraege[0].zutatName == nil && zeile.eintraege[0].rezeptID != nil {
                            Text("Nicht erkannt – beim Einkauf selbst zuordnen")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .swipeActions {
                Button("Löschen", systemImage: "trash", role: .destructive) {
                    loeschen(zeile.eintraege)
                }
            }
        }
    }

    /// Gleiche Zutat (deutscher Begriff bzw. Name) nur einmal, Mengen zusammengehängt
    private func zusammengefasst(_ liste: [EinkaufsEintrag]) -> [Zeile] {
        var reihenfolge: [String] = []
        var gruppen: [String: [EinkaufsEintrag]] = [:]
        for eintrag in liste {
            let schluessel = (eintrag.zutatName ?? eintrag.name).suchform
            if gruppen[schluessel] == nil { reihenfolge.append(schluessel) }
            gruppen[schluessel, default: []].append(eintrag)
        }
        return reihenfolge.map { Zeile(eintraege: gruppen[$0]!) }
    }

    private func nachRezept(_ liste: [EinkaufsEintrag]) -> [(titel: String, eintraege: [EinkaufsEintrag])] {
        var reihenfolge: [String] = []
        var gruppen: [String: [EinkaufsEintrag]] = [:]
        for eintrag in liste {
            let titel = eintrag.rezeptName ?? "Eigene Einträge"
            if gruppen[titel] == nil { reihenfolge.append(titel) }
            gruppen[titel, default: []].append(eintrag)
        }
        return reihenfolge.map { ($0, gruppen[$0]!) }
    }

    private var teilText: String {
        "Einkaufsliste\n" + zusammengefasst(offen).map { zeile in
            "– " + zeile.name + (zeile.mengen.map { " (\($0))" } ?? "")
        }.joined(separator: "\n")
    }

    // MARK: - Aktionen

    private func loeschen(_ liste: [EinkaufsEintrag]) {
        withAnimation {
            liste.forEach(kontext.delete)
            try? kontext.save()
        }
    }

    /// Gekaufte Zutaten in den Vorrat legen und von der Liste entfernen
    private func inDenVorrat() {
        let nachName = Dictionary(datenbank.zutaten.map { ($0.name, $0) }, uniquingKeysWith: { erste, _ in erste })
        let nachID = Dictionary(uniqueKeysWithValues: datenbank.zutaten.map { ($0.id, $0) })
        var vorhanden = Set(vorrat.map { "\($0.zutatID)-\($0.lagerort.rawValue)" })
        var anzahl = 0

        var unbekannt: [EinkaufsEintrag] = []

        for eintrag in erledigt {
            if let name = eintrag.zutatName,
               let zutat = nachName[name] ?? datenbank.alteNamen[name].flatMap({ nachID[$0] }) {
                let lagerort = zutat.istGrundzutat ? Lagerort.immerZuhause : EigeneLagerorte.vorschlag(fuer: zutat)
                let schluessel = "\(zutat.id)-\(lagerort.rawValue)"
                if !vorhanden.contains(schluessel) {
                    kontext.insert(VorratsEintrag(zutatID: zutat.id, name: zutat.name, lagerort: lagerort))
                    vorhanden.insert(schluessel)
                    anzahl += 1
                }
            } else if eintrag.rezeptID != nil {
                // Zutat aus einem Rezept, aber nicht in der Zutatenliste: im Fenster selbst zuordnen
                unbekannt.append(eintrag)
                continue
            }
            kontext.delete(eintrag)
        }
        try? kontext.save()
        zuordnen = unbekannt
        if anzahl == 0 && !unbekannt.isEmpty { return }

        let text = switch anzahl {
        case 0: "Nichts Neues für den Vorrat"
        case 1: "1 Zutat in den Vorrat gelegt"
        default: "\(anzahl) Zutaten in den Vorrat gelegt"
        }
        withAnimation { meldung = text }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { if meldung == text { meldung = nil } }
        }
    }
}

/// Fenster nach «Gekaufte in den Vorrat»: Rezeptzutaten, die nicht in der Zutatenliste stehen
/// (z. B. «Fertigfüllung»), ordnet man selbst einer Zutat der Liste zu und wählt den Lagerort.
/// Im Vorrat stehen weiterhin nur Zutaten der Zutatenliste (CLAUDE.md, Funktion 1).
private struct ZutatZuordnen: View {
    /// Kopie der Angaben – die Einträge selbst werden erst am Schluss gelöscht
    struct Angaben {
        let id: PersistentIdentifier
        let anzeigename: String
        let name: String
        let menge: String?
        let rezeptName: String?

        init(_ eintrag: EinkaufsEintrag) {
            id = eintrag.persistentModelID
            anzeigename = eintrag.anzeigename
            name = eintrag.name
            menge = eintrag.menge
            rezeptName = eintrag.rezeptName
        }
    }

    let eintraege: [Angaben]
    let fertig: () -> Void

    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(\.modelContext) private var kontext
    @State private var nummer = 0
    @State private var suchtext = ""
    @State private var gewaehlt: Zutat?
    @State private var lagerort = Lagerort.kuehlschrank
    @State private var erledigt: [PersistentIdentifier] = []

    private var eintrag: Angaben { eintraege[min(nummer, eintraege.count - 1)] }

    var body: some View {
        if eintraege.isEmpty {
            EmptyView()
        } else {
            inhalt
        }
    }

    private var inhalt: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .firstTextBaseline) {
                        Text(eintrag.anzeigename).font(.headline)
                        Spacer()
                        if let menge = eintrag.menge {
                            Text(menge).foregroundStyle(.secondary)
                        }
                    }
                    if let rezept = eintrag.rezeptName {
                        Text("aus «\(rezept)»").font(.caption).foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("Die App hat diese Zutat nicht erkannt. Wähle die passende Zutat aus der Zutatenliste, damit sie in den Vorrat kommt und bei den Rezepten zählt.")
                }

                if let gewaehlt {
                    Section("Zutat") {
                        HStack {
                            Text(gewaehlt.anzeigename)
                            Spacer()
                            Button("Ändern") { self.gewaehlt = nil }
                        }
                        Picker("Lagerort", selection: $lagerort) {
                            ForEach(Lagerort.allCases) { ort in
                                Label(ort.name, systemImage: ort.symbol).tag(ort)
                            }
                        }
                    }
                    Section {
                        Button("In den Vorrat legen", systemImage: "refrigerator") { inDenVorrat(gewaehlt) }
                            .fontWeight(.semibold)
                    }
                } else {
                    Section {
                        TextField("Zutat suchen", text: $suchtext)
                            .autocorrectionDisabled()
                    }
                    let treffer = datenbank.zutatenSuche.treffer(fuer: suchtext, hoechstens: 20)
                    if !treffer.isEmpty {
                        Section("Zutatenliste") {
                            ForEach(treffer) { zutat in
                                Button(zutat.anzeigename) { waehlen(zutat) }
                                    .foregroundStyle(.primary)
                            }
                        }
                    } else if !suchtext.trimmingCharacters(in: .whitespaces).isEmpty {
                        Section {
                            Text("Keine passende Zutat – versuche einen anderen Begriff (z. B. «Bouillon» statt «Brühe»).")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button("Nicht in den Vorrat, nur von der Liste entfernen") { weiter(entfernen: true) }
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(eintraege.count > 1 ? "Zuordnen (\(nummer + 1) von \(eintraege.count))" : "Zutat zuordnen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Später") { abschliessen() }
                }
            }
            .task(id: nummer) {
                // Suchfeld mit dem Namen vorbelegen; ein Treffer für ein einzelnes Wort genügt
                let kurz = eintrag.name.einkaufsKurzform
                let woerter = kurz.split(whereSeparator: { !$0.isLetter }).map(String.init).filter { $0.count >= 4 }
                suchtext = ([kurz] + woerter.reversed())
                    .first { !datenbank.zutatenSuche.treffer(fuer: $0, hoechstens: 1).isEmpty } ?? kurz
            }
        }
        .interactiveDismissDisabled()
    }

    private func waehlen(_ zutat: Zutat) {
        gewaehlt = zutat
        lagerort = zutat.istGrundzutat ? .immerZuhause : EigeneLagerorte.vorschlag(fuer: zutat)
    }

    private func inDenVorrat(_ zutat: Zutat) {
        let vorrat = (try? kontext.fetch(FetchDescriptor<VorratsEintrag>())) ?? []
        if !vorrat.contains(where: { $0.zutatID == zutat.id && $0.lagerort == lagerort }) {
            kontext.insert(VorratsEintrag(zutatID: zutat.id, name: zutat.name, lagerort: lagerort))
            EigeneLagerorte.merken(lagerort, fuer: zutat)
        }
        try? kontext.save()
        weiter(entfernen: true)
    }

    private func weiter(entfernen: Bool) {
        if entfernen { erledigt.append(eintrag.id) }
        if nummer + 1 < eintraege.count {
            nummer += 1
            gewaehlt = nil
        } else {
            abschliessen()
        }
    }

    /// Bearbeitete Einträge von der Liste löschen; übersprungene («Später») bleiben im Wagen
    private func abschliessen() {
        for id in erledigt {
            if let eintrag = kontext.model(for: id) as? EinkaufsEintrag { kontext.delete(eintrag) }
        }
        try? kontext.save()
        fertig()
    }
}

/// Eigenen Eintrag hinzufügen: Zutat aus der Zutatenliste oder freier Text
private struct EinkaufHinzufuegen: View {
    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(\.modelContext) private var kontext
    @Environment(\.dismiss) private var schliessen
    @State private var suchtext = ""

    var body: some View {
        let eingabe = suchtext.trimmingCharacters(in: .whitespaces)
        let treffer = datenbank.zutatenSuche.treffer(fuer: eingabe)

        NavigationStack {
            List {
                if !eingabe.isEmpty {
                    if !treffer.contains(where: { $0.name.suchform == eingabe.suchform }) {
                        Section {
                            Button("«\(eingabe)» als eigenen Eintrag hinzufügen", systemImage: "plus.circle") {
                                hinzufuegen(name: eingabe, zutatName: nil)
                            }
                        } footer: {
                            Text("Eigene Einträge kommen beim Einkaufen nicht in den Vorrat.")
                        }
                    }
                    if !treffer.isEmpty {
                        Section("Zutatenliste") {
                            ForEach(treffer) { zutat in
                                Button(zutat.anzeigename) {
                                    hinzufuegen(name: zutat.name, zutatName: zutat.name)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                }
            }
            .overlay {
                if eingabe.isEmpty {
                    ContentUnavailableView("Was brauchst du?", systemImage: "cart.badge.plus",
                                           description: Text("Suche eine Zutat oder schreibe einen eigenen Eintrag."))
                }
            }
            .searchable(text: $suchtext, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zutat suchen")
            .navigationTitle("Hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
        }
    }

    private func hinzufuegen(name: String, zutatName: String?) {
        kontext.insert(EinkaufsEintrag(name: name, zutatName: zutatName))
        try? kontext.save()
        schliessen()
    }
}
