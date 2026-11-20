#if os(iOS)
import Foundation
import ActivityKit
import AppIntents

/// Ertelenen görevin kilit ekranı / Dynamic Island geri sayımı.
struct ForceActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var deadline: Date
        var goal: String
        var multiplier: Int
    }

    var taskID: String
    var title: String
    var icon: String
    var colorHex: String
}

@MainActor
enum LiveActivityManager {
    static func start(task: TaskSnapshot, deadline: Date, multiplier: Int) {
        end(taskID: task.id.uuidString)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = ForceActivityAttributes(taskID: task.id.uuidString, title: task.title,
                                                 icon: task.icon, colorHex: task.colorHex)
        let state = ForceActivityAttributes.ContentState(startedAt: .now, deadline: deadline,
                                                         goal: task.goalText(multiplier: multiplier),
                                                         multiplier: multiplier)
        _ = try? Activity.request(attributes: attributes,
                                  content: ActivityContent(state: state, staleDate: deadline.addingTimeInterval(15 * 60)),
                                  pushType: nil)
    }

    static func end(taskID: String) {
        for activity in Activity<ForceActivityAttributes>.activities where activity.attributes.taskID == taskID {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}

/// Live Activity / Dynamic Island üzerindeki "Yaptım" butonu.
struct CompleteTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Görevi tamamla"

    @Parameter(title: "Görev")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) {
            await MainActor.run { ForceStore.shared.complete(id) }
        }
        return .result()
    }
}

/// Live Activity üzerindeki "Bugün yapamam" butonu.
struct SkipTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Bugün yapamam"

    @Parameter(title: "Görev")
    var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: taskID) {
            await MainActor.run { ForceStore.shared.skip(id) }
        }
        return .result()
    }
}
#endif
