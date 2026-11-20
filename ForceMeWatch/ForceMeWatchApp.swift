import SwiftUI
import SwiftData

@main
struct ForceMeWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchTodayView()
                #if DEBUG
                .task { DemoData.seedIfRequested() }
                #endif
        }
        .modelContainer(ForceStore.shared.container)
    }
}

struct WatchTodayView: View {
    @Query(sort: \ForceTask.createdAt) private var tasks: [ForceTask]
    private let engine = ScheduleEngine()

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { context in
                let now = context.date
                let items = tasks.map(\.snapshot).filter { engine.status($0, on: now) != .notScheduled }
                List {
                    if items.isEmpty {
                        Text("Bugün görev yok 🎉").foregroundStyle(.secondary)
                    }
                    ForEach(items, id: \.id) { snap in
                        NavigationLink {
                            WatchTaskDetail(snap: snap)
                        } label: {
                            WatchRow(snap: snap, now: now)
                        }
                    }
                }
            }
            .navigationTitle("Bugün")
        }
    }
}

private struct WatchRow: View {
    let snap: TaskSnapshot
    let now: Date
    private let engine = ScheduleEngine()

    var body: some View {
        let status = engine.status(snap, on: now)
        let m = engine.penaltyMultiplier(snap, on: now)
        HStack(spacing: 8) {
            TaskIconView(icon: snap.icon, color: snap.tint,
                         ring: engine.isSuccess(snap, on: now) ? .done : (m > 1 ? .penalty : .none),
                         multiplier: status.isOpen ? m : 1, size: 26)
            VStack(alignment: .leading) {
                Text(snap.title).lineLimit(1)
                switch status {
                case .inProgress(let done, _):
                    Text("\(done)/\(engine.requiredSlots(snap, on: now)) tur")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                case .stopped(let done):
                    Text("Durduruldu · \(done) tur").font(.caption2).foregroundStyle(.orange)
                case .postponed(let until) where until > now:
                    Text(timerInterval: now...until, countsDown: true)
                        .font(.caption2.monospacedDigit()).foregroundStyle(.orange)
                case .done:
                    Text("Tamam ✅").font(.caption2).foregroundStyle(.green)
                case .skipped:
                    Text("Pas geçildi").font(.caption2).foregroundStyle(.red)
                default:
                    Text(snap.goalText(multiplier: m)).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct WatchTaskDetail: View {
    let snap: TaskSnapshot
    @Environment(\.dismiss) private var dismiss
    private let engine = ScheduleEngine()

    var body: some View {
        let m = engine.penaltyMultiplier(snap, on: .now)
        ScrollView {
            VStack(spacing: 10) {
                TaskIconView(icon: snap.icon, color: snap.tint, ring: m > 1 ? .penalty : .none, multiplier: m, size: 48)
                Text(snap.goalText(multiplier: m)).font(.headline).multilineTextAlignment(.center)
                if snap.isRepeating {
                    Button {
                        ForceStore.shared.slotDone(snap.id)
                        dismiss()
                    } label: {
                        Label("Yaptım", systemImage: "plus")
                    }
                    .tint(.green)
                    let snooze = engine.postponeOptions(snap)[0]
                    Button {
                        ForceStore.shared.postpone(snap.id, minutes: snooze)
                        dismiss()
                    } label: {
                        Label("\(snooze) dk ertele", systemImage: "timer")
                    }
                    Button {
                        ForceStore.shared.slotMissed(snap.id)
                        dismiss()
                    } label: {
                        Label("Yapamadım", systemImage: "xmark")
                    }
                    Button(role: .destructive) {
                        ForceStore.shared.stopToday(snap.id)
                        dismiss()
                    } label: {
                        Text("Bugün daha fazla hatırlatma")
                    }
                } else {
                    singleActions
                }
            }
        }
        .navigationTitle(snap.title)
    }

    @ViewBuilder
    private var singleActions: some View {
        Button {
            ForceStore.shared.complete(snap.id)
            dismiss()
        } label: {
            Label("Yaptım", systemImage: "checkmark")
        }
        .tint(.green)
        Button {
            ForceStore.shared.postpone(snap.id, minutes: 5)
            dismiss()
        } label: {
            Label("5 dk ertele", systemImage: "timer")
        }
        Button(role: .destructive) {
            ForceStore.shared.skip(snap.id)
            dismiss()
        } label: {
            Text("Bugün yapamam")
        }
    }
}
