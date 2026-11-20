// Uygulama ikonunu üretir: Assets/Assets.xcassets/AppIcon.appiconset
//     swift Scripts/make_app_icon.swift
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath)
let setDir = root.appendingPathComponent("Assets/Assets.xcassets/AppIcon.appiconset", isDirectory: true)
try FileManager.default.createDirectory(at: setDir, withIntermediateDirectories: true)

/// Turuncu-kırmızı zemin, ortada beyaz alev ve geri sayım halkası.
struct IconArt: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 1, green: 0.55, blue: 0.2), Color(red: 0.86, green: 0.16, blue: 0.22)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 58, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(170)
            Image(systemName: "flame.fill")
                .font(.system(size: 400, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -10)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// iOS koyu ikon: şeffaf zemin (sistem koyu zemin ekler), turuncu alev ve halka.
struct DarkIconArt: View {
    let gradient = LinearGradient(colors: [Color(red: 1, green: 0.62, blue: 0.25), Color(red: 0.93, green: 0.25, blue: 0.25)],
                                  startPoint: .topLeading, endPoint: .bottomTrailing)
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(gradient, style: StrokeStyle(lineWidth: 58, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(170)
            Image(systemName: "flame.fill")
                .font(.system(size: 400, weight: .bold))
                .foregroundStyle(gradient)
                .offset(y: -10)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// iOS renklendirilmiş (tinted) ikon: gri tonlu; sistem kullanıcının seçtiği rengi uygular.
struct TintedIconArt: View {
    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.78)
                .stroke(Color(white: 0.75), style: StrokeStyle(lineWidth: 58, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(170)
            Image(systemName: "flame.fill")
                .font(.system(size: 400, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -10)
        }
        .frame(width: 1024, height: 1024)
    }
}

/// macOS ikonları sistem tarafından maskelenmez: yuvarlatılmış kare + kenar boşluğu.
struct MacIconArt: View {
    var body: some View {
        IconArt()
            .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
            .frame(width: 1024, height: 1024)
            .scaleEffect(824.0 / 1024.0)
            .frame(width: 1024, height: 1024)
    }
}

@MainActor
func writePNG<V: View>(_ view: V, pixels: Int, opaque: Bool, to name: String) {
    let renderer = ImageRenderer(content: view)
    renderer.scale = CGFloat(pixels) / 1024
    renderer.isOpaque = opaque
    guard let cg = renderer.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: setDir.appendingPathComponent(name))
}

var images: [[String: Any]] = []

MainActor.assumeIsolated {
    writePNG(IconArt(), pixels: 1024, opaque: true, to: "icon-1024.png")
    images.append(["filename": "icon-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"])
    writePNG(DarkIconArt(), pixels: 1024, opaque: false, to: "icon-dark-1024.png")
    writePNG(TintedIconArt(), pixels: 1024, opaque: false, to: "icon-tinted-1024.png")
    images.append(["filename": "icon-dark-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
                   "appearances": [["appearance": "luminosity", "value": "dark"]]])
    images.append(["filename": "icon-tinted-1024.png", "idiom": "universal", "platform": "ios", "size": "1024x1024",
                   "appearances": [["appearance": "luminosity", "value": "tinted"]]])
    images.append(["filename": "icon-1024.png", "idiom": "universal", "platform": "watchos", "size": "1024x1024"])

    for points in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let name = "mac-\(points)@\(scale)x.png"
            writePNG(MacIconArt(), pixels: points * scale, opaque: false, to: name)
            images.append(["filename": name, "idiom": "mac", "scale": "\(scale)x", "size": "\(points)x\(points)"])
        }
    }
}

let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
    .write(to: setDir.appendingPathComponent("Contents.json"))
try #"{"info":{"author":"xcode","version":1}}"#.data(using: .utf8)!
    .write(to: root.appendingPathComponent("Assets/Assets.xcassets/Contents.json"))
print("ok")
