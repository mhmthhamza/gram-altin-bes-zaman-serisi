# Gram Altın ile BES Kararı: Zaman Serisi Projesi (R)

**Kural:** Sadece ham veri seti (`zaman_serisi_R/data/GAU_TRY Geçmiş Verileri.csv`, Investing'den indirilen dosyanın değiştirilmemiş kopyası) ve ders notlarının ilk üç bölümü kullanılır. Önceki Python projesindeki sonuçlar, modeller ve kararlar bu projeye taşınmaz.

**Araç:** Ders notlarındaki gibi R ve `fpp2` paketi (`forecast` + `ggplot2` ile birlikte gelir).

**İşaretler:** 🔒 = model veya tahmin içeren adım; birlikte karar vermeden çalıştırılmaz. ❓ = senin karar vermen gereken nokta.

---

## Adım 1: Problem tanımı (Bölüm 1.3, 1.6, 1.7)

Kitaptaki ilk adım: neyin, hangi sıklıkla ve ne kadar ileri tahmin edileceğini belirlemek.

| Soru | Cevap |
|---|---|
| Ne tahmin ediliyor? | Gram altının günlük kapanış fiyatı (TL), yₜ |
| Veri sıklığı | Günlük (işlem günleri) |
| Tahmin ufku h | Son kapanıştan karar gününe kadarki hafta içi gün sayısı: **h = 43**. Şimdilik 22 Ekim → 22 Aralık; son adımda güncel veriyle 28 Ekim → 28 Aralık olacak, o aralık da 43 iş günü |
| Tahmin neye yarayacak? | BES mi, altın mı kararı. Karar, karar günündeki fiyatın bir **eşik fiyatın** üstünde mi altında mı olacağına bağlı |
| Eşik | BES kazancı = 33.443 TL × %30 × %15 = 1.504,94 TL (22 Aralık). Eşik = son kapanış + 1.504,94 / 5 gram = 5.747,72 + 300,99 = **6.048,71 TL** (%5,24 yukarıda). 5 gram altının değer artışı BES kazancını geçerse A, geçmezse B |

**Bölüm 1.7'den gelen bakış:** 22 Aralık fiyatı bugünden bilinmiyor, yani rastgele bir değişken. Bizim işimiz tek bir sayı değil, **tahmin dağılımı** y_{T+h} | y₁, …, y_T ve **tahmin aralıkları** üretmek. Kararımız şu soruya dönüşüyor:

> Tahmin dağılımına göre 22 Aralık fiyatının eşiğin altında kalma olasılığı ne kadar?

**Bölüm 1.1'den gelen uyarı:** Döviz kuru ve finansal fiyatlar etkin piyasa davranışı gösterebilir; "yarın artar mı" sorusu yazı-tura gibi olabilir. Projede bunu açıkça test edeceğiz (Adım 4 ve 6). Sonuç "yön tahmin edilemiyor" çıkarsa bu da dürüst ve geçerli bir bulgudur.

---

## Adım 2: Veriyi R'a almak ve ts nesnesi (Bölüm 2.1, 3.2) ✅

Kod: `01_veri.R`. Ham veri 1.715 satır (1 Ocak 2021 – 23 Ekim 2026); boş veya tekrarlı satır yok.

**Takvim düzenlemesi (Bölüm 3.2).** Kitap, takvimden gelen bilinen varyasyonun modelden önce kaldırılmasını öneriyor (süt örneğindeki ay uzunlukları gibi). Yapılanlar:

| Düzenleme | Satır | Gerekçe |
|---|---|---|
| Hafta sonu satırları çıkarıldı | 201 Pazar | Cumartesi hiç yok. Pazar satırları ise yıldan yıla tutarsız: 2021'de 52, 2022'de 52, 2023'te 22, 2024'te 0, 2025'te 33, 2026'da 42. Cuma'dan sonra Pazartesi gelir; hafta sonu piyasanın kapalı olduğu, fiyatın değişmediği günler sayılır |
| İndirme günü satırı çıkarıldı | 1 (23 Ekim) | Gün sonu kapanışı değil, indirme anındaki fiyat; seri tamamlanmış son işlem gününde (22 Ekim) bitiyor |
| Tatil günleri önceki kapanışla dolduruldu | 2 (18 Nisan 2025, 3 Nisan 2026; ikisi de Paskalya cuması) | Hafta sonuyla aynı mantık: piyasa kapalı, fiyat değişmedi. Böylece her hafta tam 5 gözlem oluyor |

Sonuç: **1.515 gözlem**, her hafta Pzt–Cum.

**Frekans kararı: `frequency = 5`.** Kitaptaki tanım: frekans, mevsimsel desen tekrarlanmadan önceki gözlem sayısıdır. Gerekçe:
- Haftalık bir desen varsa, bizim veride tekrar eden tek takvim döngüsü 5 günlük haftadır. Tatiller doldurulduğu için her hafta tam 5 gözlem var; serideki her gözlemin `cycle()` değeri gerçek gün adıyla birebir tutuyor (1 = Pzt … 5 = Cum, kontrol edildi).
- `frequency = 5` seçmek bize bir şey kaybettirmiyor: ortalama, naive ve drift frekansa bakmıyor, aynı sonucu verir. Ljung-Box için de kitabın önerisi değişmiyor: mevsimsel olmayan veri için h = 10, mevsimsel veri için h = 2m = 10.
- Buna karşılık iki şey kazandırıyor: mevsimsel naive yöntemi (geçen haftanın aynı günü) kullanılabiliyor ve haftanın günlerine göre mevsimsel grafikler çizilebiliyor.
- Haftalık mevsimsellik çıkmazsa bu da bir sonuç olur: mevsimsel naive, naive'den kötü çıkar ve elenir.

Mevsimsel grafikler için ayrıca aylık seri (ay sonu kapanışı, `frequency = 12`) Adım 3'te kurulur.

**Çıktı:** `data/proje.rds` (içinde `y`, temiz veri, P0, eşik, h) ve `data/gram_altin_temiz.csv`.

---

## Adım 3: Keşifsel analiz (Bölüm 1.6 Adım 3, Bölüm 2)

Model yok; sadece grafikler ve betimsel ölçüler.

| # | Grafik / ölçü | R | Cevaplanan soru |
|---|---|---|---|
| 3.1 | Zaman grafiği | `autoplot(y)`, `autoplot(log(y))` | Trend var mı? Yön değiştiriyor mu? Olağandışı gözlemler var mı, haberlerle açıklanabiliyorlar mı? |
| 3.2 | Trend / mevsimsellik / döngüsellik | Grafik yorumu (Bölüm 2.3) | Seri bu üç bileşenden hangilerini içeriyor? |
| 3.3 | Mevsimsel grafik | `ggseasonplot(aylik)`, `ggseasonplot(aylik, polar = TRUE)` | Her yıl aynı aylarda benzer hareket var mı? Özellikle Kasım–Aralık? |
| 3.4 | Mevsimsel alt seri grafiği | `ggsubseriesplot(aylik)` | Ay ortalamaları (yatay çizgiler) birbirinden farklı mı? |
| 3.5 | Gecikme grafikleri | `gglagplot(y)` | yₜ ile yₜ₋ₖ ilişkisi (trendli seride hepsi çizgi üstünde çıkar) |
| 3.6 | ACF (korelogram) | `ggAcf(y)` | Kitap: trendli serinin ACF'si gecikme arttıkça **yavaş azalır**; mevsimsel seride **taraklı** görünür |

**Not:** Altında mevsimsellik çıkmazsa bu da sonuçtur. 3.3–3.4'teki 5–6 Aralık ayıyla kesin bir şey söylenemez; sadece görsel izlenim olarak raporlanır.

---

## Adım 4: Dönüşüm ve günlük değişimler (Bölüm 3.2, 3.3)

**4.1 Log dönüşümü (Box-Cox, λ = 0).** Kitap: dalgalanma serinin seviyesiyle büyüyorsa dönüşüm kullan. Log'un artıları: yorumlanabilir ve tahminleri pozitif tutar.
```r
BoxCox.lambda(y)    # λ 0'a yakın çıkarsa log seçimini destekler
autoplot(BoxCox(y, lambda = 0))
```
Sayısal örnek: fiyat 100'den 110'a çıkıp sonra 100'e dönerse log farkları +0,0953 ve −0,0953 olur, toplamları tam 0'dır. Yüzdelerde ise +%10 ve −%9,09 çıkar. Log farkları zamanda toplanabilir; 43 günlük değişim, günlük log farklarının toplamıdır.

**4.2 Naive yöntemin artıkları = günlük değişimler.** Kitaptaki Google örneğinin aynısı: log fiyata naive uygulanırsa artıklar eₜ = log yₜ − log yₜ₋₁, yani **günlük log getiri** olur.
```r
res <- residuals(naive(log(y)))
autoplot(res); gghistogram(res); ggAcf(res)
```

**4.3 Beyaz gürültü mü? (Bölüm 2.9, 3.3)**
- ACF sınırları ±2/√T. T = 1.515 için 2/38,9 = **±0,051**. Çubukların %5'inden belirgin fazlası dışarıdaysa beyaz gürültü değil.
- Ljung-Box (h = 10, mevsimsel olmayan veri için kitabın önerisi):
  ```r
  Box.test(res, lag = 10, fitdf = 0, type = "Lj")   # H0: seri beyaz gürültü
  ```
- **Yorum:** Günlük değişimler beyaz gürültüyse geçmiş değişimler geleceğin yönü hakkında bilgi vermiyor demektir (Bölüm 1.1'deki etkin piyasa uyarısı). O zaman en iyi tahmin yöntemleri naive veya drift olur.

**4.4 Histogram ve normallik.** Kuyruklar uzun mu? Kitaptaki Google örneğinin uyarısı: nokta tahmini iyi olsa bile normal varsayımlı tahmin aralıkları yanlış olabilir. Bu, Adım 7'deki bootstrap tercihinin gerekçesi olacak.

---

## Adım 5: Kıyaslama yöntemleriyle tahmin (Bölüm 3.1) 🔒

h = 43, log ölçekte (`lambda = 0`) dört yöntem:

```r
h <- 43
fc1 <- meanf (y, h = h, lambda = 0)
fc2 <- naive (y, h = h, lambda = 0)
fc3 <- snaive(y, h = h, lambda = 0)               # frequency = 5: geçen haftanın aynı günü
fc4 <- rwf   (y, h = h, lambda = 0, drift = TRUE)

autoplot(window(y, start = ...)) +
  autolayer(fc1, series = "Ortalama",         PI = FALSE) +
  autolayer(fc2, series = "Naive",            PI = FALSE) +
  autolayer(fc4, series = "Drift",            PI = FALSE) +
  geom_hline(yintercept = esik, linetype = "dashed")
```

| Yöntem | 43 gün sonrası için tahmini | Karar açısından |
|---|---|---|
| Ortalama | Tüm geçmişin ortalaması | Trendli seride çok düşük kalır; sadece kıyaslama |
| Naive | Son kapanış | "Fiyat değişmez" → eşiğin altında kalır |
| Mevsimsel naive | Geçen haftanın aynı günü | Mevsimsellik yoksa naive'e çok yakın |
| Drift | Geçmişteki ortalama artış hızı devam eder | Drift pozitifse eşiğin üstüne çıkabilir |

**Dört yöntemin hepsi Adım 7'ye kadar birlikte taşınır**; hangisiyle devam edileceğine Adım 6'nın sonuçlarına göre en sonda karar verilir. Bu yöntemlerin hesap yükü çok küçük: `tsCV` ile 1.500 başlangıç noktası × 43 adım bile saniyeler sürer. Asıl yük, raporda dört satır yorum yazmak.

**Karar asıl olarak naive ile drift arasındaki farka bağlı.** Geçmişteki artış devam edecek mi, etmeyecek mi? Adım 6 bunu veriyle sınar.

❓ Drift'in hangi dönemden hesaplanacağı da ayrı bir seçim: `window(y, start = ...)` ile son 1 / 2 / 3 yıl ya da tüm veri. Bu seçim de Adım 6'da çapraz doğrulamayla verilir.

---

## Adım 6: Doğruluk değerlendirmesi (Bölüm 3.3, 3.4) 🔒

**6.1 Artık analizi.** Her yöntem için:
```r
checkresiduals(fc4)   # zaman grafiği + ACF + histogram + Ljung-Box
```
İyi bir yöntemin artıkları ilişkisiz ve ortalaması sıfır olmalı. Örneğin naive'in artık ortalaması sıfırdan belirgin büyükse naive yanlıdır; bu da drift lehine bir işarettir.

**6.2 Eğitim / test ayrımı.** Kitap: test seti en az tahmin ufku kadar olmalı.
```r
egitim <- subset(y, end = length(y) - h)
test   <- subset(y, start = length(y) - h + 1)
accuracy(rwf(egitim, h = h, drift = TRUE, lambda = 0), test)
```
Tablo: RMSE, MAE, MAPE, MASE (MASE < 1 → naive'den iyi). Tek bir test penceresi şansa açık; o yüzden 6.3 daha güvenilir.

**6.3 Zaman serisi çapraz doğrulaması (`tsCV`).** Her başlangıç noktasından 43 gün ileriyi tahmin edip gerçekleşenle karşılaştırırız:
```r
ly <- log(y)
e_naive <- tsCV(ly, naive, h = h)
e_drift <- tsCV(ly, rwf, drift = TRUE, h = h)
e_drift2 <- tsCV(ly, function(x, h) rwf(x, drift = TRUE, h = h), h = h, window = 500)  # son 500 günle

mse <- function(e) colMeans(e^2, na.rm = TRUE)
data.frame(h = 1:h, naive = mse(e_naive), drift = mse(e_drift)) |> ...
```
- Kitaptaki gibi MSE'nin ufukla (h = 1…43) nasıl büyüdüğü çizilir.
- 43. adımdaki RMSE en küçük olan yöntem ve pencere seçilir.
- Log ölçekteki hata yaklaşık yüzde hata gibi okunur (0,05 ≈ %5).

**6.4 Karar isabeti (basit sayım).** Geçmişteki her başlangıç noktasında "43 gün sonra fiyat, o günkü fiyat + 300 TL'yi aştı mı?" sorusunu yöntem doğru bildi mi? Bu, kitaptaki "tahmin yazı-turadan daha iyi mi?" sorusunun bizim karar için uygulanmış hâli.

---

## Adım 7: Tahmin aralıkları ve karar olasılığı (Bölüm 3.5) 🔒

**7.1 Normal varsayımlı aralıklar.** `forecast` nesneleri %80 ve %95 aralıklarını kendisi veriyor. Kitaptaki çok adımlı formüller (σ̂ = artık standart sapması):
- Naive: σ̂_h = σ̂ √h
- Drift: σ̂_h = σ̂ √( h (1 + h/T) ). Sayısal örnek: h = 43, T = 1.515 → √(43 × 1,028) ≈ 6,65 (sadece √43 olsaydı 6,56). Ek kısım, drift'in de tahmin edilmiş olmasından gelen belirsizlik.

**Eşiğin altında kalma olasılığı.** Kitaptaki aralık formülü ŷ ± c·σ̂_h'yi tersten kullanırız. Log ölçekte c = (log(eşik) − ŷ) / σ̂_h hesaplanır; Tablo 3.1'deki çarpanların karşılığı olan olasılık `pnorm(c)` ile bulunur.

**7.2 Bootstrap aralıkları.** Normal varsayımı tutmuyorsa (Adım 4.4). Kitap: tek varsayım artıkların ilişkisiz olması.
```r
rwf(y, h = h, drift = TRUE, lambda = 0, bootstrap = TRUE)
```
Olasılık için kitapta anlatılan mantığı kendimiz uygularız: geçmiş artıklardan rastgele 43 tane seçilip tahmine eklenir; bu, binlerce kez tekrarlanır ve "olası gelecekler"in yüzde kaçında fiyat eşiğin altında kalıyor sayılır.

**7.3 Medyan mı ortalama mı (yanlılık düzeltmesi, Bölüm 3.2).**
```r
rwf(y, h = h, drift = TRUE, lambda = 0)                    # geri dönüşüm: medyan
rwf(y, h = h, drift = TRUE, lambda = 0, biasadj = TRUE)    # ortalama
```
TL cinsinden beklenen kazanç/kayıp için ortalama, "yarı yarıya" yorumu için medyan raporlanır. Olasılık bu seçimden etkilenmez.

---

## Adım 8: Sonuç ve karar (Bölüm 1.2)

Kitap tahmin, hedef ve planlamayı ayırıyor: biz **tahmin** üretiyoruz, kararı (planlamayı) sen veriyorsun.

Sonuç tablosu (her seçilen yöntem için):

| Yöntem | Veri penceresi | Nokta tahmini (TL) | %80 aralık | %95 aralık | P(fiyat < eşik) | tsCV RMSE (h = 43) |
|---|---|---|---|---|---|---|

Ardından tek paragraf: hangi yöntem kazandı, olasılık hangi aralıkta değişiyor, karar ne kadar sağlam?

---

## Adım 9: Gerçek değerlendirme (Bölüm 1.6, Adım 5)

1. Karar vermeden önce tahminler tarihli bir dosyaya yazılır ve sonradan değiştirilmez.
2. 22 Aralık kapanışı gelince gerçekleşen fiyat aralıkların içinde mi kaldı, karar doğru muydu? Bunlar kontrol edilir.
3. Tek gözlemle yöntem seçilemeyeceği yazılır; yöntem karşılaştırmasının asıl dayanağı Adım 6.3'tür.

> Derste yeni konular (ör. regresyon, üstel düzeltme, ARIMA) işlendikçe bu yöntemler Adım 5–7'deki aynı karşılaştırmaya eklenebilir. Şimdilik plan sadece ilk üç bölümle sınırlı.

---

## Klasör düzeni

```
zaman_serisi_R/
  PLAN.md              bu dosya
  BULGULAR.md          rapor iskeleti: her adımın tabloları, grafikleri ve yorumları
  takip_kodu.R         ders tarzında sade özet kod: her adımın sadece gerekli satırları (öğrenci takibi için)
  data/                ham CSV (değiştirilmez) + temiz veri + proje.rds
  01_veri.R            Adım 2: okuma, takvim düzenlemesi, ts nesnesi   ✅
  01b_pazar_tatil_karsilastirma.R   Adım 2 ek: tatil seçenekleri (2.3 tablosu); Pazar karşılaştırması arşiv (D1)
  02_kesif.R           Adım 3: keşif grafikleri, ACF   ✅
  03_donusum.R         Adım 4: Box-Cox, naive artıkları, Ljung-Box, histogram   ✅
  04_tahmin.R          Adım 5–7: yöntemler, tsCV, aralıklar, olasılık
  ciktilar/            grafikler ve tablolar
```
Çalışma dizini her zaman `zaman_serisi_R` olmalı. Ham CSV'nin adında Türkçe karakter olduğu için dosya adıyla değil `^GAU_TRY` kalıbıyla bulunur; birden fazla dosya varsa en yenisi kullanılır.

---

## Karar kaydı

| Tarih | Karar |
|---|---|
| 27 Ekim | Rakamlar: 5 gram, 1.500 TL BES farkı |
| 27 Ekim | Hafta sonu satırları çıkarıldı; Cuma'dan sonra Pazartesi gelir, aradaki günler piyasanın kapalı olduğu günler sayılır |
| 27 Ekim | İndirme günündeki yarım satır çıkarıldı; 2 tatil günü önceki kapanışla dolduruldu |
| 27 Ekim | Frekans = 5 (gerekçe Adım 2'de) |
| 9 Kasım | Pazar kararı onaylandı: Pazarsız seri (Pazarlar çıkarılır). Dayanak Bölüm 3.2 takvim düzenlemesi; karşılaştırma ders dışı betimsel kontrol, `01b_pazar_tatil_karsilastirma.R`: toplam değişim iki seride aynı (2,651032), Pazar gün içi aralığı %0,43 (hafta içi %1,45–1,58), Pazarlı seride haftalar 5 ya da 6 gözlem oluyor |
| 9 Kasım | Tatil kararı onaylandı: (a) eksik 2 hafta içi gün önceki kapanışla doldurulur. (b) ara değer kapalı piyasaya hareket uyduruyor; (c) boş bırakmak 18 Nisan 2025 sonrasındaki 393 gözlemin gün sırasını kaydırıyor |
| 11 Kasım | Dönüşüm: log (λ = 0). `BoxCox.lambda` 0,29 önerdi; log yorumlanabilir olduğu (log farkı ≈ yüzde değişim, günlük değişimler toplanabilir, eşik oran olarak yazılabilir) ve notlar "basit λ seçin" dediği için tercih edildi. λ = 0,29 istenirse Adım 7'de duyarlılık kontrolü olarak hesaplanabilir |
| 27 Ekim | Adım 5'teki dört yöntemin hepsi uygulanacak; hangisiyle devam edileceğine en sonda karar verilecek |
| 11 Kasım | Adım 6 onaylandı ve yapıldı: artık kontrolü, eğitim/test (son 43 gün), tsCV h = 43 (drift: tüm geçmiş / son 500 / son 250 gün). tsCV RMSE'de en iyi tüm geçmişle drift; 2026 başlangıçlarında naive daha iyi. Yöntem seçimi Adım 8'e bırakıldı |
| 12 Kasım | Adım 7 onaylandı ve yapıldı: normal ve bootstrap tahmin aralıkları, P(B) = P(fiyat < eşik). Naive %68, drift (tüm geçmiş) %37–38, drift (son 250 gün) ~%54. Duyarlılık: 2026 oynaklığı, λ = 0,29, biasadj |
| 12 Kasım | **Ana yöntem: Drift (son 250 gün).** Proje sahibinin kararı; gerekçe dış etkiler, 2026'daki yapısal değişim ve Bölüm 1.4 ("yapısal değişiklikte yalnızca güncel veriyi kullanmayı seçebiliriz"). Not: tsCV'de 3. sırada, yani seçim yargıya dayalı. Sonuç: P(B) %54,8 (hafif B); naive %68,3 ve drift (tüm geçmiş) %38,0 karşı senaryo olarak raporlanır |
| 22 Kasım | Ders dışı gözden geçirme: D3 (normal dağılıma göre kuyruk tablosu) ve D7 (elle bootstrap simülasyonu, P(B) bootstrap sütunu) rapordan ve takip_kodu.R'den çıkarıldı; betiklerde "DERS DIŞI" diye işaretli arşiv olarak duruyor. `bootstrap = TRUE` aralıkları (ders içi) kaldı. D4, D5, D6, D8, D9 ve `tapply` açıklama sonrası karara bağlanacak |
| 22 Kasım | D4: `tsCV(window = 250/500)` çıkarıldı. Düz tsCV (Bölüm 3.4) kaldı; ana yöntem (son 250 gün drift) tsCV ile sınanmamış oldu, seçim yargıya dayalı (Bölüm 1.4). D9 (beklenen fark) kaldı, R'ın `biasadj` değerleriyle düzeltildi: −1.350 / +1.180 / −266 TL. `tapply` kaldı, takip_kodu.R'ye açıklaması eklendi. D5, D6, D8 açıklama sonrası karara bağlanacak |
| 22 Kasım | D5 (karar isabeti, "A deme oranı", 6_3 grafiği) ve D8 (2026 oynaklığıyla duyarlılık satırı) çıkarıldı; betiklerde not olarak duruyor. 6.3'e yıllara göre RMSE tablosu kondu. D6 (tahmin aralıkları / P(B), Bölüm 3.5) için karar bekleniyor: proje sahibi aralık kavramını derste görmediğini belirtti |
| 22 Kasım | D1: Pazarlı/Pazarsız karşılaştırma tabloları rapordan çıkarıldı, Pazar kararı ders içi gerekçeyle (Bölüm 2.1 frekans, 3.2 takvim düzenlemesi) kaldı. D2: tatil günlerini önceki kapanışla doldurma kaldı. Açık kalan: D6 (Adım 7 tahmin aralıkları ve P(B)) |
| 22 Kasım | D6: Adım 7 (tahmin aralıkları, Bölüm 3.5) kaldı. P(B) artık `pnorm` ile değil, `level` yöntemiyle bulunuyor (eşiğin sınıra denk geldiği aralık): naive %68,1, drift %38,0, son 250 gün drift **%55,0**; λ = 0,29 ile %73,6 / %46,4 / %55,2. 8.4'e ayrıca derste işlenen kısımla (nokta tahmini + RMSE) belirsizlik açıklaması eklendi: fark 109 TL, tipik 43 günlük hata 428–871 TL. Ders dışı gözden geçirme tamamlandı |
| 23 Kasım | Proje sahibinin isteğiyle ana yöntem `tsCV(window = 250)` ile sınandı (D4'ün sadece bu kısmı geri geldi; window = 500 hâlâ yok). Sonuç: tüm dönem RMSE 455,6, ikinci sırada (drift 427,9; naive 460,7); 2026'da en kötü (959,9). 12 Kasım notundaki "üçüncü sırada" ifadesi yanlıştı, düzeltildi. Yöntem seçimi sınama sonucuna göre yeniden değerlendirilecek |
| 23 Kasım | **Ana yöntem değişti: Drift (tüm geçmiş).** Proje sahibi, sınama sonucuna göre kitabın kuralını (tsCV'de en küçük RMSE, Bölüm 3.4) uyguladı. Sonuç: nokta 6.937,11 TL, P(B) %38 / P(A) %62, beklenen fark +1.180 TL → A'ya eğilim, belirsiz. Son 250 gün drift (%55) ve naive (%68) karşı senaryo |
| 23 Kasım | **Tarih güncellemesi yapıldı (son adım).** Proje sahibi tarihleri 28 Ekim / 28 Aralık yerine **22 Kasım / 22 Aralık** yaptı. Yeni CSV (`data/GAU_TRY Geçmiş Verileri 20Kasim.csv`, 1 Ocak 2021 – 20 Kasım 2026) eski dosyayla 22 Ekim'e kadar birebir aynı. 22 Kasım Pazar → son kapanış 20 Kasım: P₀ 5.747,72, eşik 6.047,72 (+%5,22), **h = 22**. 1.536 gözlem. Betiklerdeki sabit "43" ve tarihler parametreye bağlandı. tsCV h = 22 ile tekrarlandı: drift 294,7 / son 250 gün 296,1 / naive 296,8 → kural yine drift'i seçti, ana yöntem değişmedi. **Yeni sonuç: P(B) %58 (B'ye hafif eğilim)**; naive %77, son 250 gün %71. Önceki sürüm `zaman_serisi_R_proje_22Ekim.zip` içinde |
| 23 Kasım | **Senaryo netleştirildi:** BES kazancı yuvarlak 1.500 TL değil, BES'teki 33.443 TL × %30 × %15 = **1.504,94 TL**. Soru: 5 gram altının 22 Aralık'a kadar değer artışı bu kazancı geçer mi? Eşik 6.047,72 → **6.048,71 TL** (+%5,24). Sonuçlar neredeyse aynı: P(B) drift %58,4, son 250 gün %71,0, naive %76,9; beklenen fark −368 TL (B lehine) |
| **Sıradaki** | Adım 9: 22 Aralık 2026 kapanışı gelince gerçek değerlendirme |
