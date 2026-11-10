import SwiftData
import SwiftUI

/// Rezeptvorschläge passend zum Vorrat, mit Filtern für Zeit und Kategorie.
struct RezepteAnsicht: View {
    @Environment(RezeptDatenbank.self) private var datenbank
    @Query private var vorrat: [VorratsEintrag]

    @AppStorage("filterZeit") private var zeit = Zeitfilter.alle
    @AppStorage("filterKategorie") private var kategorieWert = ""
    @State private var auswahl: RezeptUebersicht.ID?

    private var kategorie: Kategorie? { Kategorie(rawValue: kategorieWert) }

    var body: some View {
        let vorschlaege = RezeptVorschlaege.berechnen(
            rezepte: datenbank.rezepte,
            vorrat: Set(vorrat.map(\.zutatID)),
            kategorie: kategorie,
            zeit: zeit
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
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
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
