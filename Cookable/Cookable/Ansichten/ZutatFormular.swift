import SwiftData
import SwiftUI

/// Formular zum Hinzufügen oder Bearbeiten einer Zutat im Vorrat.
struct ZutatFormular: View {
    enum Modus {
        case neu(lagerort: Lagerort? = nil)
        case bearbeiten(VorratsEintrag)
    }

    let modus: Modus

    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @Environment(RezeptDatenbank.self) private var datenbank
    @Query private var vorrat: [VorratsEintrag]
    @AppStorage("letzterLagerort") private var letzterLagerort = Lagerort.kuehlschrank

    @State private var suchtext = ""
    @State private var zutat: Zutat?
    @State private var lagerort = Lagerort.kuehlschrank
    @State private var mitAblaufdatum = false
    @State private var ablaufdatum = Calendar.current.date(byAdding: .day, value: 7, to: .now) ?? .now
    @FocusState private var sucheAktiv: Bool

    private var bearbeiteterEintrag: VorratsEintrag? {
        if case .bearbeiten(let eintrag) = modus { eintrag } else { nil }
    }

    /// Gibt es diese Zutat am gewählten Lagerort schon (ausser dem bearbeiteten Eintrag)?
    private var doppelt: Bool {
        guard let zutat else { return false }
        return vorrat.contains { $0.zutatID == zutat.id && $0.lagerort == lagerort && $0 !== bearbeiteterEintrag }
    }

    var body: some View {
        NavigationStack {
            Form {
                zutatAbschnitt
                if zutat != nil {
                    lagerortAbschnitt
                    if lagerort.hatAblaufdatum {
                        ablaufdatumAbschnitt
                    }
                }
                if let eintrag = bearbeiteterEintrag {
                    Section {
                        Button("Aus dem Vorrat entfernen", role: .destructive) {
                            kontext.delete(eintrag)
                            schliessen()
                        }
                    }
                }
            }
            .navigationTitle(bearbeiteterEintrag == nil ? "Zutat hinzufügen" : "Zutat bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(bearbeiteterEintrag == nil ? "Hinzufügen" : "Sichern") { sichern() }
                        .disabled(zutat == nil || doppelt)
                }
            }
            .onAppear(perform: vorbereiten)
        }
    }

    // MARK: - Abschnitte

    @ViewBuilder
    private var zutatAbschnitt: some View {
        Section("Zutat") {
            if let zutat {
                HStack {
                    Text(zutat.anzeigename)
                    Spacer()
                    if bearbeiteterEintrag == nil {
                        Button("Ändern") {
                            self.zutat = nil
                            sucheAktiv = true
                        }
                    }
                }
            } else {
                TextField("Zutat suchen", text: $suchtext)
                    .focused($sucheAktiv)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                trefferliste
            }
        }
    }

    @ViewBuilder
    private var trefferliste: some View {
        let treffer = datenbank.zutatenSuche.treffer(fuer: suchtext)
        if !suchtext.trimmingCharacters(in: .whitespaces).isEmpty && treffer.isEmpty {
            Text("Keine passende Zutat gefunden")
                .foregroundStyle(.secondary)
        }
        ForEach(treffer) { treffer in
            Button {
                waehlen(treffer)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(treffer.anzeigename)
                    if let hinweis = hinweis(zu: treffer) {
                        Text(hinweis)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var lagerortAbschnitt: some View {
        Section {
            Picker("Lagerort", selection: $lagerort) {
                ForEach(Lagerort.allCases) { ort in
                    Label(ort.name, systemImage: ort.symbol).tag(ort)
                }
            }
            if doppelt, let zutat {
                Label("\(zutat.anzeigename) ist bereits in «\(lagerort.name)».", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.red)
            }
        } footer: {
            if lagerort == .immerZuhause {
                Text("Zutaten in «Immer zuhause» zählen bei den Rezepten immer als vorhanden.")
            }
        }
    }

    private var ablaufdatumAbschnitt: some View {
        Section {
            Toggle("Ablaufdatum", isOn: $mitAblaufdatum.animation())
            if mitAblaufdatum {
                DatePicker("Läuft ab am", selection: $ablaufdatum, displayedComponents: .date)
            }
        }
    }

    // MARK: - Aktionen

    private func vorbereiten() {
        switch modus {
        case .neu(let vorgabe):
            lagerort = vorgabe ?? letzterLagerort
            sucheAktiv = true
        case .bearbeiten(let eintrag):
            zutat = datenbank.zutaten.first { $0.id == eintrag.zutatID }
            lagerort = eintrag.lagerort
            if let datum = eintrag.ablaufdatum {
                mitAblaufdatum = true
                ablaufdatum = datum
            }
        }
    }

    private func waehlen(_ gewaehlt: Zutat) {
        zutat = gewaehlt
        suchtext = ""
        sucheAktiv = false
    }

    private func hinweis(zu zutat: Zutat) -> String? {
        let orte = vorrat.filter { $0.zutatID == zutat.id }.map(\.lagerort.name)
        if !orte.isEmpty {
            return "Bereits im Vorrat: " + orte.joined(separator: ", ")
        }
        return zutat.istGrundzutat ? "Grundzutat" : nil
    }

    private func sichern() {
        guard let zutat, !doppelt else { return }
        let datum = lagerort.hatAblaufdatum && mitAblaufdatum ? ablaufdatum : nil
        if let eintrag = bearbeiteterEintrag {
            eintrag.lagerort = lagerort
            eintrag.ablaufdatum = datum
        } else {
            kontext.insert(VorratsEintrag(zutatID: zutat.id, name: zutat.name, lagerort: lagerort, ablaufdatum: datum))
            if lagerort != .immerZuhause {
                letzterLagerort = lagerort
            }
        }
        schliessen()
    }
}
