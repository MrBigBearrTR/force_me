import XCTest

final class ScheduleEngineTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private lazy var engine = ScheduleEngine(calendar: cal)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    private func done(_ day: Date, at hour: Int, _ minute: Int) -> LogSnapshot {
        LogSnapshot(day: cal.startOfDay(for: day), status: .done,
                    completedAt: cal.date(bySettingHour: hour, minute: minute, second: 0, of: day))
    }

    // MARK: Tekrar

    func testDailyOccursFromStartDate() {
        let t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 10))
        XCTAssertFalse(engine.occurs(t, on: date(2026, 11, 9)))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 10)))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 25)))
    }

    func testWeeklyUsesSelectedWeekdays() {
        // 2026-11-16 Pazartesi
        let t = TaskSnapshot(recurrence: .weekly, weekdays: [2, 4], startDate: date(2026, 11, 1))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 16)))
        XCTAssertFalse(engine.occurs(t, on: date(2026, 11, 17)))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 18)))
    }

    func testMonthlyClampsToLastDay() {
        let t = TaskSnapshot(recurrence: .monthly, monthDay: 31, startDate: date(2026, 1, 1))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 2, 28)))
        XCTAssertFalse(engine.occurs(t, on: date(2026, 2, 27)))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 3, 31)))
    }

    func testIntervalEveryThreeDays() {
        let t = TaskSnapshot(recurrence: .interval, intervalDays: 3, startDate: date(2026, 11, 1))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 1)))
        XCTAssertFalse(engine.occurs(t, on: date(2026, 11, 2)))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 4)))
    }

    func testOnceCarriesOverUntilDone() {
        var t = TaskSnapshot(recurrence: .once, startDate: date(2026, 11, 10))
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 12)), "yapılmayan tek seferlik görev peşini bırakmaz")
        t.logs = [done(date(2026, 11, 12), at: 10, 0)]
        XCTAssertTrue(engine.occurs(t, on: date(2026, 11, 12)))
        XCTAssertFalse(engine.occurs(t, on: date(2026, 11, 13)))
    }

    // MARK: Ceza

    func testPenaltyDoublesAfterOneMissedDay() {
        var t = TaskSnapshot(quantity: 10, unit: "şınav", recurrence: .daily, startDate: date(2026, 11, 1))
        t.logs = [done(date(2026, 11, 18), at: 10, 0)]
        // 19'u kaçırdı → 20'sinde x2
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 20)), 2)
        XCTAssertEqual(t.goalText(multiplier: 2), "20 şınav")
        // 19 ve 20 kaçtı → 21'inde x3
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 21)), 3)
    }

    func testSkippedCountsAsMissed() {
        var t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 19))
        t.logs = [LogSnapshot(day: date(2026, 11, 19), status: .skipped)]
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 20)), 2)
    }

    func testNoPenaltyWhenYesterdayDone() {
        var t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1))
        t.logs = [done(date(2026, 11, 19), at: 9, 30)]
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 20)), 1)
    }

    func testWeeklyPenaltyIgnoresOffDays() {
        // Pzt + Çar; Pzt yapıldı, Çar kaçtı → Perşembe değil, sonraki Pzt x2
        var t = TaskSnapshot(recurrence: .weekly, weekdays: [2, 4], startDate: date(2026, 11, 1))
        t.logs = [done(date(2026, 11, 16), at: 10, 0)]
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 23)), 2)
    }

    // MARK: Aralık ve rastgele saat

    func testReminderIsInsideWindowAndStable() {
        let t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1), windowStart: 540, windowEnd: 720)
        for d in 1...30 {
            let day = date(2026, 11, d)
            guard let first = engine.reminderTimes(t, on: day).first else { return XCTFail() }
            let minute = engine.minuteOfDay(first)
            XCTAssert((540...720).contains(minute), "\(minute) aralık dışında")
            XCTAssertEqual(engine.reminderTimes(t, on: day).first, first, "aynı gün için saat sabit olmalı")
        }
    }

    func testReminderTimeVariesAcrossDays() {
        let t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1), windowStart: 540, windowEnd: 720)
        let minutes = Set((1...14).compactMap { engine.reminderTimes(t, on: date(2026, 11, $0)).first.map(engine.minuteOfDay) })
        XCTAssertGreaterThan(minutes.count, 7, "her gün aynı saatte gelmemeli")
    }

    func testLearnsHabitWindow() {
        var t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1), windowStart: 540, windowEnd: 720)
        t.logs = [
            done(date(2026, 11, 10), at: 11, 5), done(date(2026, 11, 11), at: 11, 12),
            done(date(2026, 11, 12), at: 11, 20), done(date(2026, 11, 13), at: 11, 28),
            done(date(2026, 11, 14), at: 11, 15), done(date(2026, 11, 15), at: 11, 0),
        ]
        let w = engine.effectiveWindow(t)
        XCTAssertTrue(w.learned)
        XCTAssertGreaterThanOrEqual(w.start, 11 * 60)
        XCTAssertLessThanOrEqual(w.end, 11 * 60 + 30)
        for d in 16...25 {
            let m = engine.minuteOfDay(engine.reminderTimes(t, on: date(2026, 11, d)).first!)
            XCTAssert((w.start...w.end).contains(m))
        }
    }

    func testNeedsThreeSamplesToLearn() {
        var t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1), windowStart: 540, windowEnd: 720)
        t.logs = [done(date(2026, 11, 10), at: 11, 5), done(date(2026, 11, 11), at: 11, 12)]
        XCTAssertFalse(engine.effectiveWindow(t).learned)
    }

    func testPenaltyAddsFollowUpReminders() {
        let t = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 18))
        // 18 ve 19 kaçtı → 20'sinde x3 → 3 hatırlatma, 20 dk arayla
        let times = engine.reminderTimes(t, on: date(2026, 11, 20))
        XCTAssertEqual(times.count, 3)
        XCTAssertEqual(times[1].timeIntervalSince(times[0]), 20 * 60)
    }

    // MARK: Özet

    func testDayStatsAndMorningMessage() {
        var a = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1))
        a.logs = [done(date(2026, 11, 19), at: 10, 0)]
        let b = TaskSnapshot(recurrence: .daily, startDate: date(2026, 11, 1))
        let stats = engine.dayStats([a, b], on: date(2026, 11, 19))
        XCTAssertEqual(stats.done, 1)
        XCTAssertEqual(stats.total, 2)
        XCTAssertTrue(Messages.summary(done: 2, total: 2).contains("Aynı performansı"))
    }
}

// MARK: - Gün içi aralıklı tekrar

final class RepeatingTaskTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        return c
    }()
    private lazy var engine = ScheduleEngine(calendar: cal)

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// 08:00–18:00 arası 25 dk'da bir 1 dk yürüyüş.
    private func walk(logs: [LogSnapshot] = []) -> TaskSnapshot {
        TaskSnapshot(title: "Yürüyüş", quantity: 1, unit: "dk yürüyüş", recurrence: .daily,
                     startDate: date(2026, 11, 1), windowStart: 8 * 60, windowEnd: 18 * 60,
                     repeatEveryMinutes: 25, logs: logs)
    }

    private func partial(_ day: Date, done: Int, missed: Int = 0, status: LogStatus = .partial) -> LogSnapshot {
        LogSnapshot(day: cal.startOfDay(for: day), status: status, doneCount: done, missedCount: missed)
    }

    func testSlotsEvery25MinutesInsideWindow() {
        let slots = engine.slotTimes(walk(), on: date(2026, 11, 20))
        XCTAssertEqual(slots.count, 25) // 08:00, 08:25 … 18:00
        XCTAssertEqual(engine.minuteOfDay(slots.first!), 8 * 60)
        XCTAssertEqual(engine.minuteOfDay(slots[1]), 8 * 60 + 25)
        XCTAssertEqual(engine.minuteOfDay(slots.last!), 18 * 60)
        XCTAssertEqual(engine.reminderTimes(walk(), on: date(2026, 11, 20)), slots, "aralıklı görevde rastgele saat yok")
    }

    func testRequiredIsHalfRoundedUp() {
        XCTAssertEqual(engine.requiredSlots(walk(), on: date(2026, 11, 20)), 13)
    }

    func testStatusTracksProgressAndStop() {
        let today = date(2026, 11, 20)
        XCTAssertEqual(engine.status(walk(), on: today), .pending)
        XCTAssertEqual(engine.status(walk(logs: [partial(today, done: 3, missed: 1)]), on: today), .inProgress(done: 3, missed: 1))
        XCTAssertTrue(engine.status(walk(logs: [partial(today, done: 3)]), on: today).isOpen)
        let stopped = walk(logs: [partial(today, done: 5, status: .stopped)])
        XCTAssertEqual(engine.status(stopped, on: today), .stopped(done: 5))
        XCTAssertFalse(engine.status(stopped, on: today).isOpen)
    }

    func testPenaltyWhenYesterdayBelowTarget() {
        // 18'inde hedef tuttu (13), 19'unda 12'de kaldı → 20'sinde x2
        let t = walk(logs: [partial(date(2026, 11, 18), done: 13), partial(date(2026, 11, 19), done: 12)])
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 20)), 2)
        XCTAssertEqual(t.goalText(multiplier: 2), "2 dk yürüyüş")
    }

    func testNoPenaltyWhenTargetMetEvenIfStoppedEarly() {
        let t = walk(logs: [partial(date(2026, 11, 19), done: 13, status: .stopped)])
        XCTAssertEqual(engine.penaltyMultiplier(t, on: date(2026, 11, 20)), 1)
        XCTAssertEqual(engine.dayStats([t], on: date(2026, 11, 19)).done, 1)
    }

    func testNextSlot() {
        let next = engine.nextSlot(walk(), after: date(2026, 11, 20, 10, 3))
        XCTAssertEqual(next.map(engine.minuteOfDay), 10 * 60 + 5) // 08:00 + 5×25 = 10:05
        XCTAssertNil(engine.nextSlot(walk(), after: date(2026, 11, 20, 18, 1)))
    }

    func testNoHabitLearningForRepeating() {
        var t = walk()
        t.logs = (10...15).map { LogSnapshot(day: date(2026, 11, $0), status: .partial,
                                             completedAt: date(2026, 11, $0, 11, 10), doneCount: 13) }
        XCTAssertFalse(engine.effectiveWindow(t).learned)
    }
}
