import SwiftUI

struct SettingsView: View {
    @AppStorage(ForceSettings.notifyKey) private var notifyOnDevice = ForceSettings.defaultNotify
    @AppStorage(ForceSettings.soundKey) private var soundOn = true
    @AppStorage(ForceSettings.summaryKey) private var summaryMinutes = 8 * 60

    var body: some View {
        Form {
            Section {
                Toggle("Bu cihazda bildirim gönder", isOn: $notifyOnDevice)
                Toggle("Sesli bildirim", isOn: $soundOn)
            } footer: {
                Text("Aynı görevleri iPhone ve Mac'te kullanıyorsan, çift bildirim almamak için birinde kapatabilirsin. Apple Watch iPhone bildirimlerini otomatik gösterir.")
            }

            Section {
                DatePicker("Sabah özeti", selection: summaryTime, displayedComponents: .hourAndMinute)
            } footer: {
                Text("Her sabah dünkü performansını özetlerim: \"Dün 4/5 görev başardın, aynı performansı bekliyorum!\"")
            }

            Section {
                Button("Bildirim izni iste") {
                    Task { await NotificationScheduler.shared.requestAuthorization() }
                }
                Button("5 sn sonra test bildirimi gönder") {
                    NotificationScheduler.shared.sendTest(for: ForceStore.shared.allTasks().first?.snapshot)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Ayarlar")
        .onChange(of: notifyOnDevice) { reschedule() }
        .onChange(of: soundOn) { reschedule() }
        .onChange(of: summaryMinutes) { reschedule() }
    }

    private var summaryTime: Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(summaryMinutes * 60)) },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                summaryMinutes = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    private func reschedule() {
        Task { await NotificationScheduler.shared.reschedule() }
    }
}
