# =====================================================================
# GRAM ALTIN - BES KARARI | ZAMAN SERİSİ TAKİP KODU (Bölüm 1-3, fpp2)
# Satır satır Ctrl + Enter ile çalıştır.
# Önce çalışma dizini proje klasörü olmalı:
#   setwd("C:/Users/Mehmet Hamza/Desktop/FİNANS TAHMİN/zaman_serisi_R")
# Sürüm: 22 Kasım güncellemesi (veri 20 Kasım 2026 kapanışına kadar, karar günü 22 Aralık)
# =====================================================================

library(fpp2)


#ADIM 1 - PROBLEM (Bölüm 1)
# 22 Aralık kapanışı eşiğin altındaysa B, üstündeyse A kazanır
# BES kazancı = 33443 TL x %30 x %15 = 1504.94 TL (22 Aralık)
# Eşik = son kapanış + 1504.94 / 5 gram  (5 gram altının artışı BES kazancını geçerse A)
# Ufuk h = 22 iş günü (23 Kasım - 22 Aralık)


#ADIM 2 - VERİ (Bölüm 2.1, 3.2)
# Temizlik 01_veri.R'de yapıldı: Pazarlar çıkarıldı, 2 tatil günü önceki kapanışla dolduruldu.
# Burada hazır temiz veriyi okuyoruz.
veri <- read.csv("data/gram_altin_temiz.csv")
head(veri)
tail(veri)                      # son satır 20 Kasım 2026 (Cuma); 22 Kasım Pazar olduğu için yok

# ts nesnesi: frekans 5 = haftanın 5 iş günü, ilk gün (1 Ocak 2021) Cuma -> start = c(1, 5)
y <- ts(veri$kapanis, start = c(1, 5), frequency = 5)
length(y)                       # 1536 gözlem

P0   <- tail(veri$kapanis, 1)   # son kapanış: 5747.723
bes_kazanc <- 33443 * 0.30 * 0.15   # 1504.935 TL: BES kazancı
esik <- P0 + bes_kazanc / 5       # eşik: 6048.710 (gram başına 300.99 TL artış gerekiyor)
h    <- 22                      # 23 Kasım - 22 Aralık arası hafta içi gün sayısı
log(esik / P0)                  # 0.0510 -> 22 günde gereken log artış (yaklaşık %5.24)


#ADIM 3 - KEŞİF (Bölüm 2)
# Zaman grafiği: 2021-2025 güçlü trend, 2026'da yatay ve Kasım'da sert düşüş
autoplot(y)
# Log ölçekte neredeyse düz çizgi -> sabit yüzde büyüme
autoplot(log(y))

# Mevsimsel grafikler için aylık seri (her ayın son kapanışı)
# tapply(veri, grup, fonksiyon): veriyi gruplara ayırıp her gruba aynı fonksiyonu uygular
#   substr(veri$tarih, 1, 7) -> "2021-01-29" yerine "2021-01" (her gün kendi ayının grubuna girer)
#   tail, 1                  -> her grubun son değeri = ayın son kapanışı (Ocak 2021 -> 434.84)
aylik <- ts(as.numeric(tapply(veri$kapanis, substr(veri$tarih, 1, 7), tail, 1)),
            start = c(2021, 1), frequency = 12)
ggseasonplot(aylik)             # yılların ortak bir deseni yok
ggsubseriesplot(aylik)          # ay ortalamaları: mevsimsellik yok

# Gecikme grafikleri ve ACF
gglagplot(y, lags = 9)          # noktalar köşegen üzerinde -> trend
ggAcf(y)                        # yavaş azalan ACF -> trend, beyaz gürültü değil


#ADIM 4 - DÖNÜŞÜM ve ARTIKLAR (Bölüm 3.2, 3.3)
# Box-Cox: R 0.084 öneriyor (neredeyse log), biz yorumu kolay olduğu için log (lambda = 0) seçtik
BoxCox.lambda(y)

# Log fiyata naive -> artıklar = günlük log değişim (kitaptaki goog200 örneği gibi)
res <- residuals(naive(log(y)))
autoplot(res)

# Gerekli özellik: ortalama sıfır mı?
mean(res, na.rm = TRUE)               # 0.00165 > 0 -> naive yanlı, drift gerekli
22 * mean(res, na.rm = TRUE)          # 0.036 -> eşiğin (0.0510) altında

# Sadece 2026'ya bakınca:
res2026 <- res[veri$tarih >= "2026-01-01"]
22 * mean(res2026)                    # -0.003 -> 2026'da ortalama düşüş

# Gerekli özellik: artıklar ilişkisiz mi?
ggAcf(res)                                           # birkaç küçük çubuk sınır dışında
Box.test(res, lag = 10, fitdf = 0, type = "Ljung")   # p = 0.0005 < 0.05 -> tam beyaz gürültü değil
Box.test(res, lag = 10, fitdf = 0)                   # Box-Pierce, aynı sonuç

# Yararlı özellikler: sabit varyans, normal dağılım
gghistogram(res, add.normal = TRUE)   # uzun kuyruk -> normal tahmin aralıkları şüpheli

# Hepsi bir arada
checkresiduals(naive(log(y)))


#ADIM 5 - KIYASLAMA YÖNTEMLERİ (Bölüm 3.1)
# Dört yöntem, log ölçekte (lambda = 0), 22 gün ileri
fc1 <- meanf(y, h = h, lambda = 0)               # ortalama
fc2 <- naive(y, h = h, lambda = 0)               # son değer
fc3 <- snaive(y, h = h, lambda = 0)              # geçen haftanın aynı günü
fc4 <- rwf(y, h = h, lambda = 0, drift = TRUE)   # drift

# 22. gün (22 Aralık) tahminleri  -> eşik 6048.71
tail(fc1$mean, 1)    # 1883.28 -> altında (B)  (tüm geçmişin ortalaması, trendli seride anlamsız)
tail(fc2$mean, 1)    # 5747.72 -> altında (B)
tail(fc3$mean, 1)    # 6241.21 -> üstünde (A)  (geçen Salı'nın değeri, anlamsız: mevsimsellik yok)
tail(fc4$mean, 1)    # 5960.67 -> altında (B)

# Drift'in eğimi: ilk ve son gözlemi birleştiren çizgi (log ölçekte)
(log(tail(y, 1)) - log(y[1])) / (length(y) - 1)   # 0.00165 = Adım 4'teki artık ortalamasıyla aynı

# Grafik (kitaptaki goog200 örneği gibi)
autoplot(window(y, start = 252)) +
  autolayer(fc2, series = "Naive", PI = FALSE) +
  autolayer(fc3, series = "Mevsimsel naive", PI = FALSE) +
  autolayer(fc4, series = "Drift", PI = FALSE) +
  geom_hline(yintercept = esik, linetype = "dashed")


#ADIM 6 - DOĞRULUK DEĞERLENDİRMESİ (Bölüm 3.3, 3.4)

# 6.1 Artık kontrolü: drift'in artık ortalaması sıfır, naive'inki değil
checkresiduals(fc4)     # drift: ortalama 0, ACF naive ile aynı (p = 0.0005; drift'in 1 parametresi sayılırsa K=1 -> p = 0.0003)
checkresiduals(fc3)     # mevsimsel naive: çok güçlü otokorelasyon -> kötü yöntem

# 6.2 Eğitim / test: son 22 günü saklayıp tahmin et (kitaptaki goog örneği gibi)
n      <- length(y)
egitim <- subset(y, end = n - h)            # 21 Ekim 2026'ya kadar
test   <- subset(y, start = n - h + 1)      # son 22 gün (22 Ekim - 20 Kasım)
f2 <- naive(egitim, h = h, lambda = 0)
f3 <- snaive(egitim, h = h, lambda = 0)
f4 <- rwf(egitim, h = h, lambda = 0, drift = TRUE)
accuracy(f2, test)      # naive  RMSE 322  (fiyat düştü, en az yanılan naive)
accuracy(f3, test)      # snaive RMSE 340
accuracy(f4, test)      # drift  RMSE 459  (fiyat düşerken drift artış bekledi)
autoplot(subset(y, start = n - 300)) +
  autolayer(f3, series = "Mevsimsel naive", PI = FALSE) +
  autolayer(f2, series = "Naive", PI = FALSE) +
  autolayer(f4, series = "Drift", PI = FALSE)

# 6.3 Zaman serisi çapraz doğrulama (tsCV): her gün için 22 gün ileri tahmin
# (her satır ~5-10 saniye sürebilir)
e2 <- tsCV(y, naive, h = h, lambda = 0)
e3 <- tsCV(y, snaive, h = h, lambda = 0)
e4 <- tsCV(y, rwf, drift = TRUE, h = h, lambda = 0)
# Son 250 gün drift'in sınanması: window = 250 her başlangıçta sadece son 250 günü kullanır
# (window argümanı derste yok, bu yöntemi sınamanın tek yolu bu)
e5 <- tsCV(y, rwf, drift = TRUE, h = h, lambda = 0, window = 250)

# Hepsini aynı başlangıç günleriyle kıyasla (500. gün = Aralık 2022'den itibaren;
# ilk ~2 yılda drift eğimi çok az veriyle hesaplandığı için dışarıda)
t0 <- 500:(n - h)
sqrt(mean(e2[t0, h]^2))   # naive          RMSE 296.8
sqrt(mean(e3[t0, h]^2))   # snaive         RMSE 318.7
sqrt(mean(e4[t0, h]^2))   # drift          RMSE 294.7  -> en küçük (kitabın kuralına göre en iyi, fark çok az)
sqrt(mean(e5[t0, h]^2))   # drift son 250  RMSE 296.1  -> ikinci

# Ufka göre hata (kitaptaki MSE - h grafiği gibi)
mse <- colMeans(e4[t0, ]^2)
data.frame(h = 1:h, MSE = mse) %>%
  ggplot(aes(x = h, y = MSE)) + geom_point()

# Sadece 2026 başlangıçları: tablo tersine dönüyor
t26 <- t0[veri$tarih[t0] >= "2026-01-01"]
sqrt(mean(e2[t26, h]^2))   # naive 449  -> 2026'da en iyi
sqrt(mean(e4[t26, h]^2))   # drift 556
sqrt(mean(e5[t26, h]^2))   # drift son 250 gün 561 -> 2026'da en kötü (pencere 2025 yükselişini içeriyordu)


#ADIM 7 - TAHMİN ARALIKLARI ve KARAR OLASILIĞI (Bölüm 3.5)

# 7.1 R'ın hazır tahmin aralıkları (%80 ve %95), 22. gün
fc2                                     # naive: tablonun son satırı 22. gün
fc2$lower[h, ]; fc2$upper[h, ]          # %80: 5258.72-6282.20   %95: 5016.93-6584.97
fc4$lower[h, ]; fc4$upper[h, ]          # %80: 5452.99-6515.61   %95: 5201.98-6830.00
autoplot(fc2) + geom_hline(yintercept = esik, linetype = "dashed")   # eşik aralığın içinde
autoplot(fc4) + geom_hline(yintercept = esik, linetype = "dashed")

# 7.2 Kitaptaki formülle elle hesap (log ölçekte)
r     <- na.omit(res)                   # Adım 4'teki günlük log değişimler
sigma <- sd(r)                          # 0.01470
s_naive <- sigma * sqrt(h)                        # naive:  sigma * sqrt(h)        = 0.0690
s_drift <- sigma * sqrt(h * (1 + h / length(r)))  # drift:  sigma * sqrt(h(1+h/T)) = 0.0695
exp(log(P0) + c(-1.96, 1.96) * s_naive)  # naive %95 elle: 5020.97-6579.66 (R: 5017-6585)
# küçük fark: R naive'de sigma'yı sqrt(mean(r^2)) = 0.01479 alıyor (artık ortalaması 0 değil)

# 7.3 Karar olasılığı: P(B) = P(22 Aralık fiyatı < eşik)  -> sadece level ile
# Fikir: aralığı (level) daraltıp genişleterek sınırını tam eşiğe (6048.71) denk getir
# Naive: nokta (5747.72) eşiğin ALTINDA -> eşik aralığın ÜST sınırına gelmeli
naive(y, h = h, lambda = 0, level = 53.8)$upper[h]          # 6048.7 = eşik
# %53.8 içeride, kalan %46.2 iki yana eşit: %23.1 altta, %23.1 üstte
# P(B) = içerisi + alt kısım = 53.8 + 23.1 = yaklaşık %77  -> B daha olası
# Drift: nokta (5960.67) de eşiğin ALTINDA -> eşik yine aralığın ÜST sınırına gelmeli
rwf(y, h = h, lambda = 0, drift = TRUE, level = 16.7)$upper[h] # 6048.6 = eşik
# P(B) = 16.7 + (100 - 16.7) / 2 = 16.7 + 41.65 = yaklaşık %58  -> B biraz daha olası
# (level değerlerini deneme-yanılmayla bulabilirsin: sınır eşiğin altındaysa level'ı büyüt, üstündeyse küçült)

# 7.4 Bootstrap aralıkları (normal varsayımı yerine geçmiş günlük değişimlerden rastgele çekiliş)
naive(y, h = h, lambda = 0, bootstrap = TRUE)               # aralıklar normaldekine çok yakın

# 7.5 Ortalama mı medyan mı? (Bölüm 3.2 yanlılık düzeltmesi)
tail(naive(y, h = h, lambda = 0, biasadj = TRUE)$mean, 1)  # 5761.56 (medyan 5747.72, +14 TL)
# karar "eşiğin altında mı" sorusu -> medyan ve olasılık daha uygun


#ADIM 8 - SONUÇ ve KARAR (Bölüm 1.2, 3.4)
# Seçilen yöntem: DRIFT (TÜM GEÇMİŞ) = fc4
# Gerekçe: tsCV'de en küçük RMSE (294.7) -> kitabın kuralı (Bölüm 3.4); artık ortalaması 0 (Bölüm 3.3)
# Süreç: önce yargıyla son 250 gün drift seçilmişti; tsCV'de 2. çıktı -> tüm geçmiş drift'e geçildi
#        22 Kasım güncellemesinde (h = 22) sıralama değişmedi, ama fark çok küçük (294.7 / 296.1 / 296.8)
# Zayıf yönü: 2026'da drift'in hatası (556) naive'den (449) büyük

tail(fc4$mean, 1)                                        # 5960.67 -> eşiğin 88 TL altında
fc4$lower[h, ]; fc4$upper[h, ]                           # %80: 5453-6516   %95: 5202-6830
autoplot(fc4) + geom_hline(yintercept = esik, linetype = "dashed")

# Eşiğin altında kalma olasılığı (Adım 7'deki level yöntemi)
rwf(y, h = h, lambda = 0, drift = TRUE, level = 16.7)$upper[h]   # 6048.6 = eşik (üst sınır)
# P(B) = %16.7 + %41.65 = %58, P(A) = %42 -> B biraz daha olası

# Karşı senaryo: son 1 yılın eğilimi (ilk seçilen yöntem)
y250 <- subset(y, start = n - 249)                       # son 250 gün (8 Aralık 2025'ten itibaren)
fc5  <- rwf(y250, h = h, lambda = 0, drift = TRUE)
tail(fc5$mean, 1)                                        # 5748.62 -> son 1 yıl neredeyse yatay, eşiğin 300 TL altında
rwf(y250, h = h, lambda = 0, drift = TRUE, level = 42)$upper[h]   # 6048.7 = eşik -> P(B) = %71

# Sonuç tablosu: üç senaryo
data.frame(yontem = c("Drift tüm geçmiş (ANA)", "Drift son 250 gün", "Naive"),
           P_B    = c(0.5 + 16.7 / 200, 0.5 + 42 / 200, 0.5 + 53.8 / 200))
# %58 / %71 / %77  -> bütün senaryolar B; ana yönteme göre B'ye hafif eğilim

# Aynı sonuç, sadece nokta tahmini ve RMSE ile (derste işlenen kısım):
esik - tail(fc4$mean, 1)          # 88 TL: tahmin eşiğin bu kadar altında
sqrt(mean(e4[t0, h]^2))           # 295 TL: drift'in 22 gün sonraki tipik hatası
sqrt(mean(e4[t26, h]^2))          # 556 TL: drift'in 2026'daki tipik hatası
# tipik hata, farkın 3-6 katı -> tahmin B diyor ama karar belirsiz

# Beklenen fark: A'nın B'ye göre ortalama TL farkı = 5 x (beklenen fiyat - eşik)
# beklenen fiyat = biasadj = TRUE ile ortalama (Bölüm 3.2)
ort4 <- tail(rwf(y, h = h, lambda = 0, drift = TRUE, biasadj = TRUE)$mean, 1)   # 5975.05
5 * (ort4 - esik)                                        # -368 TL -> ortalamada B 368 TL önde


#ADIM 9 - GERÇEK DEĞERLENDİRME (Bölüm 1.6)  -> 22 Aralık kapanışı gelince
