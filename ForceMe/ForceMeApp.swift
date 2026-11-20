import SwiftUI
import SwiftData
import UserNotifications
#if os(iOS)
import BackgroundTasks
#endif

@main
struct ForceMeApp: App {
    @Environment(\.scenePhase) private var scenePhase

    static let refreshTaskID = "com.mrbigbear.forceme.refresh"

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationScheduler.shared.registerCategories()
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            RootView()
                .task {
                    #if DEBUG
                    DemoData.seedIfRequested()
                    #if os(macOS)
                    MacSnapshot.runIfRequested()
                    #endif
                    if !ProcessInfo.processInfo.arguments.contains("-skipAuth") {
                        await NotificationScheduler.shared.requestAuthorization()
                    }
                    #else
                    await NotificationScheduler.shared.requestAuthorization()
                    #endif
                    await NotificationScheduler.shared.reschedule()
                }
        }
        .modelContainer(ForceStore.shared.container)
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await NotificationScheduler.shared.reschedule() }
            case .background:
                #if os(iOS)
                Self.scheduleAppRefresh()
                #endif
            default:
                break
            }
        }
        #if os(iOS)
        // Uygulama günlerce açılmasa bile hatırlatmaların ileriye doğru kurulmaya devam etmesi için.
        .backgroundTask(.appRefresh(Self.refreshTaskID)) {
            await NotificationScheduler.shared.reschedule()
            await Self.scheduleAppRefresh()
        }
        #endif

        #if os(macOS)
        MenuBarExtra("ForceMe", systemImage: "flame.fill") {
            MenuBarView()
                .modelContainer(ForceStore.shared.container)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .frame(width: 460, height: 420)
        }
        #endif
    }

    #if os(iOS)
    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date.now.addingTimeInterval(6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
    #endif
}

struct RootView: View {
    @State private var tab = RootView.initialTab

    var body: some View {
        TabView(selection: $tab) {
            Tab("Bugün", systemImage: "flame.fill", value: "today") { TodayView() }
            Tab("Görevler", systemImage: "list.bullet", value: "tasks") { TasksView() }
            #if !os(macOS)
            Tab("Ayarlar", systemImage: "gearshape", value: "settings") { NavigationStack { SettingsView() } }
            #endif
        }
        .tint(Color(hex: Palette.colors[0]))
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    /// DEBUG: ekran görüntüleri için `-tab tasks` gibi bir argümanla açılış sekmesi seçilebilir.
    private static var initialTab: String {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-tab"), i + 1 < args.count { return args[i + 1] }
        #endif
        return "today"
    }
}
