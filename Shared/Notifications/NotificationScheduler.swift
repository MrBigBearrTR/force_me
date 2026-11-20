import Foundation
import UserNotifications

enum NotificationAction {
    static let done = "FORCE_DONE"
    static let postpone15 = "FORCE_POSTPONE_15"
    static let postpone30 = "FORCE_POSTPONE_30"
    static let skip = "FORCE_SKIP"
    static let slotMissed = "FORCE_SLOT_MISSED"
    static let stopToday = "FORCE_STOP_TODAY"
}

enum NotificationCategory {
    static let reminder = "FORCE_REMINDER"
    static let deadline = "FORCE_DEADLINE"
    static let interval = "FORCE_INTERVAL"
    /// Tebrikler: aksiyon yok, sadece açılınca kompakt kart gösterilsin diye.
    static let praise = "FORCE_PRAISE"
}

/// Cihaza özel ayarlar (senkronlanmaz: Mac'te kapatıp iPhone'da açık bırakabilirsin).
enum ForceSettings {
    static let notifyKey = "notifyOnDevice"
    static let soundKey = "soundOn"
    static let summaryKey = "summaryMinutes"

    #if os(watchOS)
    static let defaultNotify = false // Watch, iPhone bildirimlerini zaten aynalıyor.
    #else
    static let defaultNotify = true
    #endif

    static var notifyOnDevice: Bool { UserDefaults.standard.object(forKey: notifyKey) as? Bool ?? defaultNotify }
    static var soundOn: Bool { UserDefaults.standard.object(forKey: soundKey) as? Bool ?? true }
    static var summaryMinutes: Int { UserDefaults.standard.object(forKey: summaryKey) as? Int ?? 8 * 60 }
}

@MainActor
final class NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let engine = ScheduleEngine()
    /// Kaç gün ilerisi planlanır (iOS en fazla 64 bekleyen bildirim tutar).
    private let horizonDays = 4
    private let maxPending = 60

    // MARK: - Kurulum

    func registerCategories() {
        #if os(iOS)
        // Live Activity sadece ön planda başlatılabildiği için erteleme uygulamayı kısa süre açar.
        let postponeOptions: UNNotificationActionOptions = [.foreground]
        #else
        let postponeOptions: UNNotificationActionOptions = []
        #endif
        let done = UNNotificationAction(identifier: NotificationAction.done, title: "Yaptım ✅", options: [],
                                        icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        let p15 = UNNotificationAction(identifier: NotificationAction.postpone15, title: "15 dk ertele", options: postponeOptions,
                                       icon: UNNotificationActionIcon(systemImageName: "timer"))
        let p30 = UNNotificationAction(identifier: NotificationAction.postpone30, title: "30 dk ertele", options: postponeOptions,
                                       icon: UNNotificationActionIcon(systemImageName: "timer"))
        let skip = UNNotificationAction(identifier: NotificationAction.skip, title: "Bugün yapamam", options: [.destructive],
                                        icon: UNNotificationActionIcon(systemImageName: "xmark.circle"))
        // Aralıklı görev turları: uygulamayı açmadan arka planda işlenir.
        let missed = UNNotificationAction(identifier: NotificationAction.slotMissed, title: "Yapamadım", options: [],
                                          icon: UNNotificationActionIcon(systemImageName: "xmark"))
        let stop = UNNotificationAction(identifier: NotificationAction.stopToday, title: "Bugün daha fazla hatırlatma",
                                        options: [.destructive], icon: UNNotificationActionIcon(systemImageName: "bell.slash"))
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationCategory.reminder, actions: [done, p15, p30, skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationCategory.deadline, actions: [done, p15, skip], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationCategory.interval, actions: [done, missed, stop], intentIdentifiers: []),
            UNNotificationCategory(identifier: NotificationCategory.praise, actions: [], intentIdentifiers: []),
        ])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: - Yeniden planlama

    /// Tüm hatırlatmaları ve sabah özetlerini sıfırdan kurar. Her değişiklikten sonra çağrılır.
    func reschedule(now: Date = .now) async {
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix("reminder.") || $0.hasPrefix("summary.") }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        guard ForceSettings.notifyOnDevice else { return }

        let tasks = ForceStore.shared.allTasks().map(\.snapshot)
        let today = engine.startOfDay(now)
        // Normal görevler ve özetler önceliklidir; aralıklı turlar kalan kapasiteyi doldurur
        // (iOS en fazla 64 bekleyen bildirim tutar, 25 dk'lık turlar bunu hızla doldurur).
        // İçerik (ve ikon kopyası) sadece gerçekten planlanacak bildirimler için üretilir.
        typealias Pending = (fire: Date, make: () -> UNNotificationRequest)
        var requests: [Pending] = []
        var slotRequests: [Pending] = []

        for offset in 0..<horizonDays {
            let day = engine.addDays(offset, to: today)
            for task in tasks where engine.status(task, on: day).isOpen {
                let m = engine.penaltyMultiplier(task, on: day)
                if task.isRepeating {
                    let entry = engine.log(task, on: day)
                    let done = entry?.doneCount ?? 0
                    let required = engine.requiredSlots(task, on: day)
                    let slots = engine.slotTimes(task, on: day)
                    for (i, fire) in slots.enumerated() where fire > now {
                        let id = "reminder.\(task.id.uuidString).\(engine.dayKey(day)).\(i)"
                        slotRequests.append((fire, {
                            let text = Messages.slotReminder(task, multiplier: m, done: done, required: required, total: slots.count)
                            let content = self.makeContent(text, task: task, category: NotificationCategory.interval,
                                                           ring: m > 1 ? .penalty : .none, multiplier: m, kind: .interval,
                                                           progress: (done, required, slots.count))
                            return self.request(id, content, fire)
                        }))
                    }
                    continue
                }
                // Ertelenmiş görevin bugünkü hatırlatması geri sayım bildirimidir; burada atlanır.
                guard engine.status(task, on: day) == .pending else { continue }
                for (i, fire) in engine.reminderTimes(task, on: day).enumerated() where fire > now {
                    let id = "reminder.\(task.id.uuidString).\(engine.dayKey(day)).\(i)"
                    requests.append((fire, {
                        let text = Messages.reminder(task, multiplier: m, followUp: i > 0)
                        let content = self.makeContent(text, task: task, category: NotificationCategory.reminder,
                                                       ring: m > 1 ? .penalty : .none, multiplier: m, kind: .reminder)
                        content.relevanceScore = m > 1 ? 1.0 : 0.6
                        return self.request(id, content, fire)
                    }))
                }
            }
        }

        // Sabah özeti: bugün (saati geçmediyse) ve yarın. Yarınki, bugünün sonuçlarıyla güncellenir.
        if !tasks.isEmpty {
            for offset in 0...1 {
                let day = engine.addDays(offset, to: today)
                let fire = day.addingTimeInterval(TimeInterval(ForceSettings.summaryMinutes * 60))
                guard fire > now else { continue }
                let stats = engine.dayStats(tasks, on: engine.addDays(-1, to: day))
                let id = "summary.\(engine.dayKey(day))"
                requests.append((fire, {
                    let text = Messages.morning(done: stats.done, total: stats.total)
                    let content = UNMutableNotificationContent()
                    content.title = text.title
                    content.body = text.body
                    content.sound = ForceSettings.soundOn ? .default : nil
                    content.threadIdentifier = "summary"
                    return self.request(id, content, fire)
                }))
            }
        }

        let primary = Array(requests.sorted { $0.fire < $1.fire }.prefix(maxPending))
        let filler = slotRequests.sorted { $0.fire < $1.fire }.prefix(maxPending - primary.count)
        for item in primary + filler {
            try? await center.add(item.make())
        }
    }

    // MARK: - Erteleme geri sayımı

    func scheduleDeadline(for task: TaskSnapshot, at deadline: Date, multiplier m: Int) {
        cancelDeadline(for: task.id, clearDelivered: false)
        // Son bildirim süre bittiğinde gelir: kartta geri sayım değil "Süre doldu" yazsın.
        let end = makeContent(Messages.deadline(task, multiplier: m), task: task,
                              category: NotificationCategory.deadline, ring: .postponed, multiplier: m,
                              kind: .deadline, deadline: nil)
        center.add(request("deadline.\(task.id.uuidString)", end, deadline))

        let warnAt = deadline.addingTimeInterval(-60)
        if warnAt.timeIntervalSinceNow > 30 {
            let warn = makeContent(Messages.lastMinute(task, multiplier: m), task: task,
                                   category: NotificationCategory.deadline, ring: .postponed, multiplier: m,
                                   kind: .deadline, deadline: deadline)
            center.add(request("deadline.\(task.id.uuidString).warn", warn, warnAt))
        }
    }

    func cancelDeadline(for id: UUID, clearDelivered: Bool = true) {
        center.removePendingNotificationRequests(withIdentifiers: ["deadline.\(id.uuidString)", "deadline.\(id.uuidString).warn"])
        guard clearDelivered else { return }
        // Görev kapandıysa bildirim merkezindeki eski hatırlatmaları da temizle.
        center.getDeliveredNotifications { [center] delivered in
            let ids = delivered.filter { $0.request.content.threadIdentifier == id.uuidString }.map(\.request.identifier)
            center.removeDeliveredNotifications(withIdentifiers: ids)
        }
    }

    // MARK: - Tebrik / test

    func sendPraise(for task: TaskSnapshot, multiplier m: Int) {
        guard ForceSettings.notifyOnDevice else { return }
        let text = Messages.praise(task, multiplier: m)
        let content = makeContent(text, task: task, category: NotificationCategory.praise, ring: .done, multiplier: 1, kind: .praise)
        content.sound = Self.sound("force_praise.wav")
        content.interruptionLevel = .active
        content.threadIdentifier = "praise"
        center.add(UNNotificationRequest(identifier: "praise.\(UUID().uuidString)", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    /// Aralıklı görev kilometre taşları ("Günü kurtardın!").
    func sendMessage(_ text: Messages.Text, for task: TaskSnapshot) {
        guard ForceSettings.notifyOnDevice else { return }
        let content = makeContent(text, task: task, category: NotificationCategory.praise, ring: .done, multiplier: 1, kind: .praise)
        content.sound = Self.sound("force_praise.wav")
        content.interruptionLevel = .active
        content.threadIdentifier = "praise"
        center.add(UNNotificationRequest(identifier: "praise.\(UUID().uuidString)", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }

    func sendTest(for task: TaskSnapshot?) {
        let sample = task ?? TaskSnapshot(title: "10 şınav çek", icon: "figure.strengthtraining.traditional", quantity: 10, unit: "şınav")
        let content = makeContent(Messages.reminder(sample, multiplier: 1, followUp: false), task: sample,
                                  category: NotificationCategory.reminder, ring: .none, multiplier: 1, kind: .reminder)
        center.add(UNNotificationRequest(identifier: "test.\(UUID().uuidString)", content: content,
                                         trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)))
    }

    // MARK: - Yardımcılar

    private func makeContent(_ text: Messages.Text, task: TaskSnapshot, category: String,
                             ring: RingStyle, multiplier: Int, kind: NotificationCardData.Kind,
                             progress: (done: Int, required: Int, total: Int)? = nil,
                             deadline: Date? = nil) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = Self.sound("force_alarm.wav")
        content.categoryIdentifier = category
        let card = NotificationCardData(kind: kind, title: text.title, body: text.body, taskTitle: task.title,
                                        icon: task.icon, colorHex: task.colorHex, ring: ring, multiplier: multiplier,
                                        goal: task.goalText(multiplier: multiplier), progress: progress, deadline: deadline)
        content.userInfo = ["taskID": task.id.uuidString, NotificationCardData.key: card.dictionary]
        content.threadIdentifier = task.id.uuidString
        content.interruptionLevel = .timeSensitive
        if let attachment = IconRenderer.attachment(icon: task.icon, colorHex: task.colorHex, ring: ring, multiplier: multiplier) {
            content.attachments = [attachment]
        }
        return content
    }

    private static func sound(_ file: String) -> UNNotificationSound? {
        guard ForceSettings.soundOn else { return nil }
        #if os(watchOS)
        return .default
        #else
        return UNNotificationSound(named: UNNotificationSoundName(file))
        #endif
    }

    private func request(_ id: String, _ content: UNNotificationContent, _ fire: Date) -> UNNotificationRequest {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fire)
        return UNNotificationRequest(identifier: id, content: content,
                                     trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false))
    }
}

/// Bildirim aksiyonlarını (Yaptım / Ertele / Bugün yapamam) yakalar.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        let action = response.actionIdentifier
        guard let raw = response.notification.request.content.userInfo["taskID"] as? String,
              let id = UUID(uuidString: raw) else {
            completionHandler()
            return
        }
        Task { @MainActor in
            ForceStore.shared.handle(actionIdentifier: action, taskID: id)
            await NotificationScheduler.shared.reschedule()
            completionHandler()
        }
    }
}
