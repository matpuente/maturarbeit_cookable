import SwiftData
import SwiftUI

/// Vorrat: Bereich «Immer zuhause» und Zutaten nach Lagerort gruppiert.
struct VorratAnsicht: View {
    @Environment(\.modelContext) private var kontext
    @Environment(RezeptDatenbank.self) private var datenbank
    @Query(sort: \VorratsEintrag.name) private var eintraege: [VorratsEintrag]

    @State private var neuerEintrag: ZutatFormular.Modus?
    @State private var bearbeiteterEintrag: VorratsEintrag?
    @State private var immerZuhauseOffen = false
    /// «Bearbeiten»: rote Minus-Knöpfe, die eine Zutat mit einem Tipp löschen (ohne zweite Bestätigung)
    @State private var loeschModus = false

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
                    Button(loeschModus ? "Fertig" : "Bearbeiten") {
                        withAnimation { loeschModus.toggle() }
                    }
                    .fontWeight(loeschModus ? .semibold : .regular)
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
        }
    }

    // MARK: - Immer zuhause

    private var immerZuhauseAbschnitt: some View {
        let liste = eintraege(in: .immerZuhause)
        // Eigene Auf-/Zuklapp-Zeile statt DisclosureGroup; «Hinzufügen» als ⊕ in der Kopfzeile.
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
            HStack(spacing: 12) {
                if loeschModus {
                    Button("\(eintrag.anzeigename) löschen", systemImage: "minus.circle.fill") {
                        withAnimation { loeschen([eintrag]) }
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .foregroundStyle(.red)
                    .buttonStyle(.borderless)
                    .transition(.move(edge: .leading).combined(with: .opacity))
                }
                Button {
                    bearbeiteterEintrag = eintrag
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(eintrag.anzeigename)
                        if let datum = eintrag.ablaufdatum {
                            let datumText = datum.formatted(date: .numeric, time: .omitted)
                            if let status = eintrag.ablaufStatus() {
                                Label("\(status.text.mitGrossemAnfang) (\(datumText))", systemImage: status.symbol)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(status.farbe)
                            } else {
                                Text("Läuft ab am \(datumText)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .foregroundStyle(.primary)
                .buttonStyle(.borderless)
                .disabled(loeschModus)
            }
        }
        .onDelete { indizes in
            loeschen(indizes.map { liste[$0] })
        }
    }

    private func loeschen(_ zuLoeschen: [VorratsEintrag]) {
        for eintrag in zuLoeschen {
            kontext.delete(eintrag)
        }
        // Sofort speichern: Sonst meldet @Query das Löschen verzögert und die Liste zeigt kurz falsche Zeilen
        try? kontext.save()
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

extension AblaufStatus {
    /// Orange ab 3 Tagen vor Ablauf, rot wenn abgelaufen (CLAUDE.md, Funktion 7)
    var farbe: Color {
        switch self {
        case .bald: .orange
        case .abgelaufen: .red
        }
    }

    var symbol: String {
        switch self {
        case .bald: "clock.badge.exclamationmark"
        case .abgelaufen: "exclamationmark.triangle.fill"
        }
    }
}
