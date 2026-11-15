import SwiftUI
import UIKit

/// Foto eines Rezepts von Food.com – gross in der Detailansicht, mittel auf den Karten der Startseite
/// oder als kleines Vorschaubild in der Liste.
///
/// Anders als `AsyncImage` wird ein schon geladenes Foto aus dem Zwischenspeicher (`URLCache`) genommen,
/// auch wenn es dort als veraltet gilt – so bleibt es ohne Internet sichtbar.
struct RezeptFoto: View {
    let url: URL?
    /// false, solange noch nicht feststeht, ob das Rezept überhaupt ein Foto hat
    var geladen = true
    /// Kleinere Fassungen liefert Food.com auf Wunsch direkt (klein rund 10 KB statt 100 KB)
    var groesse = Groesse.gross

    enum Groesse {
        case gross, mittel, klein

        /// Bildbearbeitung von Food.com (Cloudinary), nil = Original
        var parameter: String? {
            switch self {
            case .gross: nil
            case .mittel: "w_560,h_400,c_fill,q_80"
            case .klein: "w_160,h_160,c_fill,q_80"
            }
        }
    }

    private var klein: Bool { groesse == .klein }

    @State private var bild: UIImage?
    @State private var fehlgeschlagen = false

    /// Bereits geladene Vorschaubilder, damit beim Scrollen nichts flackert
    private static let vorschauSpeicher = NSCache<NSURL, UIImage>()

    private var ladeURL: URL? {
        guard let url, let parameter = groesse.parameter else { return url }
        // .../image/upload/w_555,h_416,c_fit,.../v1/... -> .../image/upload/w_160,h_160,c_fill,q_80/v1/...
        let text = url.absoluteString.replacingOccurrences(
            of: #"/upload/[^/]+/v1/"#, with: "/upload/\(parameter)/v1/", options: .regularExpression
        )
        return URL(string: text) ?? url
    }

    var body: some View {
        ZStack {
            if let bild {
                Image(uiImage: bild).resizable().scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                if geladen && (url == nil || fehlgeschlagen) {
                    Image(systemName: "fork.knife")
                        .font(klein ? .body : .largeTitle)
                        .foregroundStyle(.secondary)
                } else if !klein {
                    ProgressView()
                }
            }
        }
        .task(id: url) { await laden() }
    }

    private func laden() async {
        guard let ladeURL else { return }
        if groesse != .gross, let gespeichert = Self.vorschauSpeicher.object(forKey: ladeURL as NSURL) {
            bild = gespeichert
            return
        }
        bild = nil
        fehlgeschlagen = false
        let anfrage = URLRequest(url: ladeURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        do {
            let (daten, _) = try await URLSession.shared.data(for: anfrage)
            guard let geladenesBild = UIImage(data: daten) else {
                fehlgeschlagen = true
                return
            }
            if groesse != .gross {
                Self.vorschauSpeicher.setObject(geladenesBild, forKey: ladeURL as NSURL)
            }
            bild = geladenesBild
        } catch {
            fehlgeschlagen = true
        }
    }
}
