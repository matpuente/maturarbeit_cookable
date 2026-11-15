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
    }
}
