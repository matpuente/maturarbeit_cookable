// Zeichnet das App-Symbol von Cookable (dampfender Kochtopf) in drei Varianten für iOS:
// hell, dunkel und getönt. Nicht Teil der App.
//
// Aufruf (im Ordner Cookable/):
//   swift Design/AppSymbol.swift Cookable/Assets.xcassets/AppIcon.appiconset
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let groesse = 1024
let ziel = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")

func farbe(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

enum Variante { case hell, dunkel, getoent }

func zeichnen(_ variante: Variante, datei: String) {
    let raum = CGColorSpace(name: CGColorSpace.sRGB)!
    let kontext = CGContext(data: nil, width: groesse, height: groesse, bitsPerComponent: 8, bytesPerRow: 0,
                            space: raum, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Koordinaten von oben links wie in einer Zeichnung
    kontext.translateBy(x: 0, y: CGFloat(groesse))
    kontext.scaleBy(x: 1, y: -1)
    let flaeche = CGRect(x: 0, y: 0, width: groesse, height: groesse)

    // Hintergrund
    switch variante {
    case .hell, .dunkel:
        let oben = variante == .hell ? farbe(0x43B874) : farbe(0x1F4D33)
        let unten = variante == .hell ? farbe(0x23824A) : farbe(0x0E2619)
        let verlauf = CGGradient(colorsSpace: raum, colors: [oben, unten] as CFArray, locations: [0, 1])!
        kontext.drawLinearGradient(verlauf, start: .zero, end: CGPoint(x: 0, y: groesse), options: [])
    case .getoent:
        kontext.setFillColor(farbe(0x000000))
        kontext.fill(flaeche)
    }

    let topf = variante == .dunkel ? farbe(0x8EE0AE) : farbe(0xFFFFFF)
    let akzent = variante == .getoent ? farbe(0x000000) : (variante == .hell ? farbe(0x2F9A5C) : farbe(0x163A26))

    // Dampf: drei geschwungene Linien über dem Topf
    kontext.setStrokeColor(variante == .dunkel ? farbe(0x8EE0AE, 0.75) : farbe(0xFFFFFF, 0.8))
    kontext.setLineWidth(34)
    kontext.setLineCap(.round)
    for x in [392.0, 512.0, 632.0] {
        let pfad = CGMutablePath()
        pfad.move(to: CGPoint(x: x, y: 380))
        pfad.addCurve(to: CGPoint(x: x, y: 250), control1: CGPoint(x: x - 46, y: 335), control2: CGPoint(x: x + 46, y: 295))
        pfad.addCurve(to: CGPoint(x: x, y: 150), control1: CGPoint(x: x - 40, y: 215), control2: CGPoint(x: x + 30, y: 180))
        kontext.addPath(pfad)
        kontext.strokePath()
    }

    kontext.setFillColor(topf)
    // Griff auf dem Deckel
    kontext.addPath(CGPath(roundedRect: CGRect(x: 462, y: 410, width: 100, height: 46), cornerWidth: 23, cornerHeight: 23, transform: nil))
    kontext.fillPath()
    // Deckel
    kontext.addPath(CGPath(roundedRect: CGRect(x: 232, y: 450, width: 560, height: 62), cornerWidth: 31, cornerHeight: 31, transform: nil))
    kontext.fillPath()
    // Henkel links und rechts
    for x in [178.0, 768.0] {
        kontext.addPath(CGPath(roundedRect: CGRect(x: x, y: 560, width: 78, height: 54), cornerWidth: 27, cornerHeight: 27, transform: nil))
        kontext.fillPath()
    }
    // Topf
    let koerper = CGMutablePath()
    koerper.move(to: CGPoint(x: 252, y: 532))
    koerper.addLine(to: CGPoint(x: 772, y: 532))
    koerper.addLine(to: CGPoint(x: 772, y: 760))
    koerper.addQuadCurve(to: CGPoint(x: 682, y: 850), control: CGPoint(x: 772, y: 850))
    koerper.addLine(to: CGPoint(x: 342, y: 850))
    koerper.addQuadCurve(to: CGPoint(x: 252, y: 760), control: CGPoint(x: 252, y: 850))
    koerper.closeSubpath()
    kontext.addPath(koerper)
    kontext.fillPath()

    // Blatt als Zeichen für frische Lebensmittel
    kontext.setFillColor(akzent)
    let blatt = CGMutablePath()
    blatt.move(to: CGPoint(x: 512, y: 600))
    blatt.addCurve(to: CGPoint(x: 512, y: 790), control1: CGPoint(x: 600, y: 640), control2: CGPoint(x: 590, y: 760))
    blatt.addCurve(to: CGPoint(x: 512, y: 600), control1: CGPoint(x: 434, y: 760), control2: CGPoint(x: 424, y: 640))
    kontext.addPath(blatt)
    kontext.fillPath()
    kontext.setStrokeColor(topf)
    kontext.setLineWidth(10)
    kontext.move(to: CGPoint(x: 512, y: 630))
    kontext.addLine(to: CGPoint(x: 512, y: 770))
    kontext.strokePath()

    let bild = kontext.makeImage()!
    let url = ziel.appendingPathComponent(datei)
    let ausgabe = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(ausgabe, bild, nil)
    CGImageDestinationFinalize(ausgabe)
    print("geschrieben:", url.path)
}

zeichnen(.hell, datei: "AppSymbol.png")
zeichnen(.dunkel, datei: "AppSymbol-dunkel.png")
zeichnen(.getoent, datei: "AppSymbol-getoent.png")
