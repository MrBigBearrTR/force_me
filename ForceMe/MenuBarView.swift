#if os(macOS)
import SwiftUI
import SwiftData

/// Mac menü çubuğu: bugünün açık görevleri ve erteleme geri sayımları.
struct MenuBarView: View {
    @Query(sort: \ForceTask.createdAt) private var tasks: [ForceTask]
    @Environment(\.openWindow) private var openWindow
    private let engine = ScheduleEngine()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let now = context.date
            let open = tasks.map(\.snapshot).filter { engine.status($0, on: now).isOpen }
            VStack(alignment: .leading, spacing: 12) {
                Text(open.isEmpty ? "Bugün her şey tamam 🎉" : "Bekleyen \(open.count) görev")
                    .font(.headline)
                ForEach(open, id: \.id) { snap in
                    let m = engine.penaltyMultiplier(snap, on: now)
                    HStack(spacing: 10) {
                        TaskIconView(icon: snap.icon, color: snap.tint, ring: m > 1 ? .penalty : .none, multiplier: m, size: 28)
                        VStack(alignment: .leading) {
                            Text(snap.title)
                            if case .postponed(let until) = engine.status(snap, on: now), until > now {
                                Text(timerInterval: now...until, countsDown: true)
                                    .font(.caption.monospacedDigit()).foregroundStyle(.orange)
                            } else if snap.quantity > 0 || m > 1 {
                                Text(snap.goalText(multiplier: m)).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Button("Yaptım") { ForceStore.shared.complete(snap.id) }
                            .buttonStyle(.borderedProminent).tint(.green)
                    }
                }
                Divider()
                Button("ForceMe'yi aç") {
                    openWindow(id: "main")
                    NSApp.activate()
                }
            }
            .padding()
            .frame(width: 320)
        }
    }
}
#endif
