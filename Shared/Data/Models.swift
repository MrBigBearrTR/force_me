import Foundation
import SwiftData

// CloudKit senkronu için: tüm alanlar varsayılan değerli, unique kısıt yok.

@Model
final class ForceTask {
    var id: UUID = UUID()
    var title: String = ""
    var icon: String = "checkmark.circle.fill"
    var colorHex: String = "#FF6B35"
    var quantity: Int = 0
    var unit: String = ""
    var recurrenceRaw: String = RecurrenceKind.daily.rawValue
    var weekdaysRaw: String = ""
    var monthDay: Int = 1
    var intervalDays: Int = 2
    var startDate: Date = Date()
    var windowStart: Int = 540
    var windowEnd: Int = 720
    /// >0: gün içinde her N dakikada bir tekrar.
    var repeatEveryMinutes: Int = 0
    var isActive: Bool = true
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TaskLog.task)
    var logs: [TaskLog]? = []

    init(title: String = "") {
        self.title = title
    }

    var recurrence: RecurrenceKind {
        get { RecurrenceKind(rawValue: recurrenceRaw) ?? .daily }
        set { recurrenceRaw = newValue.rawValue }
    }

    var weekdays: Set<Int> {
        get { Set(weekdaysRaw.split(separator: ",").compactMap { Int($0) }) }
        set { weekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",") }
    }

    var snapshot: TaskSnapshot {
        TaskSnapshot(
            id: id, title: title, icon: icon, colorHex: colorHex,
            quantity: quantity, unit: unit, recurrence: recurrence,
            weekdays: weekdays, monthDay: monthDay, intervalDays: intervalDays,
            startDate: startDate, windowStart: windowStart, windowEnd: windowEnd,
            repeatEveryMinutes: repeatEveryMinutes, isActive: isActive,
            logs: (logs ?? []).map(\.snapshot).sorted { $0.day < $1.day }
        )
    }
}

@Model
final class TaskLog {
    var id: UUID = UUID()
    var day: Date = Date()
    var statusRaw: String = LogStatus.done.rawValue
    var completedAt: Date?
    var postponedUntil: Date?
    var multiplier: Int = 1
    var doneCount: Int = 0
    var missedCount: Int = 0
    var task: ForceTask?

    init(day: Date) {
        self.day = day
    }

    var status: LogStatus {
        get { LogStatus(rawValue: statusRaw) ?? .done }
        set { statusRaw = newValue.rawValue }
    }

    var snapshot: LogSnapshot {
        LogSnapshot(day: day, status: status, completedAt: completedAt, postponedUntil: postponedUntil,
                    doneCount: doneCount, missedCount: missedCount)
    }
}
