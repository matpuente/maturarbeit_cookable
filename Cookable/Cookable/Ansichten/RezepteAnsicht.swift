import SwiftData
import SwiftUI

/// Rezeptvorschläge passend zum Vorrat, mit Filtern für Zeit und Kategorie.
struct RezepteAnsicht: View {
    @Environment(RezeptDatenbank.self) private var datenbank
    @Query private var vorrat: [VorratsEintrag]

    @AppStorage("filterZeit") private var zeit = Zeitfilter.alle
    @AppStorage("filterKategorie") private var kategorieWert = ""
    @State private var auswahl: RezeptUebersicht.ID?
    /// Zutaten, die jedes Rezept enthalten muss (Filter «Muss enthalten»)
    @State private var mussEnthalten: Set<Int> = []
    @State private var zeigeZutatenauswahl = false

    private var kategorie: Kategorie? { Kategorie(rawValue: kategorieWert) }

    /// Gewählte Zutaten, die noch im Vorrat sind
    private var aktiveMussZutaten: Set<Int> {
        mussEnthalten.intersection(vorrat.map(\.zutatID))
    }

    var body: some View {
        let vorschlaege = RezeptVorschlaege.berechnen(
            rezepte: datenbank.rezepte,
            vorrat: Set(vorrat.map(\.zutatID)),
            kategorie: kategorie,
            zeit: zeit,
            mussEnthalten: aktiveMussZutaten
        )
        NavigationSplitView {
            List(selection: $auswahl) {
                Section {
                    filter
                }
                if vorschlaege.isEmpty {
                    leererZustand
                } else {
                    Section {
                        ForEach(vorschlaege) { vorschlag in
                            NavigationLink(value: vorschlag.id) {
                                RezeptZeile(vorschlag: vorschlag)
                            }
                        }
                    } header: {
                        Text("\(vorschlaege.count) Rezepte")
                    }
                }
            }
            .navigationTitle("Rezepte")
            .sheet(isPresented: $zeigeZutatenauswahl) {
                MussEnthaltenAuswahl(vorrat: vorrat, auswahl: $mussEnthalten)
            }
        } detail: {
            if let auswahl, let vorschlag = vorschlaege.first(where: { $0.id == auswahl }) {
                RezeptDetailAnsicht(vorschlag: vorschlag)
            } else {
                ContentUnavailableView("Kein Rezept ausgewählt", systemImage: "fork.knife")
            }
        }
    }

    // MARK: - Filter

    private var filter: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Zubereitungszeit", selection: $zeit) {
                ForEach(Zeitfilter.allCases) { filter in
                    Text(filter.titel).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    kategorieKnopf("Alle", wert: "")
                    ForEach(Kategorie.allCases) { kategorie in
                        kategorieKnopf(kategorie.rawValue, wert: kategorie.rawValue)
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("Muss enthalten", systemImage: "checklist") { zeigeZutatenauswahl = true }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(aktiveMussZutaten.isEmpty ? .secondary : .accentColor)
                    ForEach(mussZutatenSortiert, id: \.id) { zutat in
                        Button {
                            mussEnthalten.remove(zutat.id)
                        } label: {
                            Label(zutat.anzeigename, systemImage: "xmark")
                                .labelStyle(TitelZuerstStil())
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .accessibilityHint("Entfernt die Zutat aus dem Filter")
                    }
                }
            }
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }

    private var mussZutatenSortiert: [Zutat] {
        datenbank.zutaten.filter { aktiveMussZutaten.contains($0.id) }
    }

    private func kategorieKnopf(_ titel: String, wert: String) -> some View {
        let gewaehlt = kategorieWert == wert
        return Button(titel) { kategorieWert = wert }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .tint(gewaehlt ? .accentColor : .secondary)
            .fontWeight(gewaehlt ? .semibold : .regular)
    }

    // MARK: - Leerer Zustand

    @ViewBuilder
    private var leererZustand: some View {
        let hatZutaten = vorrat.contains { eintrag in
            datenbank.zutaten.first { $0.id == eintrag.zutatID }?.istGrundzutat == false
        }
        Section {
            if hatZutaten {
                ContentUnavailableView(
                    "Keine passenden Rezepte",
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text("Für diesen Filter gibt es keine Rezepte mit deinen Zutaten.")
                )
            } else {
                ContentUnavailableView(
                    "Noch keine Vorschläge",
                    systemImage: "refrigerator",
                    description: Text("Füge Zutaten zum Vorrat hinzu, um passende Rezepte zu sehen.")
                )
            }
        }
    }
}

/// Eine Zeile der Vorschlagsliste.
struct RezeptZeile: View {
    let vorschlag: RezeptVorschlag

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vorschlag.rezept.name)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: 8) {
                ProgressView(value: vorschlag.anteil)
                    .frame(width: 60)
                    .tint(vorschlag.fehlend == 0 ? .green : .accentColor)
                Text("\(vorschlag.vorhanden) von \(vorschlag.benoetigt) Zutaten vorhanden")
                    .font(.subheadline)
            }
            Label {
                Text("\(vorschlag.rezept.zeitText) · \(vorschlag.rezept.kategorie.rawValue)")
            } icon: {
                Image(systemName: "clock")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Zeigt den Text vor dem Symbol ("Poulet ×").
private struct TitelZuerstStil: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon.imageScale(.small)
        }
    }
}

/// Auswahl der Zutaten aus dem Vorrat für den Filter «Muss enthalten», nach Lagerort gruppiert und durchsuchbar.
struct MussEnthaltenAuswahl: View {
    let vorrat: [VorratsEintrag]
    @Binding var auswahl: Set<Int>
    @Environment(\.dismiss) private var schliessen
    @State private var suchtext = ""

    /// Zum Aufbrauchen sind meist Kühlschrank und Tiefkühler gefragt, darum «Immer zuhause» zuletzt
    private static let reihenfolge: [Lagerort] = [.kuehlschrank, .tiefkuehler, .vorratsschrank, .immerZuhause]

    private func eintraege(in ort: Lagerort) -> [VorratsEintrag] {
        let gesucht = suchtext.trimmingCharacters(in: .whitespaces).suchform
        return vorrat
            .filter { $0.lagerort == ort && (gesucht.isEmpty || $0.name.suchform.contains(gesucht)) }
            .sorted { $0.anzeigename.localizedStandardCompare($1.anzeigename) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Self.reihenfolge) { ort in
                    let liste = eintraege(in: ort)
                    if !liste.isEmpty {
                        Section {
                            ForEach(liste) { eintrag in
                                zeile(eintrag)
                            }
                        } header: {
                            Label(ort.name, systemImage: ort.symbol)
                        }
                    }
                }
                if Self.reihenfolge.allSatisfy({ eintraege(in: $0).isEmpty }) {
                    ContentUnavailableView.search(text: suchtext)
                } else if suchtext.isEmpty {
                    Section {
                    } footer: {
                        Text("Es erscheinen nur Rezepte, die alle gewählten Zutaten enthalten. Der übrige Vorrat zählt weiterhin.")
                    }
                }
            }
            .searchable(text: $suchtext, placement: .navigationBarDrawer(displayMode: .always), prompt: "Zutat suchen")
            .autocorrectionDisabled()
            .navigationTitle(auswahl.isEmpty ? "Muss enthalten" : "Muss enthalten (\(auswahl.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zurücksetzen") { auswahl.removeAll() }
                        .disabled(auswahl.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
        }
    }

    /// Steht eine Zutat an mehreren Lagerorten, ist sie überall gleichzeitig angehakt.
    private func zeile(_ eintrag: VorratsEintrag) -> some View {
        let gewaehlt = auswahl.contains(eintrag.zutatID)
        return Button {
            if gewaehlt {
                auswahl.remove(eintrag.zutatID)
            } else {
                auswahl.insert(eintrag.zutatID)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.anzeigename)
                    if let datum = eintrag.ablaufdatum {
                        Text("Läuft ab am \(datum.formatted(date: .numeric, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if gewaehlt {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
            .contentShape(.rect)
        }
        .foregroundStyle(.primary)
    }
}
