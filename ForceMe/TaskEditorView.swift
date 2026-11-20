import SwiftUI
import SwiftData

struct TaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let task: ForceTask?

    @State private var title: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var quantity: Int
    @State private var unit: String
    @State private var recurrence: RecurrenceKind
    @State private var weekdays: Set<Int>
    @State private var monthDay: Int
    @State private var intervalDays: Int
    @State private var startDate: Date
    @State private var windowStart: Int
    @State private var windowEnd: Int
    @State private var isActive: Bool
    @State private var repeats: Bool
    @State private var repeatEvery: Int
    @State private var confirmDelete = false

    private let engine = ScheduleEngine()

    init(task: ForceTask?) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _icon = State(initialValue: task?.icon ?? IconCatalog.icons[0])
        _colorHex = State(initialValue: task?.colorHex ?? Palette.colors[0])
        _quantity = State(initialValue: task?.quantity ?? 0)
        _unit = State(initialValue: task?.unit ?? "")
        _recurrence = State(initialValue: task?.recurrence ?? .daily)
        _weekdays = State(initialValue: task?.weekdays ?? [])
        _monthDay = State(initialValue: task?.monthDay ?? Calendar.current.component(.day, from: .now))
        _intervalDays = State(initialValue: task?.intervalDays ?? 2)
        _startDate = State(initialValue: task?.startDate ?? .now)
        _windowStart = State(initialValue: task?.windowStart ?? 9 * 60)
        _windowEnd = State(initialValue: task?.windowEnd ?? 12 * 60)
        _isActive = State(initialValue: task?.isActive ?? true)
        _repeats = State(initialValue: (task?.repeatEveryMinutes ?? 0) > 0)
        _repeatEvery = State(initialValue: (task?.repeatEveryMinutes ?? 0) > 0 ? task!.repeatEveryMinutes : 25)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        TaskIconView(icon: icon, color: Color(hex: colorHex), size: 44)
                        TextField("Görev adı (örn. Diş fırçala)", text: $title)
                            .font(.headline)
                    }
                    Stepper(value: $quantity, in: 0...1000) {
                        Text(quantity == 0 ? "Miktar yok" : "Miktar: \(quantity)")
                    }
                    if quantity > 0 {
                        TextField("Birim (örn. şınav, sayfa, bardak)", text: $unit)
                    }
                    Toggle("Aktif", isOn: $isActive)
                } footer: {
                    Text("Miktar verirsen kaçırdığın her gün için hedef katlanır: 10 şınav → x2 → 20 şınav.")
                }

                Section("İkon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 40), spacing: 10)], spacing: 10) {
                        ForEach(IconCatalog.icons, id: \.self) { symbol in
                            Button { icon = symbol } label: {
                                Image(systemName: symbol)
                                    .font(.system(size: 18, weight: .semibold))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(icon == symbol ? .white : .primary)
                                    .background(Circle().fill(icon == symbol ? Color(hex: colorHex) : Color.secondary.opacity(0.12)))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Renk") {
                    HStack {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Button { colorHex = hex } label: {
                                Circle().fill(Color(hex: hex))
                                    .frame(width: 26, height: 26)
                                    .overlay(Circle().stroke(.primary, lineWidth: colorHex == hex ? 2 : 0).padding(-3))
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Tekrar") {
                    Picker("Sıklık", selection: $recurrence) {
                        ForEach(RecurrenceKind.allCases) { Text($0.title).tag($0) }
                    }
                    switch recurrence {
                    case .weekly:
                        HStack(spacing: 6) {
                            ForEach(Weekday.ordered, id: \.value) { day in
                                let on = weekdays.contains(day.value)
                                Button {
                                    if on { weekdays.remove(day.value) } else { weekdays.insert(day.value) }
                                } label: {
                                    Text(day.short).font(.caption.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: 32)
                                        .foregroundStyle(on ? .white : .primary)
                                        .background(Capsule().fill(on ? Color(hex: colorHex) : Color.secondary.opacity(0.12)))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    case .monthly:
                        Stepper("Ayın \(monthDay). günü", value: $monthDay, in: 1...31)
                    case .interval:
                        Stepper("\(intervalDays) günde bir", value: $intervalDays, in: 2...60)
                    default:
                        EmptyView()
                    }
                    DatePicker(recurrence == .once ? "Tarih" : "Başlangıç", selection: $startDate, displayedComponents: .date)
                }

                Section {
                    Toggle("Gün içinde aralıklarla tekrarla", isOn: $repeats.animation())
                    if repeats {
                        Stepper("Her \(repeatEvery) dakikada bir", value: $repeatEvery,
                                in: ScheduleEngine.minRepeatMinutes...240, step: 5)
                    }
                } header: {
                    Text("Gün içi tekrar")
                } footer: {
                    if repeats {
                        let preview = previewSnapshot
                        let total = engine.slotTimes(preview, on: .now).count
                        let required = engine.requiredSlots(preview, on: .now)
                        Text("\(MinuteWindow.format(windowStart))–\(MinuteWindow.format(windowEnd)) arasında günde \(total) hatırlatma. Günü kurtarmak için en az \(required) tur yapmalısın, yoksa ertesi gün ceza (x2). Bildirimden \"Yapamadım\" ya da \"Bugün daha fazla hatırlatma\" diyebilirsin.")
                    } else {
                        Text("Örn. 1 dk yürüyüş: Miktar 1, birim \"dk yürüyüş\", 08:00–18:00 arası 25 dk'da bir.")
                    }
                }

                Section {
                    DatePicker(repeats ? "Başlangıç" : "En erken", selection: timeBinding($windowStart), displayedComponents: .hourAndMinute)
                    DatePicker(repeats ? "Bitiş" : "En geç", selection: timeBinding($windowEnd), displayedComponents: .hourAndMinute)
                    if let task, !repeats {
                        let learned = engine.effectiveWindow(task.snapshot)
                        if learned.learned {
                            Label("Alışkanlığın öğrenildi: \(learned.label)", systemImage: "brain")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text(repeats ? "Aktif saatler" : "Hatırlatma aralığı")
                } footer: {
                    Text(repeats ? "Turlar bu saatler arasında, başlangıçtan itibaren eşit aralıklarla gelir."
                                 : "Her gün bu aralıkta rastgele bir saatte hatırlatırım. Genelde hep aynı saatlerde yaparsan aralığı o saatlere daraltırım.")
                }

                if task != nil {
                    Section {
                        Button("Görevi sil", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle(task == nil ? "Yeni görev" : "Görevi düzenle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet", action: save)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || windowEnd <= windowStart)
                }
            }
            .confirmationDialog("Bu görev ve tüm geçmişi silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Sil", role: .destructive) {
                    if let task { ForceStore.shared.delete(task) }
                    dismiss()
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 640)
        #endif
    }

    private func save() {
        let store = ForceStore.shared
        let target: ForceTask
        if let task {
            target = task
        } else {
            target = ForceTask()
            store.context.insert(target)
        }
        target.title = title.trimmingCharacters(in: .whitespaces)
        target.icon = icon
        target.colorHex = colorHex
        target.quantity = quantity
        target.unit = unit.trimmingCharacters(in: .whitespaces)
        target.recurrence = recurrence
        target.weekdays = weekdays
        target.monthDay = monthDay
        target.intervalDays = intervalDays
        target.startDate = startDate
        target.windowStart = windowStart
        target.windowEnd = windowEnd
        target.repeatEveryMinutes = repeats ? repeatEvery : 0
        target.isActive = isActive
        store.save()
        Task { await NotificationScheduler.shared.reschedule() }
        dismiss()
    }

    private var previewSnapshot: TaskSnapshot {
        TaskSnapshot(windowStart: windowStart, windowEnd: windowEnd, repeatEveryMinutes: repeatEvery)
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.startOfDay(for: .now).addingTimeInterval(TimeInterval(minutes.wrappedValue * 60)) },
            set: {
                let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}
