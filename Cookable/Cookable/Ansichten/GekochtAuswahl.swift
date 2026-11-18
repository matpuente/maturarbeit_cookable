import SwiftData
import SwiftUI

/// Fenster nach «Gekocht»: Man hakt an, welche Zutaten aus dem Vorrat aufgebraucht sind (nichts vorausgewählt,
/// weil oft ein Rest bleibt). «Immer zuhause» erscheint nicht.
struct GekochtAuswahl: View {
    /// Eine Zutat aus dem Vorrat, die das Rezept verwendet
    struct Zeile: Identifiable {
        let eintrag: VorratsEintrag
        /// z. B. "Ersatz für Nudeln" oder "Eigene Zutat"
        let hinweis: String?
        var id: PersistentIdentifier { eintrag.persistentModelID }
    }

    let zeilen: [Zeile]
    /// Wird mit den gewählten Einträgen aufgerufen
    let entfernen: ([VorratsEintrag]) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var gewaehlt: Set<PersistentIdentifier> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(zeilen) { zeile in
                        Button {
                            if gewaehlt.contains(zeile.id) { gewaehlt.remove(zeile.id) } else { gewaehlt.insert(zeile.id) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: gewaehlt.contains(zeile.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3)
                                    .foregroundStyle(gewaehlt.contains(zeile.id) ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(zeile.eintrag.anzeigename)
                                    Text(details(zu: zeile))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let status = zeile.eintrag.ablaufStatus() {
                                        Label(status.text.mitGrossemAnfang, systemImage: status.symbol)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(status.farbe)
                                    }
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    HStack {
                        Text("Aus deinem Vorrat")
                        Spacer()
                        Button(gewaehlt.count == zeilen.count ? "Keine" : "Alle auswählen") {
                            gewaehlt = gewaehlt.count == zeilen.count ? [] : Set(zeilen.map(\.id))
                        }
                        .font(.subheadline)
                        .textCase(nil)
                    }
                } footer: {
                    Text("Hake an, was aufgebraucht ist – Zutaten mit einem Rest bleiben im Vorrat. «Immer zuhause» wird nie entfernt.")
                }
            }
            .navigationTitle("Was hast du aufgebraucht?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    entfernen(zeilen.filter { gewaehlt.contains($0.id) }.map(\.eintrag))
                    schliessen()
                } label: {
                    Text(gewaehlt.isEmpty ? "Nichts aufgebraucht" : "Aus dem Vorrat entfernen (\(gewaehlt.count))")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(gewaehlt.isEmpty)
                .padding()
            }
        }
    }

    private func details(zu zeile: Zeile) -> String {
        ([zeile.eintrag.lagerort.name] + [zeile.hinweis].compactMap { $0 }).joined(separator: " · ")
    }
}

extension GekochtAuswahl {
    /// Vorratseinträge, die das Rezept verwendet: genau vorhanden, als Ersatz (gleiche Austauschgruppe)
    /// oder als eigene Zutat (gleicher englischer Grundname). Ohne «Immer zuhause».
    static func zeilen(fuer zutatenzeilen: [ZutatenZeile], vorrat: [VorratsEintrag],
                       austauschgruppe: [Int: Int], zutatName: (Int) -> String?) -> [Zeile] {
        let kandidaten = vorrat.filter { $0.lagerort != .immerZuhause }
        var ergebnis: [Zeile] = []
        var gesehen = Set<PersistentIdentifier>()
        func hinzufuegen(_ eintrag: VorratsEintrag, _ hinweis: String?) {
            if gesehen.insert(eintrag.persistentModelID).inserted { ergebnis.append(Zeile(eintrag: eintrag, hinweis: hinweis)) }
        }
        for zeile in zutatenzeilen {
            for zutatID in zeile.zutatIDs {
                let genau = kandidaten.filter { $0.zutatID == zutatID }
                if !genau.isEmpty {
                    genau.forEach { hinzufuegen($0, nil) }
                } else if let gruppe = austauschgruppe[zutatID] {
                    let name = zutatName(zutatID).map { "Ersatz für \($0.mitGrossemAnfang)" }
                    kandidaten.filter { austauschgruppe[$0.zutatID] == gruppe }.forEach { hinzufuegen($0, name) }
                }
            }
            for grundname in zeile.ohneListe {
                kandidaten.filter { $0.grundname == grundname }.forEach { hinzufuegen($0, "Eigene Zutat") }
            }
        }
        return ergebnis
    }
}
