import Foundation

/// Görevin tekrar tipi.
enum RecurrenceKind: String, Codable, CaseIterable, Identifiable {
    case once, daily, weekly, monthly, interval

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: "Tek sefer"
        case .daily: "Her gün"
        case .weekly: "Haftalık"
        case .monthly: "Aylık"
        case .interval: "Her N günde bir"
        }
    }
}

/// Bir günlük kaydın durumu.
enum LogStatus: String, Codable {
    case done, skipped, postponed
    /// Aralıklı görev: gün devam ediyor, turlar sayılıyor.
    case partial
    /// Aralıklı görev: "Bugün daha fazla hatırlatma" dendi.
    case stopped
}

/// Saf (SwiftData'dan bağımsız) günlük kayıt. Motor ve testler bunu kullanır.
struct LogSnapshot: Equatable {
    var day: Date
    var status: LogStatus
    var completedAt: Date? = nil
    var postponedUntil: Date? = nil
    /// Aralıklı görevlerde yapılan / yapılamayan tur sayısı.
    var doneCount: Int = 0
    var missedCount: Int = 0
}

/// Saf görev görüntüsü. Zamanlama motoru sadece bununla çalışır.
struct TaskSnapshot {
    var id: UUID = UUID()
    var title: String = ""
    var icon: String = "checkmark"
    var colorHex: String = "#FF6B35"
    /// 0 ise miktar yok (ör. "Diş fırçala"). >0 ise ör. 10 şınav.
    var quantity: Int = 0
    var unit: String = ""
    var recurrence: RecurrenceKind = .daily
    /// Calendar weekday: 1 = Pazar ... 7 = Cumartesi
    var weekdays: Set<Int> = []
    var monthDay: Int = 1
    var intervalDays: Int = 2
    var startDate: Date = .now
    /// Gün içindeki dakika (ör. 540 = 09:00)
    var windowStart: Int = 9 * 60
    var windowEnd: Int = 12 * 60
    /// >0 ise görev gün içinde aralık boyunca her N dakikada bir hatırlatılır (örn. 25 dk'da bir 1 dk yürüyüş).
    var repeatEveryMinutes: Int = 0
    var isActive: Bool = true
    var logs: [LogSnapshot] = []

    var isRepeating: Bool { repeatEveryMinutes > 0 }

    /// Ceza çarpanı uygulanmış hedef metni: "20 şınav"
    func goalText(multiplier: Int = 1) -> String {
        guard quantity > 0 else {
            return multiplier > 1 ? "\(title) (x\(multiplier))" : title
        }
        let u = unit.isEmpty ? "tekrar" : unit
        return "\(quantity * multiplier) \(u)"
    }
}

/// Bir görevin belirli bir gündeki durumu.
enum DayStatus: Equatable {
    case notScheduled
    case pending
    case postponed(until: Date)
    case done(at: Date?)
    case skipped
    /// Aralıklı görev: gün sürüyor.
    case inProgress(done: Int, missed: Int)
    /// Aralıklı görev: bugünlük durduruldu.
    case stopped(done: Int)

    var isOpen: Bool {
        switch self {
        case .pending, .postponed, .inProgress: true
        default: false
        }
    }

    var isDone: Bool {
        if case .done = self { return true }
        return false
    }
}

/// Gün içi dakika aralığı.
struct MinuteWindow: Equatable {
    var start: Int
    var end: Int
    var learned: Bool = false

    var label: String { "\(Self.format(start))–\(Self.format(end))" }

    static func format(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
