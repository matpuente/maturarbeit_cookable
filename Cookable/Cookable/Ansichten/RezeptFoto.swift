import SwiftUI
import UIKit

/// Foto eines Rezepts von Food.com.
///
/// Anders als `AsyncImage` wird ein schon geladenes Foto aus dem Zwischenspeicher (`URLCache`) genommen,
/// auch wenn es dort als veraltet gilt – so bleibt es ohne Internet sichtbar.
struct RezeptFoto: View {
    let url: URL?
    /// false, solange noch nicht feststeht, ob das Rezept überhaupt ein Foto hat
    let geladen: Bool

    @State private var bild: UIImage?
    @State private var fehlgeschlagen = false

    var body: some View {
        ZStack {
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                if geladen && (url == nil || fehlgeschlagen) {
                    Image(systemName: "fork.knife")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                }
            }
        }
        .task(id: url) { await laden() }
    }

    private func laden() async {
        guard let url else { return }
        bild = nil
        fehlgeschlagen = false
        let anfrage = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        do {
            let (daten, _) = try await URLSession.shared.data(for: anfrage)
            if let geladenesBild = UIImage(data: daten) {
                bild = geladenesBild
            } else {
                fehlgeschlagen = true
            }
        } catch {
            fehlgeschlagen = true
        }
    }
}
