import SwiftUI
import SwiftData

struct TasksView: View {
    @Query(sort: \ForceTask.createdAt) private var tasks: [ForceTask]
    @State private var editing: ForceTask?
    @State private var creating = false
    private let engine = ScheduleEngine()

    var body: some View {
        NavigationStack {
            List {
                if tasks.isEmpty {
                    ContentUnavailableView("Henüz görev yok", systemImage: "flame",
                                           description: Text("Sağ üstteki + ile ilk görevini ekle. Örn: Diş fırçala, 09:00–12:00."))
                }
                ForEach(tasks) { task in
                    let snap = task.snapshot
                    let m = engine.penaltyMultiplier(snap, on: .now)
                    Button { editing = task } label: {
                        HStack(spacing: 14) {
                            TaskIconView(icon: snap.icon, color: snap.tint, ring: m > 1 ? .penalty : .none,
                                         multiplier: m, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snap.title).font(.headline).foregroundStyle(.primary)
                                Text(describe(snap)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !snap.isActive {
                                Image(systemName: "pause.circle").foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    offsets.map { tasks[$0] }.forEach(ForceStore.shared.delete)
                }
            }
            .navigationTitle("Görevler")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { creating = true } label: { Label("Yeni görev", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $creating) { TaskEditorView(task: nil) }
            .sheet(item: $editing) { TaskEditorView(task: $0) }
            #if DEBUG
            .task {
                // DEBUG: `-editRepeating` ile gün içi tekrar eden ilk görevin düzenleyicisi açılır (ekran görüntüsü için).
                if ProcessInfo.processInfo.arguments.contains("-editRepeating") {
                    editing = tasks.first { $0.repeatEveryMinutes > 0 }
                }
            }
            #endif
        }
    }

    private func describe(_ t: TaskSnapshot) -> String {
        let window = engine.effectiveWindow(t)
        let when: String
        switch t.recurrence {
        case .once: when = "Tek sefer · \(t.startDate.formatted(date: .abbreviated, time: .omitted))"
        case .daily: when = "Her gün"
        case .weekly:
            let names = Weekday.ordered.filter { t.weekdays.contains($0.value) }.map(\.short)
            when = names.isEmpty ? "Haftalık" : names.joined(separator: ", ")
        case .monthly: when = "Her ayın \(t.monthDay). günü"
        case .interval: when = "\(t.intervalDays) günde bir"
        }
        if t.isRepeating {
            return "\(when) · \(window.label) · \(t.repeatEveryMinutes) dk'da bir"
        }
        return "\(when) · \(window.label)\(window.learned ? " (öğrenildi)" : "")"
    }
}

enum Weekday {
    /// Pazartesi'den başlayan sıra (Calendar weekday değerleri).
    static let ordered: [(value: Int, short: String)] = [
        (2, "Pzt"), (3, "Sal"), (4, "Çar"), (5, "Per"), (6, "Cum"), (7, "Cmt"), (1, "Paz"),
    ]
}
