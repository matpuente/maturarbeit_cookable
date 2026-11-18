import SwiftData
import SwiftUI
import UserNotifications

/// Einstellungen für die Mitteilungen vor dem Ablaufen (Glocke im Vorrat).
struct MitteilungenEinstellungen: View {
    @Environment(\.dismiss) private var schliessen
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var oeffnen
    @Query private var vorrat: [VorratsEintrag]
    @AppStorage(AblaufMitteilungen.schluesselAn) private var an = true
    @AppStorage(AblaufMitteilungen.schluesselTage) private var tageText = AblaufMitteilungen.standardTage
    @AppStorage(AblaufMitteilungen.schluesselMinuten) private var minuten = AblaufMitteilungen.standardMinuten
    @State private var status: UNAuthorizationStatus?

    private var erlaubt: Bool {
        status == .authorized || status == .provisional || status == .ephemeral
    }

    private var vorlauf: Set<Int> { AblaufMitteilungen.vorlauf(aus: tageText) }

    /// Uhrzeit als Datum (für den DatePicker)
    private var uhrzeit: Binding<Date> {
        Binding {
            Calendar.current.date(byAdding: .minute, value: minuten, to: Calendar.current.startOfDay(for: .now)) ?? .now
        } set: { datum in
            let teile = Calendar.current.dateComponents([.hour, .minute], from: datum)
            minuten = (teile.hour ?? 0) * 60 + (teile.minute ?? 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Mitteilungen bei Ablauf", isOn: $an)
                        .onChange(of: an) { _, neu in
                            if neu { Task { await erlaubnisPruefen(anfragen: true) } }
                        }
                } footer: {
                    Text("Höchstens eine Mitteilung pro Tag mit allen Zutaten, die bald ablaufen. Antippen öffnet die Rezepte zum Aufbrauchen.")
                }

                if status == .denied && an {
                    Section {
                        Label("Mitteilungen sind in den iOS-Einstellungen ausgeschaltet.", systemImage: "bell.slash")
                            .foregroundStyle(.orange)
                        Button("Einstellungen öffnen") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { oeffnen(url) }
                        }
                    }
                }

                if an {
                    Section {
                        ForEach(AblaufMitteilungen.vorlaufOptionen, id: \.self) { tage in
                            Toggle(AblaufMitteilungen.titel(vorlauf: tage), isOn: Binding {
                                vorlauf.contains(tage)
                            } set: { gewaehlt in
                                var neu = vorlauf
                                if gewaehlt { neu.insert(tage) } else { neu.remove(tage) }
                                guard !neu.isEmpty else { return }  // mindestens ein Zeitpunkt
                                tageText = AblaufMitteilungen.text(aus: neu)
                            })
                        }
                        DatePicker("Uhrzeit", selection: uhrzeit, displayedComponents: .hourAndMinute)
                    } header: {
                        Text("Wann")
                    } footer: {
                        Text("Mindestens ein Zeitpunkt bleibt gewählt.")
                    }

                    Section("Nächste Mitteilung") {
                        if let plan = naechsterPlan {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.zeitpunkt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(plan.titel).font(.subheadline.weight(.semibold))
                                Text(plan.text).font(.subheadline)
                            }
                        } else {
                            Text("Keine – im Vorrat läuft in nächster Zeit nichts ab, oder es fehlen Ablaufdaten.")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Mitteilungen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { schliessen() }
                }
            }
            .task { await erlaubnisPruefen(anfragen: an) }
            .onChange(of: phase) { _, neu in
                // Zurück aus den iOS-Einstellungen
                if neu == .active { Task { await erlaubnisPruefen(anfragen: false) } }
            }
        }
    }

    private var naechsterPlan: AblaufMitteilungen.Plan? {
        let zutaten = vorrat.compactMap { eintrag in
            eintrag.ablaufdatum.map { AblaufMitteilungen.Zutat(name: eintrag.anzeigename, ablaufdatum: $0) }
        }
        return AblaufMitteilungen.plaene(fuer: zutaten, vorlauf: vorlauf, minuten: minuten).first
    }

    private func erlaubnisPruefen(anfragen: Bool) async {
        if anfragen { await AblaufMitteilungen.erlaubnisAnfragen() }
        status = await AblaufMitteilungen.status()
    }
}
