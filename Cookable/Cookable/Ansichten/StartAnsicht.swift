import SwiftData
import SwiftUI

/// Startseite: Begrüssung, bald ablaufende Zutaten mit Rezepten zum Aufbrauchen und Vorschläge als Foto-Karten.
struct StartAnsicht: View {
    /// Wechselt zum Tab «Rezepte» bzw. «Vorrat»
    let zeigeRezepte: () -> Void
    let zeigeVorrat: () -> Void

    @Environment(RezeptDatenbank.self) private var datenbank
    @Environment(Uebersetzer.self) private var uebersetzer
    @Environment(\.horizontalSizeClass) private var breite
    @Query private var vorrat: [VorratsEintrag]
    @Query private var uebersetzungen: [Uebersetzung]
    @Query private var favoriten: [Favorit]
    private var favoritIDs: Set<Int> { Set(favoriten.map(\.rezeptID)) }

    private static let anzahlKarten = 10

    /// Zutaten aus Kühlschrank, Tiefkühler und Vorratsschrank (ohne «Immer zuhause»)
    private var erfasst: [VorratsEintrag] { vorrat.filter { $0.lagerort != .immerZuhause } }

    /// Bald ablaufende und abgelaufene Zutaten, die dringendsten zuerst
    private var baldAblaufend: [(eintrag: VorratsEintrag, status: AblaufStatus)] {
        erfasst
            .compactMap { eintrag in eintrag.ablaufStatus().map { (eintrag, $0) } }
            .sorted { ($0.eintrag.ablaufdatum ?? .distantFuture) < ($1.eintrag.ablaufdatum ?? .distantFuture) }
    }

    var body: some View {
        let namen = Dictionary(uebersetzungen.map { ($0.rezeptID, $0.name) }, uniquingKeysWith: { erster, _ in erster })
        let vorschlaege = RezeptVorschlaege.berechnen(
            rezepte: datenbank.rezepte,
            vorrat: Set(vorrat.map(\.zutatID)),
            austauschgruppe: datenbank.austauschgruppe,
            kategorie: nil,
            zeit: .alle
        )
        let ablaufend = baldAblaufend
        let (aufbrauchen, passt, schnell) = reihen(vorschlaege, ablaufend: Set(ablaufend.map(\.eintrag.zutatID)))
        let lieblinge = favoritenVorschlaege
        let alleAngezeigt = Dictionary(
            (aufbrauchen + passt + schnell + lieblinge).map { ($0.id, $0) },
            uniquingKeysWith: { erster, _ in erster }
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    kopf(anzahlAblaufend: ablaufend.count)

                    if erfasst.isEmpty {
                        leererVorrat
                    } else {
                        if !ablaufend.isEmpty {
                            ablaufAbschnitt(ablaufend)
                            if !aufbrauchen.isEmpty {
                                kartenReihe("Rezepte zum Aufbrauchen", symbol: "leaf", aufbrauchen, namen: namen)
                            }
                        }
                        if !passt.isEmpty {
                            kartenReihe("Passt zu deinem Vorrat", symbol: "refrigerator", passt, namen: namen)
                        }
                        if !lieblinge.isEmpty {
                            kartenReihe("Deine Favoriten", symbol: "heart", lieblinge, namen: namen)
                        }
                        if !schnell.isEmpty {
                            kartenReihe("Schnell gemacht", symbol: "timer", schnell, namen: namen)
                        }
                        Button(action: zeigeRezepte) {
                            Label("Alle \(vorschlaege.count) Vorschläge anzeigen", systemImage: "list.bullet")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Cookable")
            .navigationDestination(for: RezeptVorschlag.ID.self) { id in
                if let vorschlag = alleAngezeigt[id] {
                    RezeptDetailAnsicht(vorschlag: vorschlag)
                }
            }
        }
    }

    // MARK: - Kopf

    private func kopf(anzahlAblaufend: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(begruessung)
                .font(.title2.bold())
            Group {
                if anzahlAblaufend > 0 {
                    let warnung = Text(anzahlAblaufend == 1 ? "1 läuft bald ab" : "\(anzahlAblaufend) laufen bald ab")
                        .foregroundStyle(.orange)
                    Text("\(erfasst.count) Zutaten im Vorrat · \(warnung)")
                } else {
                    Text(erfasst.count == 1 ? "1 Zutat im Vorrat" : "\(erfasst.count) Zutaten im Vorrat")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var begruessung: String {
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<11: "Guten Morgen"
        case 11..<17: "Guten Tag"
        default: "Guten Abend"
        }
    }

    // MARK: - Bald ablaufend

    private func ablaufAbschnitt(_ eintraege: [(eintrag: VorratsEintrag, status: AblaufStatus)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            abschnittTitel("Bald ablaufend", symbol: "clock.badge.exclamationmark")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(eintraege, id: \.eintrag.persistentModelID) { eintrag, status in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(eintrag.anzeigename, systemImage: eintrag.lagerort.symbol)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            Text(status.text)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(status.farbe)
                        }
                        .padding(12)
                        .frame(minWidth: 140, alignment: .leading)
                        .background(status.farbe.opacity(0.12), in: .rect(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(status.farbe.opacity(0.35)))
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Favoriten, die am besten zum Vorrat passen, zuerst
    private var favoritenVorschlaege: [RezeptVorschlag] {
        let vorratIDs = Set(vorrat.map(\.zutatID))
        return favoriten
            .compactMap { datenbank.rezeptNachID[$0.rezeptID] }
            .map { RezeptVorschlaege.einzeln($0, vorrat: vorratIDs, austauschgruppe: datenbank.austauschgruppe) }
            .sorted { $0.anteil > $1.anteil }
            .prefix(Self.anzahlKarten)
            .map { $0 }
    }

    /// Jedes Rezept nur in einer Reihe: «Aufbrauchen» zuerst, dann «Passt zu deinem Vorrat», dann «Schnell gemacht»
    private func reihen(_ vorschlaege: [RezeptVorschlag], ablaufend: Set<Int>)
        -> (aufbrauchen: [RezeptVorschlag], passt: [RezeptVorschlag], schnell: [RezeptVorschlag]) {
        let aufbrauchen = rezepteZumAufbrauchen(vorschlaege, zutaten: ablaufend)
        var gezeigt = Set(aufbrauchen.map(\.id))
        let passt = Array(vorschlaege.filter { !gezeigt.contains($0.id) }.prefix(Self.anzahlKarten))
        gezeigt.formUnion(passt.map(\.id))
        let schnell = Array(vorschlaege.filter { $0.rezept.zeitMinuten <= 30 && !gezeigt.contains($0.id) }
            .prefix(Self.anzahlKarten))
        return (aufbrauchen, passt, schnell)
    }

    /// Rezepte, die möglichst viele bald ablaufende Zutaten enthalten
    private func rezepteZumAufbrauchen(_ vorschlaege: [RezeptVorschlag], zutaten: Set<Int>) -> [RezeptVorschlag] {
        guard !zutaten.isEmpty else { return [] }
        return vorschlaege
            .map { vorschlag in (vorschlag, vorschlag.rezept.zutaten.count(where: zutaten.contains)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0.anteil > $1.0.anteil }
            .prefix(Self.anzahlKarten)
            .map(\.0)
    }

    // MARK: - Foto-Karten

    private func kartenReihe(_ titel: String, symbol: String, _ vorschlaege: [RezeptVorschlag],
                             namen: [Int: String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            abschnittTitel(titel, symbol: symbol)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(vorschlaege) { vorschlag in
                        NavigationLink(value: vorschlag.id) {
                            RezeptKarte(vorschlag: vorschlag, name: namen[vorschlag.id] ?? vorschlag.rezept.name,
                                        breite: breite == .regular ? 280 : 220)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            FavoritMenue(rezeptID: vorschlag.id, istFavorit: favoritIDs.contains(vorschlag.id))
                        }
                        .onAppear {
                            if namen[vorschlag.id] == nil {
                                uebersetzer.nameAnfordern(rezeptID: vorschlag.id, englisch: vorschlag.rezept.name)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
        }
    }

    private func abschnittTitel(_ titel: String, symbol: String) -> some View {
        Label(titel, systemImage: symbol)
            .font(.title3.bold())
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.primary, .tint)
            .padding(.horizontal)
    }

    // MARK: - Leerer Vorrat

    private var leererVorrat: some View {
        ContentUnavailableView {
            Label("Was hast du zuhause?", systemImage: "refrigerator")
        } description: {
            Text("Erfasse die Zutaten aus Kühlschrank, Tiefkühler und Vorratsschrank – dann schlägt Cookable passende Rezepte vor.")
        } actions: {
            Button("Zutaten erfassen", action: zeigeVorrat)
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 40)
    }
}

/// Grosse Karte mit Foto für die Startseite.
struct RezeptKarte: View {
    let vorschlag: RezeptVorschlag
    let name: String
    let breite: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RezeptFoto(url: vorschlag.rezept.bildURL, groesse: .mittel)
                .frame(width: breite, height: breite * 0.66)
                .clipped()
            VStack(alignment: .leading, spacing: 6) {
                Text(name)
                    .font(.headline)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 6) {
                    ProgressView(value: vorschlag.anteil)
                        .frame(width: 36)
                    Text("\(vorschlag.verfuegbar) von \(vorschlag.benoetigt)")
                    Text("·")
                    Image(systemName: "clock")
                    Text(vorschlag.rezept.zeitText)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            .padding(12)
        }
        .frame(width: breite)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
        .contentShape(.rect(cornerRadius: 18))
    }
}
