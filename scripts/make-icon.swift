import AppKit
import Foundation

let directory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
func color(_ value: Int) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255, green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}
func fill(_ path: NSBezierPath, _ value: Int) { color(value).setFill(); path.fill() }
func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ value: Int) {
    fill(NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)), value)
}
func draw() {
    fill(NSBezierPath(roundedRect: NSRect(x: 62, y: 62, width: 900, height: 900), xRadius: 210, yRadius: 210), 0xF0F3E9)
    ellipse(261, 187, 502, 71, 0xDEE6D2)
    ellipse(335, 206, 104, 119, 0xB4CDA1)
    ellipse(583, 206, 104, 119, 0xB4CDA1)
    ellipse(195, 344, 100, 155, 0xBED4AA)
    ellipse(732, 344, 100, 155, 0xBED4AA)
    let body = NSBezierPath()
    body.move(to: NSPoint(x: 512, y: 764))
    body.curve(to: NSPoint(x: 752, y: 565), controlPoint1: NSPoint(x: 649, y: 784), controlPoint2: NSPoint(x: 720, y: 707))
    body.curve(to: NSPoint(x: 750, y: 300), controlPoint1: NSPoint(x: 795, y: 405), controlPoint2: NSPoint(x: 823, y: 347))
    body.curve(to: NSPoint(x: 506, y: 239), controlPoint1: NSPoint(x: 703, y: 237), controlPoint2: NSPoint(x: 609, y: 230))
    body.curve(to: NSPoint(x: 275, y: 287), controlPoint1: NSPoint(x: 400, y: 234), controlPoint2: NSPoint(x: 318, y: 213))
    body.curve(to: NSPoint(x: 272, y: 540), controlPoint1: NSPoint(x: 215, y: 346), controlPoint2: NSPoint(x: 242, y: 420))
    body.curve(to: NSPoint(x: 512, y: 764), controlPoint1: NSPoint(x: 310, y: 714), controlPoint2: NSPoint(x: 357, y: 762))
    body.close()
    NSGradient(starting: color(0xCDDEB6), ending: color(0xE5EDCE))!.draw(in: body, angle: 70)
    let stem = NSBezierPath()
    stem.move(to: NSPoint(x: 510, y: 738)); stem.line(to: NSPoint(x: 528, y: 838))
    stem.lineWidth = 15; stem.lineCapStyle = .round; color(0x50775E).setStroke(); stem.stroke()
    let rightLeaf = NSBezierPath()
    rightLeaf.move(to: NSPoint(x: 526, y: 815))
    rightLeaf.curve(to: NSPoint(x: 674, y: 874), controlPoint1: NSPoint(x: 529, y: 896), controlPoint2: NSPoint(x: 615, y: 900))
    rightLeaf.curve(to: NSPoint(x: 526, y: 815), controlPoint1: NSPoint(x: 659, y: 792), controlPoint2: NSPoint(x: 579, y: 781))
    fill(rightLeaf, 0x789C63)
    let leftLeaf = NSBezierPath()
    leftLeaf.move(to: NSPoint(x: 515, y: 789))
    leftLeaf.curve(to: NSPoint(x: 396, y: 857), controlPoint1: NSPoint(x: 503, y: 853), controlPoint2: NSPoint(x: 450, y: 885))
    leftLeaf.curve(to: NSPoint(x: 515, y: 789), controlPoint1: NSPoint(x: 390, y: 794), controlPoint2: NSPoint(x: 454, y: 762))
    fill(leftLeaf, 0x9DB87A)
    ellipse(352, 437, 55, 24, 0xD8BB98)
    ellipse(616, 437, 55, 24, 0xD8BB98)
    fill(NSBezierPath(roundedRect: NSRect(x: 412, y: 478, width: 22, height: 36), xRadius: 11, yRadius: 11), 0x293D34)
    fill(NSBezierPath(roundedRect: NSRect(x: 591, y: 478, width: 22, height: 36), xRadius: 11, yRadius: 11), 0x293D34)
    let smile = NSBezierPath()
    smile.move(to: NSPoint(x: 486, y: 449))
    smile.curve(to: NSPoint(x: 538, y: 449), controlPoint1: NSPoint(x: 499, y: 427), controlPoint2: NSPoint(x: 525, y: 427))
    smile.lineWidth = 9; smile.lineCapStyle = .round; color(0x293D34).setStroke(); smile.stroke()
}
for dimension in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = dimension * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                      bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                      colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = NSAffineTransform()
        transform.scale(by: CGFloat(pixels) / 1024)
        transform.concat()
        draw()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = directory.appendingPathComponent("icon_\(dimension)x\(dimension)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}

// ICNS PNG chunks preserve the same vector artwork at every Retina size.
if CommandLine.arguments.count > 2 {
    func lengthBytes(_ length: Int) -> Data {
        var bigEndian = UInt32(length).bigEndian
        return withUnsafeBytes(of: &bigEndian) { Data($0) }
    }
    let variants = [("icp4", "16x16"), ("ic11", "16x16@2x"), ("icp5", "32x32"),
                    ("ic12", "32x32@2x"), ("ic07", "128x128"), ("ic13", "128x128@2x"),
                    ("ic08", "256x256"), ("ic14", "256x256@2x"), ("ic09", "512x512"), ("ic10", "512x512@2x")]
    var chunks = Data()
    for (type, filename) in variants {
        let png = try Data(contentsOf: directory.appendingPathComponent("icon_\(filename).png"))
        chunks.append(Data(type.utf8)); chunks.append(lengthBytes(png.count + 8)); chunks.append(png)
    }
    var icns = Data("icns".utf8)
    icns.append(lengthBytes(chunks.count + 8)); icns.append(chunks)
    try icns.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
}
