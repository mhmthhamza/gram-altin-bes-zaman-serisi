# Adım 4: Dönüşüm ve günlük değişimler (PLAN.md, Adım 4; ders Bölüm 2.9, 3.2, 3.3)
# Log fiyata naive uygulanır; artıkları = günlük log değişim. Tahmin yapılmaz, sadece artıklar incelenir.
# Çalıştırma: çalışma dizini zaman_serisi_R  ->  Rscript 03_donusum.R   (önce 01_veri.R)
# Çıktılar : ciktilar/4_*.png

library(fpp2)

p    <- readRDS("data/proje.rds")
y    <- p$y
veri <- p$veri
dir.create("ciktilar", showWarnings = FALSE)
kaydet <- function(g, ad, w = 9, h = 4.5) ggsave(file.path("ciktilar", ad), g, width = w, height = h, dpi = 120)
yaz <- function(baslik) cat("\n==== ", baslik, " ====\n", sep = "")

# ---- 4.1 Box-Cox / log dönüşümü (Bölüm 3.2) ---------------------------------
yaz("4.1 BoxCox.lambda ile önerilen lambda")
lam <- BoxCox.lambda(y)
cat(sprintf("lambda = %.3f  (0 = log dönüşümü, 1 = dönüşüm yok)\n", lam))

# ---- 4.2 Naive yöntemin artıkları = günlük log değişim (Bölüm 3.3) -----------
res <- residuals(naive(log(y)))          # e_t = log y_t - log y_(t-1)
e   <- as.numeric(res)[-1]
tarih <- veri$tarih[-1]

g <- ggplot(data.frame(tarih, e), aes(tarih, e)) + geom_line(linewidth = 0.3) +
  labs(x = NULL, y = "log y(t) - log y(t-1)", title = "Log fiyata naive: artıklar (günlük log değişim)")
kaydet(g, "4_2_artik_zaman.png")

yaz("4.2 Artıkların özeti")
cat(sprintf("n = %d | ortalama = %.5f | std = %.5f | en küçük = %.4f | en büyük = %.4f\n",
            length(e), mean(e), sd(e), min(e), max(e)))
cat(sprintf("Ortalama günlük değişim %.5f, %d iş gününe ölçeklenince %.4f (yaklaşık %%%.1f)\n",
            mean(e), p$h, p$h * mean(e), 100 * (exp(p$h * mean(e)) - 1)))

yaz("4.2 Yıllara göre artıkların ortalaması ve standart sapması (sabit varyans kontrolü)")
yil <- format(tarih, "%Y")
print(round(data.frame(n = as.vector(table(yil)), ortalama = tapply(e, yil, mean), std = tapply(e, yil, sd)), 5))

# ---- 4.3 Beyaz gürültü mü? (Bölüm 2.9, 3.3) ---------------------------------
kaydet(ggAcf(res, lag.max = 60) + labs(title = "Artıkların (günlük log değişim) ACF'si"), "4_3_artik_acf.png")

yaz("4.3 ACF: ilk 10 gecikme ve sınır dışı çubuklar")
r   <- acf(e, lag.max = 60, plot = FALSE)$acf[-1]
sinir <- 2 / sqrt(length(e))
print(setNames(round(r[1:10], 3), paste0("r", 1:10)))
cat(sprintf("Sınır ±2/sqrt(T) = ±%.3f | 60 gecikmeden sınır dışında: %d (şans eseri beklenen ≈ %.0f) -> gecikmeler: %s\n",
            sinir, sum(abs(r) > sinir), 0.05 * 60, paste(which(abs(r) > sinir), collapse = ", ")))

yaz("4.3 Portmanteau testleri (h = 10, K = 0)")
print(Box.test(res, lag = 10, fitdf = 0))
print(Box.test(res, lag = 10, fitdf = 0, type = "Lj"))
cat(sprintf("Karşılaştırma: chi-kare(10) için %%5 kritik değer = %.2f\n", qchisq(0.95, 10)))

yaz("4.3 Duyarlılık: sonuç 2021 şokuna mı bağlı? (aynı test, farklı başlangıç tarihleri)")
for (bas in c("2021-01-01", "2022-01-01", "2023-01-01")) {
  x  <- e[tarih >= as.Date(bas)]
  lb <- Box.test(x, lag = 10, fitdf = 0, type = "Lj")
  rx <- acf(x, lag.max = 10, plot = FALSE)$acf[-1]
  cat(sprintf("%s sonrası: T = %4d | Q* = %6.2f | p = %.4f | en büyük |r_k| (k<=10) = %.3f (k = %d) | sınır ±%.3f\n",
              bas, length(x), lb$statistic, lb$p.value, max(abs(rx)), which.max(abs(rx)), 2 / sqrt(length(x))))
}

# ---- 4.4 Histogram ve normallik (Bölüm 3.3) ---------------------------------
kaydet(gghistogram(res, add.normal = TRUE) + labs(x = "günlük log değişim", y = "gün sayısı", title = "Artıkların histogramı (eğri: aynı ortalama ve std ile normal)"),
       "4_4_artik_histogram.png")

# DERS DIŞI (D3) - 22 Kasım kararıyla rapordan çıkarıldı; sadece arşiv için duruyor
yaz("4.4 Kuyruklar: normal dağılıma göre beklenen ve gözlenen uç gün sayısı (basit kontrol)")
z <- (e - mean(e)) / sd(e)
uc <- data.frame(esik = c("|z| > 2", "|z| > 3", "|z| > 4"),
                 gozlenen = c(sum(abs(z) > 2), sum(abs(z) > 3), sum(abs(z) > 4)),
                 normalde_beklenen = round(length(z) * 2 * pnorm(-c(2, 3, 4)), 1))
print(uc, row.names = FALSE)
cat(sprintf("Ortadaki yoğunluk: |z| < 0.5 olan gün oranı %%%.1f (normalde %%%.1f)\n",
            100 * mean(abs(z) < 0.5), 100 * (2 * pnorm(0.5) - 1)))

# ---- 4.5 Haftanın günlerine göre günlük değişim (Bölüm 2.5) -----------------
# İlk değer (NA) atılır; y ekseni ±0,05'e yakınlaştırılır, yoksa uç günler ortalama çizgilerini görünmez kılar
res2 <- window(res, start = time(res)[2])
kaydet(ggsubseriesplot(res2) + coord_cartesian(ylim = c(-0.05, 0.05)) +
         labs(x = "Haftanın günü (1 = Pzt ... 5 = Cum)", y = "günlük log değişim",
              title = "Alt seri grafiği: günlük değişim, haftanın günlerine göre (y ekseni ±0,05)"),
       "4_5_gun_alt_seri.png")

yaz("4.5 Haftanın gününe göre günlük log değişim")
gun <- factor(c("Pzt", "Sal", "Çar", "Per", "Cum")[cycle(res)[-1]], levels = c("Pzt", "Sal", "Çar", "Per", "Cum"))
print(round(data.frame(n = as.vector(table(gun)), ortalama = tapply(e, gun, mean), std = tapply(e, gun, sd)), 5))
