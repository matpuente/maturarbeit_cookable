import SwiftUI

/// Tab-Navigation der App.
struct HauptAnsicht: View {
    var body: some View {
        TabView {
            Tab("Vorrat", systemImage: "refrigerator") {
                VorratAnsicht()
            }
            Tab("Rezepte", systemImage: "fork.knife") {
                RezepteAnsicht()
            }
        }
        // Abgerundete Variante der Systemschrift: freundlicher, passend zu einer Koch-App
        .fontDesign(.rounded)
    }
}
