import Foundation
import SwiftUI
import UserNotifications
import ImageIO
import UniformTypeIdentifiers

/// Görev ikonunu PNG'ye çizip bildirime ek olarak koyar → bildirimlerde ikon görünür.
@MainActor
enum IconRenderer {
    static func attachment(icon: String, colorHex: String, ring: RingStyle, multiplier: Int) -> UNNotificationAttachment? {
        guard let cached = cachedPNG(icon: icon, colorHex: colorHex, ring: ring, multiplier: multiplier) else { return nil }
        // Sistem ek dosyayı taşır; her bildirime ayrı kopya ver.
        let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).png")
        do {
            try FileManager.default.copyItem(at: cached, to: copy)
            return try UNNotificationAttachment(identifier: "icon", url: copy, options: nil)
        } catch {
            return nil
        }
    }

    private static func cachedPNG(icon: String, colorHex: String, ring: RingStyle, multiplier: Int) -> URL? {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent("ForceMeIcons", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        purgeOldVersions(in: dir)
        let key = "\(version)_\(icon)_\(colorHex)_\(ring.rawValue)_\(multiplier)".filter { $0.isLetter || $0.isNumber || $0 == "_" }
        let url = dir.appendingPathComponent("\(key).png")
        if fm.fileExists(atPath: url.path) { return url }

        // Kare, ortalanmış ve rozet için kenarlarda pay bırakılmış görsel.
        let view = TaskIconView(icon: icon, color: Color(hex: colorHex), ring: ring, multiplier: multiplier, size: 100)
            .frame(width: 128, height: 128)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        guard let rendered = renderer.cgImage,
              let image = standardRGBA(rendered),
              let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(dest, image, nil)
        return CGImageDestinationFinalize(dest) ? url : nil
    }

    /// Önbellek biçimi değişince artan sürüm (v3: 8-bit sRGB).
    private static let version = "v3"
    private static var purged = false

    private static func purgeOldVersions(in dir: URL) {
        guard !purged else { return }
        purged = true
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: dir.path)) ?? [] where !name.hasPrefix("\(version)_") {
            try? fm.removeItem(at: dir.appendingPathComponent(name))
        }
    }

    /// ImageRenderer geniş renkli ekranlarda 16-bit Display P3 görüntü üretir; bildirim sistemi
    /// bundan küçük resim oluşturamıyor (QuickLook hata 102) ve ikon yerine boş yer tutucu gösteriyor.
    /// Bu yüzden görüntü standart 8-bit sRGB'ye çevrilir.
    private static func standardRGBA(_ image: CGImage) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }
}
