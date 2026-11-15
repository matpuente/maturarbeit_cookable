import SwiftData
import SwiftUI

/// Gemerkte Lieblingsrezepte (CLAUDE.md, Funktion 8).
struct FavoritenAnsicht: View {
    enum Sortierung: String, CaseIterable, Identifiable {
        case passt, zuletzt

        var id: Self { self }
        var titel: String {
            switch self {
            case .passt: "Passt am besten"
            case .zuletzt: "Zuletzt hinzugefügt"
            }
        }
    }

    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(Uebersetzer.self) private var uebersetzer
    @Environment(\.modelContext) private var kontext
    @Query private var favoriten: [Favorit]
    @Query private var vorrat: [VorratsEintrag]
    @Query private var uebersetzungen: [Uebersetzung]
    @AppStorage("favoritenSortierung") private var sortierung = Sortierung.passt
    @State private var auswahl: RezeptUebersicht.ID?

    /// Favoriten mit Abgleich gegen den Vorrat, in der gewählten Reihenfolge
    private var vorschlaege: [RezeptVorschlag] {
        let vorratIDs = Set(vorrat.map(\.zutatID))
        let eigene = Set(vorrat.compactMap(\.grundname))
        let datum = Dictionary(favoriten.map { ($0.rezeptID, $0.hinzugefuegtAm) }, uniquingKeysWith: { erstes, _ in erstes })
        let liste = favoriten.compactMap { favorit in
            datenbank.rezeptNachID[favorit.rezeptID].map {
                RezeptVorschlaege.einzeln($0, vorrat: vorratIDs, austauschgruppe: datenbank.austauschgruppe, eigene: eigene)
            }
        }
        switch sortierung {
        case .passt:
            return liste.sorted { a, b in
                if a.anteil != b.anteil { return a.anteil > b.anteil }
                if a.ersatz != b.ersatz { return a.ersatz < b.ersatz }
                return a.fehlend < b.fehlend
            }
        case .zuletzt:
            return liste.sorted { (datum[$0.id] ?? .distantPast) > (datum[$1.id] ?? .distantPast) }
        }
    }

    var body: some View {
        let namen = Dictionary(uebersetzungen.map { ($0.rezeptID, $0.name) }, uniquingKeysWith: { erster, _ in erster })
        let vorschlaege = vorschlaege

        NavigationSplitView {
            Group {
                if vorschlaege.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Favoriten", systemImage: "heart")
                    } description: {
                        Text("Tippe in einem Rezept auf das Herz – oder drücke lange auf ein Rezept in der Liste.")
                    }
                } else {
                    List(selection: $auswahl) {
                        Section {
                            Picker("Sortierung", selection: $sortierung) {
                                ForEach(Sortierung.allCases) { Text($0.titel).tag($0) }
                            }
                            .pickerStyle(.segmented)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        Section {
                            ForEach(vorschlaege) { vorschlag in
                                NavigationLink(value: vorschlag.id) {
                                    RezeptZeile(vorschlag: vorschlag, name: namen[vorschlag.id] ?? vorschlag.rezept.name)
                                }
                                .onAppear {
                                    if namen[vorschlag.id] == nil {
                                        uebersetzer.nameAnfordern(rezeptID: vorschlag.id, englisch: vorschlag.rezept.name)
                                    }
                                }
                                .swipeActions {
                                    Button("Entfernen", systemImage: "heart.slash", role: .destructive) {
                                        withAnimation { kontext.favoritUmschalten(vorschlag.id) }
                                    }
                                }
                            }
                        } header: {
                            Text(vorschlaege.count == 1 ? "1 Favorit" : "\(vorschlaege.count) Favoriten")
                        }
                    }
                }
            }
            .navigationTitle("Favoriten")
        } detail: {
            if let auswahl, let vorschlag = vorschlaege.first(where: { $0.id == auswahl })
                ?? datenbank.rezeptNachID[auswahl].map({
                    RezeptVorschlaege.einzeln($0, vorrat: Set(vorrat.map(\.zutatID)), austauschgruppe: datenbank.austauschgruppe,
                                              eigene: Set(vorrat.compactMap(\.grundname)))
                }) {
                RezeptDetailAnsicht(vorschlag: vorschlag)
                    .id(vorschlag.id)
            } else {
                ContentUnavailableView("Kein Rezept ausgewählt", systemImage: "heart")
            }
        }
    }
}
