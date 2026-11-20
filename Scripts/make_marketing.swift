// App Store "Header" ve "Search Results" tanıtım görsellerini üretir.
//     swift Scripts/make_marketing.swift
// Çıktı: AppStore/marketing/header-5244x2950.png, search-3840x2560.png
import AppKit
import SwiftUI

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let shots = root.appendingPathComponent("AppStore/screenshots/iphone")
let outDir = root.appendingPathComponent("AppStore/marketing")
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func image(_ name: String) -> NSImage {
    NSImage(contentsOf: shots.appendingPathComponent(name))!
}
let icon = NSImage(contentsOf: root.appendingPathComponent("Assets/Assets.xcassets/AppIcon.appiconset/icon-1024.png"))!

let orange = Color(red: 1, green: 0.42, blue: 0.21)
let red = Color(red: 0.90, green: 0.22, blue: 0.27)

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.06, blue: 0.05), Color(red: 0.22, green: 0.08, blue: 0.06)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [orange.opacity(0.55), .clear], center: .init(x: 0.72, y: 0.55),
                           startRadius: 0, endRadius: 1900)
            RadialGradient(colors: [red.opacity(0.35), .clear], center: .init(x: 0.15, y: 0.9),
                           startRadius: 0, endRadius: 1400)
        }
    }
}

/// Basit iPhone çerçevesi içinde ekran görüntüsü.
struct Phone: View {
    let shot: NSImage
    let height: CGFloat
    var body: some View {
        let w = height * 1320 / 2868
        Image(nsImage: shot)
            .resizable()
            .frame(width: w, height: height)
            .clipShape(RoundedRectangle(cornerRadius: w * 0.13, style: .continuous))
            .padding(w * 0.035)
            .background(RoundedRectangle(cornerRadius: w * 0.16, style: .continuous).fill(Color(white: 0.08)))
            .overlay(RoundedRectangle(cornerRadius: w * 0.16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: w * 0.008))
            .shadow(color: .black.opacity(0.55), radius: height * 0.05, y: height * 0.03)
    }
}

struct Title: View {
    let scale: CGFloat
    var body: some View {
        VStack(alignment: .leading, spacing: 40 * scale) {
            HStack(spacing: 48 * scale) {
                Image(nsImage: icon).resizable()
                    .frame(width: 300 * scale, height: 300 * scale)
                    .clipShape(RoundedRectangle(cornerRadius: 68 * scale, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 30 * scale, y: 14 * scale)
                Text("ForceMe")
                    .font(.system(size: 230 * scale, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text("Seni zorlayan hatırlatıcı")
                .font(.system(size: 120 * scale, weight: .bold, design: .rounded))
                .foregroundStyle(LinearGradient(colors: [Color(red: 1, green: 0.75, blue: 0.4), orange],
                                                startPoint: .leading, endPoint: .trailing))
            VStack(alignment: .leading, spacing: 26 * scale) {
                Bullet(text: "Her gün rastgele saatte hatırlatma", symbol: "shuffle", scale: scale)
                Bullet(text: "Kaçırırsan hedef katlanır: x2", symbol: "flame.fill", scale: scale)
                Bullet(text: "Dynamic Island'da geri sayım", symbol: "timer", scale: scale)
            }
            .padding(.top, 20 * scale)
        }
    }
}

struct Bullet: View {
    let text: String
    let symbol: String
    let scale: CGFloat
    var body: some View {
        HStack(spacing: 28 * scale) {
            Image(systemName: symbol)
                .font(.system(size: 62 * scale, weight: .bold))
                .foregroundStyle(orange)
                .frame(width: 90 * scale)
            Text(text)
                .font(.system(size: 72 * scale, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
        }
    }
}

/// Telefonlar: ortada büyük, iki yanda biraz küçük ve eğik.
struct Phones: View {
    let height: CGFloat
    var body: some View {
        ZStack {
            Phone(shot: image("03-gorevler.png"), height: height * 0.86)
                .rotationEffect(.degrees(-8))
                .offset(x: -height * 0.40, y: height * 0.05)
            Phone(shot: image("06-karanlik.png"), height: height * 0.86)
                .rotationEffect(.degrees(8))
                .offset(x: height * 0.40, y: height * 0.05)
            Phone(shot: image("01-bugun.png"), height: height)
        }
    }
}

/// Header 5244×2950: farklı yönlerde kırpılabildiği için önemli öğeler ortadaki ~3840×1646 bantta.
struct Header: View {
    var body: some View {
        ZStack {
            Background()
            HStack(spacing: 260) {
                Title(scale: 1.15)
                Phones(height: 1500)
                    .frame(width: 1750)
            }
        }
        .frame(width: 5244, height: 2950)
    }
}

/// Search Results 3840×2560.
struct Search: View {
    var body: some View {
        ZStack {
            Background()
            HStack(spacing: 140) {
                Title(scale: 0.95)
                Phones(height: 1650)
                    .frame(width: 1950)
            }
        }
        .frame(width: 3840, height: 2560)
    }
}

@MainActor
func write<V: View>(_ view: V, _ name: String) {
    let r = ImageRenderer(content: view)
    r.scale = 1
    r.isOpaque = true
    guard let cg = r.cgImage else { fatalError("render failed: \(name)") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
    print(name, cg.width, cg.height)
}

MainActor.assumeIsolated {
    write(Header(), "header-5244x2950.png")
    write(Search(), "search-3840x2560.png")
}
