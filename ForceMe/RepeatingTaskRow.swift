import SwiftUI

/// Gün içinde aralıklı tekrar eden görevin satırı (örn. 08–18 arası 25 dk'da bir 1 dk yürüyüş).
struct RepeatingTaskRow: View {
    let snap: TaskSnapshot
    let now: Date
    private let engine = ScheduleEngine()
    private var store: ForceStore { ForceStore.shared }

    var body: some View {
        let status = engine.status(snap, on: now)
        let m = engine.penaltyMultiplier(snap, on: now)
        let total = engine.slotTimes(snap, on: now).count
        let required = engine.requiredSlots(snap, on: now)
        let done = engine.log(snap, on: now)?.doneCount ?? 0
        let missed = engine.log(snap, on: now)?.missedCount ?? 0
        let success = done >= required

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                TaskIconView(icon: snap.icon, color: snap.tint,
                             ring: success ? .done : (m > 1 ? .penalty : .none),
                             multiplier: success ? 1 : m, size: 50)
                VStack(alignment: .leading, spacing: 3) {
                    Text(snap.title).font(.headline)
                    Text("Her tur: \(snap.goalText(multiplier: m)) · \(snap.repeatEveryMinutes) dk'da bir")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(m > 1 && !success ? .red : .secondary)
                    Text("✅ \(done)  ❌ \(missed)  ·  hedef \(required)/\(total)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(success ? .green : .secondary)
                    infoLine(status)
                }
                Spacer(minLength: 0)
            }

            ProgressView(value: Double(min(done, total)), total: Double(max(total, 1))) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(success ? .green : snap.tint)
            .overlay(alignment: .leading) {
                // Hedef çizgisi
                GeometryReader { geo in
                    Rectangle().fill(.primary.opacity(0.5))
                        .frame(width: 2, height: 10)
                        .offset(x: geo.size.width * Double(required) / Double(max(total, 1)) - 1, y: -3)
                }
                .frame(height: 4)
            }

            if case .stopped = status {
                Button("Devam et") { store.resumeToday(snap.id) }
                    .font(.footnote)
                    .buttonStyle(.borderless)
            } else {
                HStack(spacing: 10) {
                    Button { store.slotDone(snap.id) } label: {
                        ActionLabel(title: "Yaptım", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button { store.slotMissed(snap.id) } label: {
                        ActionLabel(title: "Yapamadım", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 8)

                    Button(role: .destructive) { store.stopToday(snap.id) } label: {
                        Text("Bugün yeter")
                            .font(.footnote)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func infoLine(_ status: DayStatus) -> some View {
        if case .stopped = status {
            Text("Bugün daha fazla hatırlatmıyorum.")
                .font(.caption).foregroundStyle(.orange)
        } else if let next = engine.nextSlot(snap, after: now) {
            Text("Sıradaki tur \(next.formatted(date: .omitted, time: .shortened))")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Bugünkü turlar bitti.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
