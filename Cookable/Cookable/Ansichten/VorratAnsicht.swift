import SwiftData
import SwiftUI

/// Vorrat: Bereich «Immer zuhause» und Zutaten nach Lagerort gruppiert.
struct VorratAnsicht: View {
    @Environment(\.modelContext) private var kontext
    @Environment(RezeptDatenbank.self) private var datenbank
    @Query(sort: \VorratsEintrag.name) private var eintraege: [VorratsEintrag]
    @AppStorage("grundzutatenAngelegt") private var grundzutatenAngelegt = false

    @State private var neuerEintrag: ZutatFormular.Modus?
    @State private var bearbeiteterEintrag: VorratsEintrag?
    @State private var immerZuhauseOffen = false

    private static let lagerorte: [Lagerort] = [.kuehlschrank, .tiefkuehler, .vorratsschrank]

    private func eintraege(in ort: Lagerort) -> [VorratsEintrag] {
        eintraege.filter { $0.lagerort == ort }
    }

    var body: some View {
        NavigationStack {
            List {
                immerZuhauseAbschnitt
                ForEach(Self.lagerorte) { ort in
                    let liste = eintraege(in: ort)
                    if !liste.isEmpty {
                        Section {
                            zeilen(liste)
                        } header: {
                            Label(ort.name, systemImage: ort.symbol)
                        }
                    }
                }
                if Self.lagerorte.allSatisfy({ eintraege(in: $0).isEmpty }) {
                    Section {
                        ContentUnavailableView {
                            Label("Noch keine Zutaten", systemImage: "refrigerator")
                        } description: {
                            Text("Erfasse, was in Kühlschrank, Tiefkühler und Vorratsschrank ist.")
                        } actions: {
                            Button("Zutat hinzufügen") { neuerEintrag = .neu() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
            .navigationTitle("Vorrat")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Zutat hinzufügen", systemImage: "plus") { neuerEintrag = .neu() }
                }
            }
            .sheet(item: $neuerEintrag) { modus in
                ZutatFormular(modus: modus)
            }
            .sheet(item: $bearbeiteterEintrag) { eintrag in
                ZutatFormular(modus: .bearbeiten(eintrag))
            }
            .task(grundzutatenAnlegen)
        }
    }

    // MARK: - Immer zuhause

    private var immerZuhauseAbschnitt: some View {
        let liste = eintraege(in: .immerZuhause)
        // Eigene Auf-/Zuklapp-Zeile statt DisclosureGroup. Nach den löschbaren Zeilen darf im selben
        // Abschnitt keine weitere Zeile folgen, sonst stellt die Liste nach dem Löschen Zeilen falsch dar.
        return Section {
            HStack(spacing: 16) {
                Button {
                    withAnimation { immerZuhauseOffen.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(Lagerort.immerZuhause.name)
                            } icon: {
                                Image(systemName: Lagerort.immerZuhause.symbol).foregroundStyle(.tint)
                            }
                            .font(.headline)
                            Text(liste.isEmpty ? "Keine Einträge" : liste.map(\.anzeigename).joined(separator: ", "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(immerZuhauseOffen ? 1 : 2)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.tertiary)
                            .rotationEffect(.degrees(immerZuhauseOffen ? 90 : 0))
                    }
                    .contentShape(.rect)
                }
                .foregroundStyle(.primary)
                Button("Zu «Immer zuhause» hinzufügen", systemImage: "plus.circle.fill") {
                    neuerEintrag = .neu(lagerort: .immerZuhause)
                }
                .labelStyle(.iconOnly)
                .font(.title2)
            }
            .buttonStyle(.borderless)
            if immerZuhauseOffen {
                zeilen(liste)
            }
        } footer: {
            Text("Zählt bei den Rezepten immer als vorhanden. Lösche, was du nicht hast, und ergänze, was du immer hast.")
        }
    }

    // MARK: - Zeilen

    private func zeilen(_ liste: [VorratsEintrag]) -> some View {
        ForEach(liste) { eintrag in
            Button {
                bearbeiteterEintrag = eintrag
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(eintrag.anzeigename)
                    if let datum = eintrag.ablaufdatum {
                        Text("Läuft ab am \(datum.formatted(date: .numeric, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .foregroundStyle(.primary)
        }
        .onDelete { indizes in
            for index in indizes {
                kontext.delete(liste[index])
            }
        }
    }

    /// Beim ersten Start die Grundzutaten in «Immer zuhause» eintragen.
    private func grundzutatenAnlegen() async {
        guard !grundzutatenAngelegt else { return }
        for zutat in datenbank.grundzutaten {
            kontext.insert(VorratsEintrag(zutatID: zutat.id, name: zutat.name, lagerort: .immerZuhause))
        }
        grundzutatenAngelegt = true
    }
}

extension ZutatFormular.Modus: Identifiable {
    var id: String {
        switch self {
        case .neu(let lagerort): "neu-\(lagerort?.rawValue ?? "")"
        case .bearbeiten(let eintrag): "bearbeiten-\(eintrag.persistentModelID.hashValue)"
        }
    }
}
