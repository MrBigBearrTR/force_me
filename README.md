# ForceMe 🔥

Zorlayıcı hatırlatma uygulaması: iPhone, iPad, Apple Watch ve Mac.

- **Rastgele saat:** Görevi bir aralığa koyarsın (örn. 09:00–12:00), her gün o aralıkta farklı bir saatte hatırlatır.
- **Alışkanlığı öğrenir:** Genelde 11:00–11:30 arasında yapıyorsan (en az 3 kayıt), hatırlatmalar o aralığa daralır.
- **Ceza sistemi:** "Bugün yapamam" dersen ya da kaçırırsan, ertesi gün ikonun halkası kırmızı olur ve hedef katlanır (1 gün → x2, 2 gün → x3 …). Cezalıyken günde birden fazla (20 dk arayla) hatırlatma gelir.
- **Ertele + geri sayım:** Ertelenen görev kilit ekranında ve Dynamic Island'da geri sayım olarak görünür ("20 sayfa için son 04:59"), halka geriye doğru boşalır.
- **Gün içi aralıklı tekrar:** Örneğin 08:00–18:00 arası 25 dk'da bir "1 dk yürüyüş". Her tur için bildirimde *Yaptım / Yapamadım / Bugün daha fazla hatırlatma* butonları vardır. Turların en az yarısı yapılırsa gün kurtarılmış sayılır; yapılmazsa ertesi gün ceza gelir (1 dk → 2 dk yürüyüş).
- **Tekrar tipleri:** Tek sefer (yapılana kadar her gün peşini bırakmaz), her gün, haftalık (gün seçimli), aylık, N günde bir.
- **İkonlu ve sesli bildirimler:** Bildirimde görev ikonu görünür, özel alarm sesi çalar; "Yaptım / 15 dk ertele / 30 dk ertele / Bugün yapamam" butonları vardır.
- **Samimi geri bildirim:** Her başarıda "Helal olsun! 💪" tarzı tebrik; her sabah "Dün 4/5 görev başardın, aynı performansı bekliyorum!" özeti.

## Kurulum

```bash
brew install xcodegen
xcodegen generate
open ForceMe.xcodeproj
```

1. `project.yml` içinde `DEVELOPMENT_TEAM` alanına Team ID'ni yaz (veya Xcode > Signing & Capabilities'ten seç) ve `xcodegen generate` komutunu tekrar çalıştır.
2. Gerekirse bundle ID'leri (`com.mrbigbear.forceme…`), App Group'u (`group.com.mrbigbear.forceme`) ve iCloud konteynerini (`iCloud.com.mrbigbear.forceme`) kendi hesabına göre değiştir.
3. `ForceMe` şemasını iPhone/iPad'de, `ForceMeMac` şemasını Mac'te çalıştır. Watch uygulaması iOS uygulamasına gömülüdür.

> Not: Projeyi iCloud'a senkronlanan Masaüstü klasöründen derlerken "resource fork… not allowed" imza hatası alırsan, DerivedData'yı varsayılan konumda (`~/Library/Developer/Xcode/DerivedData`) bırak. Proje klasörüne `build/` koyma.

### Demo verisi (sadece Debug)

Scheme > Run > Arguments'a `-demo` eklersen örnek görevler kurulur: alışkanlığı öğrenilmiş "Diş fırçala", dün kaçırıldığı için x2 cezalı "Şınav çek" 5 dakikalık geri sayımı başlamış "Kitap oku" ve 25 dk'da bir "Yürüyüş". `-skipAuth` bildirim izni sorusunu atlar.

## Testler

```bash
xcodebuild -project ForceMe.xcodeproj -scheme ForceMeMac -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO
```

Zamanlama motoru (`Shared/Core`) saf Swift'tir ve 22 birim testle doğrulanır: tekrar kuralları, ceza çarpanı, rastgele saatin aralık içinde ve gün boyunca sabit kalması, alışkanlık öğrenme ve gün içi aralıklı turlar.

## Mimari

| Klasör | İçerik |
|---|---|
| `Shared/Core` | Saf mantık: `ScheduleEngine` (tekrar, ceza, rastgele saat, öğrenme), `Messages` (Türkçe metinler) |
| `Shared/Data` | SwiftData modelleri (CloudKit uyumlu) + `ForceStore` (Yaptım / Ertele / Bugün yapamam aksiyonları) |
| `Shared/Notifications` | Bildirim planlama (önümüzdeki 4 gün, en fazla 60 bekleyen), ikon PNG üretimi, aksiyon yakalama |
| `Shared/LiveActivity` | ActivityKit nitelikleri + Live Activity butonları için App Intent'ler (iOS) |
| `ForceMe` | iOS/iPadOS/macOS arayüzü (Bugün, Görevler, Ayarlar, Mac menü çubuğu) |
| `ForceMeWidgets` | Kilit ekranı ve Dynamic Island geri sayımı |
| `ForceMeNotificationUI` | Bildirim aşağı çekilince açılan kompakt kart (ikon, metin, ilerleme / geri sayım). Bu olmadan iOS ekteki ikon görselini ekran genişliğinde gösterir. |
| `ForceMeWatch` | watchOS uygulaması |
| `Assets` | Uygulama ikonu; açık, koyu ve renklendirilmiş (tinted) varyantlar (`swift Scripts/make_app_icon.swift` ile yeniden üretilir) |

## Bilinen sınırlar

- **Dynamic Island çevresinde halka:** Apple, uygulamaların adanın kenarına çizim yapmasına izin vermiyor; kompakt görünümde yalnızca kameranın solu ve sağı uygulamaya ait. Bu yüzden geri sayım solda ikonun etrafında geriye doğru boşalan bir halka, sağda da süre olarak gösteriliyor. Basılı tutunca açılan görünümde solda ikon, sağda büyük süre, altta görev adı ve boşalan bir çizgi var.
- **Bildirimden erteleme:** Live Activity yalnızca uygulama ön plandayken başlatılabildiği için, bildirimdeki "ertele" butonu uygulamayı bir anlığına açar.
- **Senkron:** iCloud (CloudKit) imzalı bir build ve giriş yapılmış iCloud hesabı gerektirir. Bunlar yoksa veriler cihazda yerel olarak tutulur.
- **Çift bildirim:** iPhone ve Mac'te aynı görevler varsa ikisi de bildirim gönderir. Ayarlar'dan birinde "Bu cihazda bildirim gönder" seçeneğini kapat. Watch, iPhone bildirimlerini aynalar.
- **64 bildirim sınırı:** iOS en fazla 64 bekleyen bildirim tutar. Normal görevler ve sabah özetleri önceliklidir; aralıklı turlar kalan kapasiteyi en yakın saatlerden başlayarak doldurur. Çok sayıda aralıklı görev varsa yalnızca bugünün turları kurulabilir. Uygulama her açıldığında plan yenilenir.
- **Simülatörde bildirim ikonu:** iOS 27 simülatörü bildirimlerde uygulama ikonu ve görsel eki göstermiyor (QuickLook'ta bildirim küçük resmi eklentisi yok). Bunlar gerçek cihazda kontrol edilmeli.
- Uygulama uzun süre açılmazsa hatırlatmalar 4 gün sonra biter. Arka plan yenilemesi bunu uzatır ama iOS bunun ne zaman çalışacağını garanti etmez.
