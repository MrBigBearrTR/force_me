import Foundation

/// Samimi, biraz da zorba metinler.
enum Messages {
    typealias Text = (title: String, body: String)

    static func reminder(_ task: TaskSnapshot, multiplier m: Int, followUp: Bool) -> Text {
        let goal = task.goalText(multiplier: m)
        if m > 1 {
            let missed = m - 1
            return (
                "🔴 Cezalısın x\(m) · \(task.title)",
                [
                    "Dün kaçırdın, bugün x\(m): \(goal). Borç birikiyor!",
                    "\(missed) gündür yapmıyorsun. Ceza: \(goal). Hadi bakalım!",
                    "Kaçış yok. Bugünkü borcun: \(goal).",
                ].randomElement()!
            )
        }
        if followUp {
            return (
                "⏰ \(task.title)",
                [
                    "Hâlâ bekliyorum… \(goal) yapılmadı.",
                    "Unuttun sanma, hatırlatıyorum: \(goal).",
                ].randomElement()!
            )
        }
        return (
            "\(task.title) zamanı!",
            [
                "Hadi bakalım, \(goal). Bahane yok!",
                "Seni izliyorum 👀 \(goal) bekliyor.",
                "Şimdi yap, sonra rahatla: \(goal).",
                "Kalk, yap, bitir: \(goal)!",
                "Erteleme yok, kaçış yok: \(goal).",
            ].randomElement()!
        )
    }

    /// Aralıklı görevin her turu (örn. 25 dk'da bir 1 dk yürüyüş).
    static func slotReminder(_ task: TaskSnapshot, multiplier m: Int, done: Int, required: Int, total: Int) -> Text {
        let goal = task.goalText(multiplier: m)
        let title = m > 1 ? "🔴 Cezalısın x\(m) · \(task.title)" : "🔁 \(task.title)"
        if done >= required {
            return (title, "Hedef tamam ama durmak yok: \(goal). Bugün \(done)/\(total) ✅")
        }
        let left = required - done
        let body = [
            "Sıradaki tur: \(goal). Günü kurtarmana \(left) tur kaldı.",
            "Kalk bakalım: \(goal). Bugün \(done)/\(required) hedef.",
            "Tur zamanı! \(goal) — \(left) tur daha yaparsan bugün temiz.",
        ].randomElement()!
        return (title, body)
    }

    static func slotGoalReached(_ task: TaskSnapshot, done: Int, total: Int) -> Text {
        ("Günü kurtardın! 🎯", "\(task.title): \(done)/\(total). Hedef tamam, devam edersen bonus!")
    }

    static func slotAllDone(_ task: TaskSnapshot, total: Int) -> Text {
        ("Kusursuz gün! 🏆", "\(task.title): bugünkü \(total) turun hepsi tamam. Helal olsun!")
    }

    static func praise(_ task: TaskSnapshot, multiplier m: Int) -> Text {
        if m > 1 {
            return (
                "Borcunu ödedin! 🏆",
                "x\(m) cezayı erittin, \(task.title) tamam. Saygılar, gerçekten."
            )
        }
        let title = ["Helal olsun! 💪", "İşte bu! 🔥", "Aslanım benim! 🦁", "Bravo! 👏", "Sözünü tuttun! ✅"].randomElement()!
        let body = [
            "\(task.title) tamam. Kendinle gurur duy, ben duyuyorum.",
            "Disiplin böyle olur. Bir sonrakine de böyle gir!",
            "\(task.title) bitti. Kimse seni durduramaz.",
            "Bugünkü sen, dünkü seni geçti. Devam!",
            "Tıkır tıkır. Yarın da aynı tempo, anlaştık mı?",
        ].randomElement()!
        return (title, body)
    }

    static func deadline(_ task: TaskSnapshot, multiplier m: Int) -> Text {
        let goal = task.goalText(multiplier: m)
        return (
            "⏰ Süre doldu: \(task.title)",
            ["\(goal) hâlâ bekliyor. Söz verdin!", "Ertelemenin sonu geldi: \(goal), şimdi!"].randomElement()!
        )
    }

    static func lastMinute(_ task: TaskSnapshot, multiplier m: Int) -> Text {
        ("⌛ Son 1 dakika!", "\(task.goalText(multiplier: m)) için son dakika. Yetiş!")
    }

    /// Sabah özeti: "Dün bu kadar iş başardın, aynı performansı bekliyorum."
    static func morning(done: Int, total: Int) -> Text {
        ("Günaydın! ☀️", summary(done: done, total: total))
    }

    static func summary(done: Int, total: Int) -> String {
        guard total > 0 else { return "Dün listende görev yoktu. Bugün kendine bir hedef koy!" }
        if done == total { return "Dün \(total) görevin hepsini bitirdin. Aynı performansı bugün de bekliyorum! 💪" }
        if done == 0 { return "Dün \(total) görevden hiçbirini yapmadın. Bugün telafi günü, bahane yok!" }
        if Double(done) / Double(total) >= 0.5 {
            return "Dün \(done)/\(total) görev başardın. Fena değil ama daha iyisini yapabileceğini biliyorum."
        }
        return "Dün sadece \(done)/\(total). Bugün çıtayı yükseltiyoruz!"
    }
}
