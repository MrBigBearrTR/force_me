import Foundation
import SwiftData
#if os(watchOS)
import WatchKit
#endif

/// Tek veri deposu + görev aksiyonları (Yaptım / Ertele / Bugün yapamam).
/// Uygulama, bildirim aksiyonları ve Live Activity butonları hep buradan geçer.
@MainActor
final class ForceStore {
    static let shared = ForceStore()

    let container: ModelContainer
    let engine = ScheduleEngine()
    var context: ModelContext { container.mainContext }

    private init() {
        let schema = Schema([ForceTask.self, TaskLog.self])
        // App Group + iCloud (imza ve yetkiler varsa) → iPhone, iPad, Mac, Watch senkron.
        let synced = ModelConfiguration(schema: schema, groupContainer: .automatic, cloudKitDatabase: .automatic)
        if let c = try? ModelContainer(for: schema, configurations: [synced]) {
            container = c
        } else {
            let local = ModelConfiguration(schema: schema, groupContainer: .none, cloudKitDatabase: .none)
            container = try! ModelContainer(for: schema, configurations: [local])
        }
    }

    // MARK: - Okuma

    func allTasks() -> [ForceTask] {
        (try? context.fetch(FetchDescriptor<ForceTask>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    func task(_ id: UUID) -> ForceTask? {
        var d = FetchDescriptor<ForceTask>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        return try? context.fetch(d).first
    }

    func todayLog(for task: ForceTask, now: Date = .now) -> TaskLog? {
        task.logs?.first { Calendar.current.isDate($0.day, inSameDayAs: now) }
    }

    private func makeTodayLog(for task: ForceTask, now: Date = .now) -> TaskLog {
        if let existing = todayLog(for: task, now: now) { return existing }
        let log = TaskLog(day: Calendar.current.startOfDay(for: now))
        context.insert(log)
        log.task = task
        return log
    }

    // MARK: - Aksiyonlar

    func complete(_ id: UUID) {
        guard let task = task(id) else { return }
        if task.repeatEveryMinutes > 0 { return slotDone(id) }
        let m = engine.penaltyMultiplier(task.snapshot, on: .now)
        let log = makeTodayLog(for: task)
        log.status = .done
        log.completedAt = .now
        log.postponedUntil = nil
        log.multiplier = m
        save()
        afterChange(id)
        NotificationScheduler.shared.sendPraise(for: task.snapshot, multiplier: m)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }

    func postpone(_ id: UUID, minutes: Int) {
        guard let task = task(id) else { return }
        let until = Date.now.addingTimeInterval(TimeInterval(minutes * 60))
        let m = engine.penaltyMultiplier(task.snapshot, on: .now)
        let log = makeTodayLog(for: task)
        if task.repeatEveryMinutes > 0 {
            // Aralıklı görev: sadece bu tur ertelenir, günün sayımı (yapılan/yapılamayan) bozulmaz.
            log.status = .partial
        } else {
            log.status = .postponed
            log.completedAt = nil
        }
        log.postponedUntil = until
        log.multiplier = m
        save()
        let snap = task.snapshot
        #if os(iOS)
        LiveActivityManager.start(task: snap, deadline: until, multiplier: m)
        #endif
        NotificationScheduler.shared.scheduleDeadline(for: snap, at: until, multiplier: m)
        Task { await NotificationScheduler.shared.reschedule() }
    }

    func skip(_ id: UUID) {
        guard let task = task(id) else { return }
        if task.repeatEveryMinutes > 0 { return stopToday(id) }
        let log = makeTodayLog(for: task)
        log.status = .skipped
        log.completedAt = nil
        log.postponedUntil = nil
        save()
        afterChange(id)
    }

    // MARK: - Aralıklı görev turları

    /// Bir tur yapıldı (+1). Hedefe ulaşınca ve tüm turlar bitince tebrik eder.
    func slotDone(_ id: UUID) {
        guard let task = task(id) else { return }
        let snap = task.snapshot
        let m = engine.penaltyMultiplier(snap, on: .now)
        let log = makeTodayLog(for: task)
        if log.status != .stopped { log.status = .partial }
        log.postponedUntil = nil
        log.doneCount += 1
        log.completedAt = .now
        log.multiplier = m
        save()
        let required = engine.requiredSlots(snap, on: .now)
        let total = engine.slotTimes(snap, on: .now).count
        if log.doneCount == total {
            NotificationScheduler.shared.sendMessage(Messages.slotAllDone(snap, total: total), for: snap)
        } else if log.doneCount == required {
            NotificationScheduler.shared.sendMessage(Messages.slotGoalReached(snap, done: log.doneCount, total: total), for: snap)
        }
        afterChange(id)
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }

    /// Bu tur yapılamadı.
    func slotMissed(_ id: UUID) {
        guard let task = task(id) else { return }
        let log = makeTodayLog(for: task)
        if log.status != .stopped { log.status = .partial }
        log.postponedUntil = nil
        log.missedCount += 1
        save()
        afterChange(id)
    }

    /// "Bugün daha fazla hatırlatma": bugünkü kalan turlar iptal.
    func stopToday(_ id: UUID) {
        guard let task = task(id) else { return }
        let log = makeTodayLog(for: task)
        log.status = .stopped
        save()
        afterChange(id)
    }

    /// Durdurulan aralıklı görevi bugün için tekrar başlatır.
    func resumeToday(_ id: UUID) {
        guard let task = task(id), let log = todayLog(for: task), log.status == .stopped else { return }
        log.status = .partial
        save()
        afterChange(id)
    }

    /// Bugünkü kaydı siler (yanlışlıkla "Yaptım" denirse).
    func undoToday(_ id: UUID) {
        guard let task = task(id), let log = todayLog(for: task) else { return }
        context.delete(log)
        save()
        afterChange(id)
    }

    func delete(_ task: ForceTask) {
        let id = task.id
        context.delete(task)
        save()
        afterChange(id)
    }

    func handle(actionIdentifier: String, taskID: UUID) {
        if let minutes = NotificationAction.postponeMinutes(from: actionIdentifier) {
            postpone(taskID, minutes: minutes)
            return
        }
        switch actionIdentifier {
        case NotificationAction.done: complete(taskID)
        case NotificationAction.skip: skip(taskID)
        case NotificationAction.slotMissed: slotMissed(taskID)
        case NotificationAction.stopToday: stopToday(taskID)
        default: break
        }
    }

    func save() {
        try? context.save()
    }

    private func afterChange(_ id: UUID) {
        #if os(iOS)
        LiveActivityManager.end(taskID: id.uuidString)
        #endif
        NotificationScheduler.shared.cancelDeadline(for: id)
        Task { await NotificationScheduler.shared.reschedule() }
    }
}
