import SwiftData
import SwiftUI

/// Vorrat: Zutaten nach Lagerort gruppiert (Platzhalter, folgt in Etappe 2).
struct VorratAnsicht: View {
    @Query(sort: \VorratsEintrag.name) private var eintraege: [VorratsEintrag]

    var body: some View {
        NavigationStack {
            Group {
                if eintraege.isEmpty {
                    ContentUnavailableView(
                        "Noch keine Zutaten",
                        systemImage: "refrigerator",
                        description: Text("Hier erscheinen bald die Zutaten, die du zuhause hast.")
                    )
                } else {
                    List(eintraege) { eintrag in
                        Text(eintrag.name)
                    }
                }
            }
            .navigationTitle("Vorrat")
        }
    }
}
