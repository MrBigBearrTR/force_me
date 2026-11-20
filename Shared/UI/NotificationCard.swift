import SwiftUI

/// Bildirim ile bildirim kartı (Notification Content Extension) arasında `userInfo` içinde taşınan veri.
/// Bildirim aşağı çekilip açıldığında sistem, ekteki ikon görselini ekran genişliğinde göstermek yerine bu kartı gösterir.
struct NotificationCardData {
    enum Kind: String {
        case reminder, interval, deadline, praise
    }

    var kind: Kind
    var title: String
    var body: String
    var taskTitle: String
    var icon: String
    var colorHex: String
    var ring: RingStyle
    var multiplier: Int
    var goal: String
    var done: Int = 0
    var required: Int = 0
    var total: Int = 0
    var deadline: Date? = nil

    static let key = "card"

    var dictionary: [String: Any] {
        var d: [String: Any] = [
            "kind": kind.rawValue, "taskTitle": taskTitle, "icon": icon, "color": colorHex,
            "ring": ring.rawValue, "mult": multiplier, "goal": goal,
            "done": done, "required": required, "total": total,
        ]
        if let deadline { d["deadline"] = deadline.timeIntervalSince1970 }
        return d
    }

    init(kind: Kind, title: String, body: String, taskTitle: String, icon: String, colorHex: String,
         ring: RingStyle, multiplier: Int, goal: String,
         progress: (done: Int, required: Int, total: Int)? = nil, deadline: Date? = nil) {
        self.kind = kind
        self.title = title
        self.body = body
        self.taskTitle = taskTitle
        self.icon = icon
        self.colorHex = colorHex
        self.ring = ring
        self.multiplier = multiplier
        self.goal = goal
        self.done = progress?.done ?? 0
        self.required = progress?.required ?? 0
        self.total = progress?.total ?? 0
        self.deadline = deadline
    }

    init?(userInfo: [AnyHashable: Any], title: String, body: String) {
        guard let d = userInfo[Self.key] as? [String: Any],
              let kind = (d["kind"] as? String).flatMap(Kind.init(rawValue:)),
              let icon = d["icon"] as? String
        else { return nil }
        self.kind = kind
        self.title = title
        self.body = body
        self.taskTitle = d["taskTitle"] as? String ?? ""
        self.icon = icon
        self.colorHex = d["color"] as? String ?? "#FF6B35"
        self.ring = (d["ring"] as? String).flatMap(RingStyle.init(rawValue:)) ?? .none
        self.multiplier = d["mult"] as? Int ?? 1
        self.goal = d["goal"] as? String ?? ""
        self.done = d["done"] as? Int ?? 0
        self.required = d["required"] as? Int ?? 0
        self.total = d["total"] as? Int ?? 0
        self.deadline = (d["deadline"] as? Double).map(Date.init(timeIntervalSince1970:))
    }
}

/// Açılmış bildirimin kompakt kartı: solda ikon, sağda başlık, metin ve duruma göre ilerleme / geri sayım.
struct NotificationCardView: View {
    let data: NotificationCardData

    var body: some View {
        let tint = Color(hex: data.colorHex)
        HStack(alignment: .center, spacing: 14) {
            TaskIconView(icon: data.icon, color: tint, ring: data.ring, multiplier: data.multiplier, size: 52)
            VStack(alignment: .leading, spacing: 5) {
                Text(data.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(data.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                detail(tint: tint)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func detail(tint: Color) -> some View {
        switch data.kind {
        case .interval where data.total > 0:
            let success = data.done >= data.required
            VStack(alignment: .leading, spacing: 4) {
                ProgressView(value: Double(min(data.done, data.total)), total: Double(data.total))
                    .tint(success ? .green : tint)
                Text("✅ \(data.done) · hedef \(data.required)/\(data.total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(success ? .green : .secondary)
            }
            .padding(.top, 2)
        case .deadline:
            if let deadline = data.deadline, deadline > .now {
                (Text("Son ") + Text(timerInterval: Date.now...deadline, countsDown: true))
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Text("Süre doldu · \(data.goal)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
            }
        case .reminder where data.multiplier > 1:
            Text("Ceza x\(data.multiplier) · \(data.goal)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(.red))
        default:
            EmptyView()
        }
    }
}
