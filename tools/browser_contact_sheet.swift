// Assemble captured browser screenshots for visual QA. No artwork is generated.
import AppKit

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2 else { fatalError("Usage: swift browser_contact_sheet.swift OUTPUT.png INPUT.png ...") }
let files = Array(arguments.dropFirst())
let columns = min(4, files.count)
let rows = (files.count + columns - 1) / columns
let cell = NSSize(width: 400, height: 510)
let canvas = NSImage(size: NSSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows)))
canvas.lockFocus()
NSColor(calibratedWhite: 0.12, alpha: 1).setFill()
NSRect(origin: .zero, size: canvas.size).fill()
for (index, file) in files.enumerated() {
    guard let source = NSImage(contentsOfFile: file) else { fatalError("Cannot read \(file)") }
    let x = CGFloat(index % columns) * cell.width
    let y = canvas.size.height - CGFloat(index / columns + 1) * cell.height
    let scale = min((cell.width - 16) / source.size.width, (cell.height - 38) / source.size.height)
    let size = NSSize(width: source.size.width * scale, height: source.size.height * scale)
    source.draw(in: NSRect(x: x + (cell.width - size.width) / 2, y: y + 28 + (cell.height - 38 - size.height) / 2, width: size.width, height: size.height))
    let title = URL(fileURLWithPath: file).deletingPathExtension().lastPathComponent
    (title as NSString).draw(at: NSPoint(x: x + 12, y: y + 8), withAttributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white])
}
canvas.unlockFocus()
guard let tiff = canvas.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff), let png = bitmap.representation(using: .png, properties: [:]) else { fatalError("Image encoding failed") }
try png.write(to: URL(fileURLWithPath: arguments[0]))
