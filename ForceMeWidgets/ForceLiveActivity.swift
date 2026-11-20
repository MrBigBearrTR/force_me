import SwiftUI
import WidgetKit
import ActivityKit
import AppIntents

@main
struct ForceMeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ForceLiveActivity()
    }
}

/// Ertelenen görevin geri sayımı: kilit ekranı + Dynamic Island.
struct ForceLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ForceActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.75))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = Color(hex: context.attributes.colorHex)
            return DynamicIsland {
                // Basılı tutunca: solda ikon (boşalan halka içinde), sağda süre, altta görev adı.
                DynamicIslandExpandedRegion(.leading) {
                    CountdownRing(context: context, size: 58, lineWidth: 5)
                        .padding(.leading, 4)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(context: context)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.6)
                        .padding(.trailing, 4)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text(context.attributes.title)
                                .font(.headline)
                                .lineLimit(1)
                            if context.state.multiplier > 1 {
                                Text("x\(context.state.multiplier)")
                                    .font(.caption.weight(.heavy))
                                    .padding(.horizontal, 6)
                                    .background(Capsule().fill(.red))
                            }
                            Spacer(minLength: 0)
                            Text(context.state.goal)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        CountdownBar(context: context)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                // Solda ikon ve etrafında geriye doğru boşalan halka.
                CountdownRing(context: context, size: 26, lineWidth: 3)
            } compactTrailing: {
                // Sağ taraf bilerek boş: süre metni yok, sadece halka.
                EmptyView()
            } minimal: {
                CountdownRing(context: context, size: 24, lineWidth: 3)
            }
            .keylineTint(tint)
        }
    }
}

/// Geriye doğru boşalan halka + ortada görev ikonu. Halka sistemin zamanlayıcısıyla
/// kendiliğinden akar; uygulamanın çalışmasına gerek yoktur.
private struct CountdownRing: View {
    let context: ActivityViewContext<ForceActivityAttributes>
    let size: CGFloat
    let lineWidth: CGFloat

    var body: some View {
        let tint = context.state.multiplier > 1 ? Color.red : Color(hex: context.attributes.colorHex)
        ZStack {
            Circle()
                .stroke(tint.opacity(0.25), lineWidth: lineWidth)
            if context.state.deadline > context.state.startedAt {
                ProgressView(timerInterval: context.state.startedAt...context.state.deadline, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .progressViewStyle(.circular)
                .tint(tint)
            }
            Image(systemName: context.attributes.icon)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Genişletilmiş görünümün altında boşalan ince çizgi.
private struct CountdownBar: View {
    let context: ActivityViewContext<ForceActivityAttributes>

    var body: some View {
        let tint = context.state.multiplier > 1 ? Color.red : Color(hex: context.attributes.colorHex)
        if context.state.deadline > context.state.startedAt {
            ProgressView(timerInterval: context.state.startedAt...context.state.deadline, countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(tint)
        }
    }
}

private struct CountdownText: View {
    let context: ActivityViewContext<ForceActivityAttributes>

    var body: some View {
        if context.state.deadline > context.state.startedAt {
            Text(timerInterval: context.state.startedAt...context.state.deadline, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        } else {
            Text("0:00")
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<ForceActivityAttributes>

    var body: some View {
        let tint = Color(hex: context.attributes.colorHex)
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                CountdownRing(context: context, size: 52, lineWidth: 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(context.state.goal) için son")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.8))
                    CountdownText(context: context)
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(tint)
                }
                Spacer()
                if context.state.multiplier > 1 {
                    Text("x\(context.state.multiplier)")
                        .font(.headline.weight(.heavy))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Capsule().fill(.red))
                        .foregroundStyle(.white)
                }
            }
            if context.state.deadline > context.state.startedAt {
                ProgressView(timerInterval: context.state.startedAt...context.state.deadline, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(tint)
            }
            HStack {
                Button(intent: CompleteTaskIntent(taskID: context.attributes.taskID)) {
                    Label("Yaptım", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)
                Button(intent: SkipTaskIntent(taskID: context.attributes.taskID)) {
                    Text("Bugün yapamam").frame(maxWidth: .infinity)
                }
                .tint(.gray)
            }
        }
        .padding()
    }
}
