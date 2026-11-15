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
                        Label("Gekaufte in den Vorrat (\(erledigt.count))", systemImage: "refrigerator")
                    }
                } header: {
                    Text("Im Wagen")
                } footer: {
                    Text("Zutaten der Zutatenliste kommen an ihren gewohnten Lagerort, Grundzutaten zu «Immer zuhause». Andere Einträge werden nur von der Liste entfernt.")
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
            }
            kontext.delete(eintrag)
        }
        try? kontext.save()

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
