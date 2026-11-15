import SwiftData
import SwiftUI

/// Eintrag für das Menü beim langen Drücken auf ein Rezept: zu den Favoriten hinzufügen oder entfernen.
struct FavoritMenue: View {
    let rezeptID: Int
    let istFavorit: Bool

    @Environment(\.modelContext) private var kontext

    var body: some View {
        Button(istFavorit ? "Aus Favoriten entfernen" : "Zu Favoriten hinzufügen",
               systemImage: istFavorit ? "heart.slash" : "heart") {
            kontext.favoritUmschalten(rezeptID)
        }
    }
}
