#if DEBUG
import Foundation
import UserNotifications

/// Sadece DEBUG: uygulamayı `-demo` argümanıyla açınca örnek görevler kurar.
/// Xcode > Scheme > Run > Arguments'a `-demo` ekleyerek dene.
@MainActor
enum DemoData {
    static func seedIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-demo") else { return }
        let store = ForceStore.shared
        // Silinen eski demo görevlerinin bekleyen/teslim edilmiş bildirimleri kalmasın.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        for task in store.allTasks() { store.context.delete(task) }
        store.save()

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: today)! }
        func at(_ offset: Int, _ h: Int, _ m: Int) -> Date { cal.date(bySettingHour: h, minute: m, second: 0, of: day(offset))! }

        func make(_ title: String, icon: String, color: String, qty: Int = 0, unit: String = "",
                  start: Int, end: Int, every: Int = 0, logs: [(Int, LogStatus, Date?)],
                  counts: [Int: (done: Int, missed: Int)] = [:]) -> ForceTask {
            let t = ForceTask(title: title)
            store.context.insert(t)
            t.icon = icon; t.colorHex = color; t.quantity = qty; t.unit = unit
            t.windowStart = start; t.windowEnd = end
            t.repeatEveryMinutes = every
            t.startDate = day(-10)
            for (offset, status, completedAt) in logs {
                let log = TaskLog(day: day(offset))
                store.context.insert(log)
                log.status = status
                log.completedAt = completedAt
                if let c = counts[offset] { log.doneCount = c.done; log.missedCount = c.missed }
                log.task = t
            }
            return t
        }

        // Alışkanlık öğrenilmiş: hep 11:00–11:30 arası yapılmış.
        _ = make("Diş fırçala", icon: "mouth.fill", color: "#3A86FF", start: 9 * 60, end: 12 * 60,
                 logs: (1...5).map { (-$0, .done, at(-$0, 11, 5 + $0 * 4)) })
        // Dün kaçırıldı → bugün x2.
        let pushups = make("Şınav çek", icon: "figure.strengthtraining.traditional", color: "#E63946",
                           qty: 10, unit: "şınav", start: 18 * 60, end: 21 * 60,
                           logs: [(-2, .done, at(-2, 19, 0))])
        // Gün içi tekrar: 08–18 arası 25 dk'da bir 1 dk yürüyüş. Dün hedef tuttu, bugün 3 yapıldı 1 kaçtı.
        _ = make("Yürüyüş", icon: "figure.walk", color: "#2A9D8F", qty: 1, unit: "dk yürüyüş",
                 start: 8 * 60, end: 18 * 60, every: 25,
                 logs: [(-1, .partial, at(-1, 17, 40)), (0, .partial, .now.addingTimeInterval(-600))],
                 counts: [-1: (15, 4), 0: (3, 1)])
        // Bugün yapılmış.
        _ = make("2 litre su iç", icon: "drop.fill", color: "#118AB2", start: 10 * 60, end: 16 * 60,
                 logs: [(0, .done, .now.addingTimeInterval(-3600)), (-1, .done, at(-1, 14, 0))])
        // Ertelenecek görev.
        let reading = make("Kitap oku", icon: "book.fill", color: "#8338EC", qty: 20, unit: "sayfa",
                           start: 20 * 60, end: 23 * 60, logs: [(-1, .done, at(-1, 21, 0))])
        store.save()
        _ = pushups
        // -demoQuick: Dynamic Island halkasının azalışını hızlı görmek için 1 dakikalık erteleme.
        store.postpone(reading.id, minutes: ProcessInfo.processInfo.arguments.contains("-demoQuick") ? 1 : 5)
    }
}
#endif

#if DEBUG && os(macOS)
import AppKit

/// Sadece DEBUG/Mac: `-snapshot <dosya.png>` ile açılınca ana pencereyi 2x PNG olarak kaydedip çıkar
/// (App Store ekran görüntüleri için; ekran kaydı izni gerektirmez).
@MainActor
enum MacSnapshot {
    static func runIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-snapshot"), i + 1 < args.count else { return }
        let path = args[i + 1]
        NSApp.appearance = NSAppearance(named: .aqua)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            guard let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil && $0.frame.width > 400 }),
                  let frameView = window.contentView?.superview else { exit(1) }
            window.setContentSize(NSSize(width: 1440, height: 900))
            window.center()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                let bounds = frameView.bounds
                guard let rep = frameView.bitmapImageRepForCachingDisplay(in: bounds) else { exit(1) }
                frameView.cacheDisplay(in: bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
                exit(0)
            }
        }
    }
}
#endif
