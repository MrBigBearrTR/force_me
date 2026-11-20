import Foundation

/// Zorlayıcı hatırlatma motoru: hangi gün görev var, ceza çarpanı ne,
/// hatırlatma hangi rastgele saatte gelecek, kullanıcının alışkanlığına göre
/// aralık nasıl daralacak — hepsi burada, saf fonksiyonlar olarak.
struct ScheduleEngine {
    var calendar: Calendar = .current

    /// Öğrenmenin başlaması için gereken minimum tamamlama sayısı.
    static let minSamplesToLearn = 3
    /// Öğrenmede bakılan son tamamlama sayısı.
    static let learningSampleSize = 14
    /// Öğrenilmiş aralığın minimum genişliği (dakika).
    static let minLearnedWidth = 20
    /// Ceza çarpanının üst sınırı.
    static let maxMultiplier = 10
    /// Bir günde gönderilecek en fazla hatırlatma.
    static let maxRemindersPerDay = 4
    /// Ek (ceza) hatırlatmaları arasındaki dakika.
    static let followUpGap = 20
    /// Aralıklı görevde günü "başarılı" saymak için yapılması gereken tur oranı.
    static let intervalSuccessRatio = 0.5
    /// Aralıklı görevde en kısa tekrar süresi.
    static let minRepeatMinutes = 5

    // MARK: - Gün hesapları

    func startOfDay(_ date: Date) -> Date { calendar.startOfDay(for: date) }

    func addDays(_ n: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: n, to: date) ?? date
    }

    func log(_ task: TaskSnapshot, on date: Date) -> LogSnapshot? {
        task.logs.last { calendar.isDate($0.day, inSameDayAs: date) }
    }

    // MARK: - Tekrar kuralı

    /// Görev bu güne düşüyor mu?
    func occurs(_ task: TaskSnapshot, on date: Date) -> Bool {
        guard task.isActive else { return false }
        let day = startOfDay(date)
        let start = startOfDay(task.startDate)
        guard day >= start else { return false }

        switch task.recurrence {
        case .once:
            // Tek seferlik görev yapılana kadar her gün peşini bırakmaz.
            return !task.logs.contains { startOfDay($0.day) < day && isSuccess(task, log: $0) }
        case .daily:
            return true
        case .weekly:
            let weekday = calendar.component(.weekday, from: day)
            let days = task.weekdays.isEmpty ? [calendar.component(.weekday, from: start)] : task.weekdays
            return days.contains(weekday)
        case .monthly:
            let dayOfMonth = calendar.component(.day, from: day)
            let lastDay = calendar.range(of: .day, in: .month, for: day)?.count ?? 31
            return dayOfMonth == min(max(task.monthDay, 1), lastDay)
        case .interval:
            let n = max(1, task.intervalDays)
            let diff = calendar.dateComponents([.day], from: start, to: day).day ?? 0
            return diff % n == 0
        }
    }

    func status(_ task: TaskSnapshot, on date: Date) -> DayStatus {
        if let entry = log(task, on: date) {
            switch entry.status {
            case .done: return .done(at: entry.completedAt)
            case .skipped: return .skipped
            case .postponed: return .postponed(until: entry.postponedUntil ?? date)
            case .partial: return .inProgress(done: entry.doneCount, missed: entry.missedCount)
            case .stopped: return .stopped(done: entry.doneCount)
            }
        }
        return occurs(task, on: date) ? .pending : .notScheduled
    }

    // MARK: - Ceza

    /// `date`'ten önceki, art arda yapılmamış görev günü sayısı.
    func missedStreak(_ task: TaskSnapshot, before date: Date) -> Int {
        let start = startOfDay(task.startDate)
        var day = addDays(-1, to: startOfDay(date))
        var streak = 0
        var steps = 0
        while day >= start && steps < 120 {
            if occurs(task, on: day) {
                if isSuccess(task, on: day) { break }
                streak += 1
            }
            day = addDays(-1, to: day)
            steps += 1
        }
        return streak
    }

    /// 1 gün kaçırırsan x2, 2 gün kaçırırsan x3...
    func penaltyMultiplier(_ task: TaskSnapshot, on date: Date) -> Int {
        min(1 + missedStreak(task, before: date), Self.maxMultiplier)
    }

    // MARK: - Hatırlatma aralığı ve saati

    func baseWindow(_ task: TaskSnapshot) -> MinuteWindow {
        let start = min(max(task.windowStart, 0), 24 * 60 - 1)
        var end = min(max(task.windowEnd, 0), 24 * 60 - 1)
        if end <= start { end = min(start + 60, 24 * 60 - 1) }
        return MinuteWindow(start: start, end: end)
    }

    /// Kullanıcı genelde 11:00–11:30 arasında yapıyorsa aralığı oraya daraltır.
    func effectiveWindow(_ task: TaskSnapshot) -> MinuteWindow {
        let base = baseWindow(task)
        guard !task.isRepeating else { return base }
        let minutes = task.logs
            .filter { $0.status == .done && $0.completedAt != nil }
            .sorted { $0.day > $1.day }
            .prefix(Self.learningSampleSize)
            .compactMap { $0.completedAt.map(minuteOfDay) }
            .filter { $0 >= base.start && $0 <= base.end }
            .sorted()

        guard minutes.count >= Self.minSamplesToLearn else { return base }

        var lo = percentile(minutes, 0.2)
        var hi = percentile(minutes, 0.8)
        if hi - lo < Self.minLearnedWidth {
            let mid = (lo + hi) / 2
            lo = mid - Self.minLearnedWidth / 2
            hi = mid + Self.minLearnedWidth / 2
        }
        lo = max(lo, base.start)
        hi = min(hi, base.end)
        guard hi > lo else { return base }
        if lo == base.start && hi == base.end { return base }
        return MinuteWindow(start: lo, end: hi, learned: true)
    }

    /// O günün hatırlatma saatleri. İlk saat aralık içinde rastgele (ama gün+görev için sabit),
    /// ceza varsa ek hatırlatmalar 20 dk arayla gelir.
    func reminderTimes(_ task: TaskSnapshot, on date: Date) -> [Date] {
        if task.isRepeating { return slotTimes(task, on: date) }
        let window = effectiveWindow(task)
        var rng = SplitMix64(seed: Self.stableSeed("\(task.id.uuidString)|\(dayKey(date))"))
        let width = UInt64(window.end - window.start + 1)
        let minute = window.start + Int(rng.next() % width)
        let first = startOfDay(date).addingTimeInterval(TimeInterval(minute * 60))
        let count = min(penaltyMultiplier(task, on: date), Self.maxRemindersPerDay)
        return (0..<count).map { first.addingTimeInterval(TimeInterval($0 * Self.followUpGap * 60)) }
    }

    // MARK: - Gün içi aralıklı tekrar

    /// Aralık boyunca her N dakikada bir tur: 08:00, 08:25, 08:50 … 18:00.
    func slotTimes(_ task: TaskSnapshot, on date: Date) -> [Date] {
        guard task.isRepeating else { return [] }
        let window = baseWindow(task)
        let step = max(Self.minRepeatMinutes, task.repeatEveryMinutes)
        let day = startOfDay(date)
        return stride(from: window.start, through: window.end, by: step)
            .map { day.addingTimeInterval(TimeInterval($0 * 60)) }
    }

    /// Günü kurtarmak için en az kaç tur yapılmalı (yarısı, yukarı yuvarlanır).
    func requiredSlots(_ task: TaskSnapshot, on date: Date) -> Int {
        let total = slotTimes(task, on: date).count
        return max(1, Int((Double(total) * Self.intervalSuccessRatio).rounded(.up)))
    }

    /// O gün görev başarılı mı? Normal görevde "yapıldı", aralıklıda yeterli tur.
    func isSuccess(_ task: TaskSnapshot, on date: Date) -> Bool {
        guard let entry = log(task, on: date) else { return false }
        return isSuccess(task, log: entry)
    }

    private func isSuccess(_ task: TaskSnapshot, log entry: LogSnapshot) -> Bool {
        if task.isRepeating {
            return entry.doneCount >= requiredSlots(task, on: entry.day)
        }
        return entry.status == .done
    }

    /// Sıradaki tur saati (yoksa nil).
    func nextSlot(_ task: TaskSnapshot, after now: Date) -> Date? {
        slotTimes(task, on: now).first { $0 > now }
    }

    // MARK: - İstatistik

    func dayStats(_ tasks: [TaskSnapshot], on date: Date) -> (done: Int, total: Int) {
        var done = 0, total = 0
        for task in tasks {
            let s = status(task, on: date)
            guard s != .notScheduled else { continue }
            total += 1
            if isSuccess(task, on: date) { done += 1 }
        }
        return (done, total)
    }

    // MARK: - Yardımcılar

    func minuteOfDay(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    func dayKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private func percentile(_ sorted: [Int], _ p: Double) -> Int {
        sorted[Int((Double(sorted.count - 1) * p).rounded())]
    }

    /// Platformlar arası sabit hash (Hasher her açılışta değişir, bu değişmez).
    static func stableSeed(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash &*= 0x100000001b3
        }
        return hash
    }
}

struct SplitMix64: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
