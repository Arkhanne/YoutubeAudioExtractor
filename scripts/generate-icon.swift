#!/usr/bin/env swift
import AppKit

// Dibuja en píxeles exactos (sin depender del factor de escala de pantalla)
func makeIconPNG(pixels size: Int) -> Data {
    let s = CGFloat(size)

    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    )!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Margen transparente ~4% para que no llegue al borde del canvas
    let pad  = s * 0.04
    let rect = NSRect(x: pad, y: pad, width: s - 2 * pad, height: s - 2 * pad)
    let bg   = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.22, yRadius: rect.height * 0.22)

    // Gradiente vertical: rojo brillante arriba → rojo oscuro abajo
    bg.setClip()
    let gradient = NSGradient(
        colors: [
            NSColor(red: 0.92, green: 0.14, blue: 0.14, alpha: 1),
            NSColor(red: 0.68, green: 0.05, blue: 0.05, alpha: 1),
        ],
        atLocations: [0, 1],
        colorSpace: .deviceRGB
    )!
    gradient.draw(in: rect, angle: 270)

    // Barras de onda — ocupan ~56% del ancho, máx 58% del alto
    let barW   = s * 0.078
    let gap    = s * 0.044
    let total  = 5 * barW + 4 * gap
    let startX = (s - total) / 2
    let relH: [CGFloat] = [0.23, 0.42, 0.58, 0.42, 0.23]

    NSColor.white.setFill()
    for (i, rel) in relH.enumerated() {
        let h = rel * s
        let x = startX + CGFloat(i) * (barW + gap)
        let y = (s - h) / 2
        NSBezierPath(
            roundedRect: NSRect(x: x, y: y, width: barW, height: h),
            xRadius: barW / 2, yRadius: barW / 2
        ).fill()
    }

    NSGraphicsContext.restoreGraphicsState()

    return rep.representation(using: .png, properties: [:])!
}

// iconutil espera esta estructura de carpeta en el directorio de trabajo
let iconset = "AppIcon.iconset"
let fm = FileManager.default
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let specs: [(logical: Int, scale: Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

for spec in specs {
    let pixels = spec.logical * spec.scale
    let data   = makeIconPNG(pixels: pixels)
    let name   = spec.scale == 1
        ? "icon_\(spec.logical)x\(spec.logical).png"
        : "icon_\(spec.logical)x\(spec.logical)@2x.png"
    fm.createFile(atPath: "\(iconset)/\(name)", contents: data)
}

print("✓ AppIcon.iconset generado (\(specs.count) tamaños)")
