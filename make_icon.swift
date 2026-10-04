import AppKit

// 渲染 1024x1024 主图标:macOS 风格圆角矩形 + 橙红渐变 + 白色咖啡杯
let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "/tmp/nosleep_master.png"
let size: CGFloat = 1024

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { exit(1) }

// 背景:超椭圆圆角矩形 + 顶到底橙红渐变
let rect = NSRect(x: 0, y: 0, width: size, height: size)
let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.225, yRadius: size * 0.225)
ctx.saveGState()
path.addClip()
let grad = NSGradient(colors: [
    NSColor(calibratedRed: 1.00, green: 0.65, blue: 0.20, alpha: 1),  // 顶:亮橙
    NSColor(calibratedRed: 0.93, green: 0.28, blue: 0.22, alpha: 1),  // 底:暖红
])!
grad.draw(in: path, angle: -90)
ctx.restoreGState()

// 白色咖啡杯符号,居中,约占 52%
let symName = "cup.and.saucer.fill"
guard let raw = NSImage(systemSymbolName: symName, accessibilityDescription: nil) else { exit(1) }
let conf = NSImage.SymbolConfiguration(pointSize: size * 0.52, weight: .semibold)
guard let sym = raw.withSymbolConfiguration(conf) else { exit(1) }
let symSize = sym.size

// 先把符号画到透明画布上,再用 sourceIn 染成纯白
let tinted = NSImage(size: symSize)
tinted.lockFocus()
sym.draw(in: NSRect(origin: .zero, size: symSize))
NSColor.white.set()
NSRect(origin: .zero, size: symSize).fill(using: .sourceIn)
tinted.unlockFocus()

let symRect = NSRect(x: (size - symSize.width) / 2,
                     y: (size - symSize.height) / 2 + size * 0.015,
                     width: symSize.width, height: symSize.height)
tinted.draw(in: symRect, from: .zero, operation: .sourceOver, fraction: 1)

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { exit(1) }
do {
    try png.write(to: URL(fileURLWithPath: outPath))
    print("wrote \(outPath)")
} catch {
    print("write failed: \(error)")
    exit(1)
}
