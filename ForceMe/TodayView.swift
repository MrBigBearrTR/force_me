import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \ForceTask.createdAt) private var tasks: [ForceTask]
    private let engine = ScheduleEngine()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                let items = todayItems(now: now)
                List {
                    Section {
                        SummaryCard(tasks: tasks.map(\.snapshot), now: now)
                    }
                    Section("Bugünün görevleri") {
                        if items.isEmpty {
                            ContentUnavailableView("Bugün boşsun", systemImage: "sparkles",
                                                   description: Text("Görevler sekmesinden yeni bir görev ekle."))
                        }
                        ForEach(items, id: \.task.id) { item in
                            TodayRow(task: item.task, snap: item.snap, now: now)
                        }
                    }
                }
            }
            .navigationTitle("Bugün")
        }
    }

    private func todayItems(now: Date) -> [(task: ForceTask, snap: TaskSnapshot, open: Bool)] {
        tasks
            .map { ($0, $0.snapshot) }
            .compactMap { task, snap in
                let s = engine.status(snap, on: now)
                return s == .notScheduled ? nil : (task, snap, s.isOpen)
            }
            .sorted { $0.open && !$1.open }
    }
}

private struct SummaryCard: View {
    let tasks: [TaskSnapshot]
    let now: Date
    private let engine = ScheduleEngine()

    var body: some View {
        let today = engine.dayStats(tasks, on: now)
        let yesterday = engine.dayStats(tasks, on: engine.addDays(-1, to: now))
        HStack(spacing: 16) {
            Gauge(value: Double(today.done), in: 0...Double(max(today.total, 1))) {
                EmptyView()
            } currentValueLabel: {
                Text("\(today.done)/\(today.total)").font(.headline.monospacedDigit())
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(today.done == today.total && today.total > 0 ? .green : .orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(greeting).font(.headline)
                Text(Messages.summary(done: yesterday.done, total: yesterday.total))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: now) {
        case 5..<12: "Günaydın ☀️"
        case 12..<18: "Tünaydın 🌤️"
        default: "İyi akşamlar 🌙"
        }
    }
}

struct TodayRow: View {
    let task: ForceTask
    let snap: TaskSnapshot
    let now: Date
    private let engine = ScheduleEngine()
    private var store: ForceStore { ForceStore.shared }

    var body: some View {
        if snap.isRepeating {
            RepeatingTaskRow(snap: snap, now: now)
        } else {
            singleRow
        }
    }

    private var singleRow: some View {
        let status = engine.status(snap, on: now)
        let m = engine.penaltyMultiplier(snap, on: now)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                TaskIconView(icon: snap.icon, color: snap.tint, ring: ring(status, m),
                             multiplier: status.isOpen ? m : 1, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(snap.title).font(.headline)
                    if snap.quantity > 0 || m > 1 {
                        Text(snap.goalText(multiplier: status.isOpen ? m : 1))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(m > 1 && status.isOpen ? .red : .secondary)
                    }
                    statusLine(status, m)
                }
                Spacer(minLength: 0)
            }

            if status.isOpen {
                HStack(spacing: 10) {
                    Button { store.complete(snap.id) } label: {
                        ActionLabel(title: "Yaptım", systemImage: "checkmark")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Menu {
                        ForEach([5, 15, 30, 60], id: \.self) { minutes in
                            Button("\(minutes) dk ertele") { store.postpone(snap.id, minutes: minutes) }
                        }
                    } label: {
                        ActionLabel(title: "Ertele", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 8)

                    Button(role: .destructive) { store.skip(snap.id) } label: {
                        Text("Bugün yapamam")
                            .font(.footnote)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Button("Geri al") { store.undoToday(snap.id) }
                    .font(.footnote)
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }

    private func ring(_ status: DayStatus, _ m: Int) -> RingStyle {
        switch status {
        case .done: .done
        case .postponed: .postponed
        case .skipped, .stopped: .penalty
        case .pending, .inProgress: m > 1 ? .penalty : .none
        case .notScheduled: .none
        }
    }

    @ViewBuilder
    private func statusLine(_ status: DayStatus, _ m: Int) -> some View {
        switch status {
        case .pending:
            let w = engine.effectiveWindow(snap)
            Text(w.learned ? "Alışkanlığına göre \(w.label) arası hatırlatılacak"
                           : "\(w.label) arası rastgele bir saatte hatırlatılacak")
                .font(.caption).foregroundStyle(.secondary)
        case .postponed(let until):
            if until > now {
                HStack(spacing: 4) {
                    Image(systemName: "hourglass")
                    Text("Son ")
                    + Text(timerInterval: now...until, countsDown: true)
                }
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(.orange)
            } else {
                Text("Süre doldu! Hâlâ bekliyorum.").font(.caption.weight(.semibold)).foregroundStyle(.red)
            }
        case .done(let at):
            Text("✅ \(at.map { $0.formatted(date: .omitted, time: .shortened) } ?? "")'de yapıldı")
                .font(.caption).foregroundStyle(.green)
        case .skipped:
            Text("Bugün pas geçtin — yarın cezalısın (x\(m + 1))")
                .font(.caption).foregroundStyle(.red)
        case .notScheduled, .inProgress, .stopped:
            EmptyView()
        }
    }
}

/// Liste satırındaki aksiyon butonlarının tek satırlık etiketi.
struct ActionLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
        }
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }
}
