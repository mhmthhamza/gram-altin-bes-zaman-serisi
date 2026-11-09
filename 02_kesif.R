# Adım 3: Keşifsel analiz (PLAN.md, Adım 3; ders Bölüm 2)
# Model yok: sadece grafikler ve betimsel sayılar.
# Çalıştırma: çalışma dizini zaman_serisi_R  ->  Rscript 02_kesif.R   (önce 01_veri.R)
# Çıktılar : ciktilar/3_1_zaman_grafigi.png ... 3_6_acf.png

library(fpp2)

p    <- readRDS("data/proje.rds")
y    <- p$y
veri <- p$veri
dir.create("ciktilar", showWarnings = FALSE)
kaydet <- function(g, ad, w = 9, h = 4.5) ggsave(file.path("ciktilar", ad), g, width = w, height = h, dpi = 120)
yaz <- function(baslik) cat("\n==== ", baslik, " ====\n", sep = "")

# Aylık seri: her ayın son kapanışı (son ay yarım: VERI_BITIS tarihine kadar)
ay     <- format(veri$tarih, "%Y-%m")
aylik  <- ts(as.numeric(tapply(veri$kapanis, ay, function(x) tail(x, 1))), start = c(2021, 1), frequency = 12)

# ---- 3.1 Zaman grafiği (Bölüm 2.2) ------------------------------------------
# ts nesnesinin zaman ekseni "hafta" olduğu için okunabilirlik adına grafikte gerçek tarihler kullanılır
uzun <- rbind(data.frame(tarih = veri$tarih, deger = veri$kapanis,      seri = "Fiyat (TL)"),
              data.frame(tarih = veri$tarih, deger = log(veri$kapanis), seri = "log(Fiyat)"))
g <- ggplot(uzun, aes(tarih, deger)) + geom_line(linewidth = 0.4) +
  facet_wrap(~seri, ncol = 1, scales = "free_y") +
  labs(x = NULL, y = NULL, title = paste0("Gram altın günlük kapanış (Pzt–Cum, 2021 – ", format(max(veri$tarih), "%d.%m.%Y"), ")"))
kaydet(g, "3_1_zaman_grafigi.png", h = 6)

yaz("3.1 Yıllara göre ilk ve son kapanış")
yil <- format(veri$tarih, "%Y")
yt  <- data.frame(ilk = tapply(veri$kapanis, yil, head, 1), son = tapply(veri$kapanis, yil, tail, 1),
                  en_dusuk = tapply(veri$kapanis, yil, min), en_yuksek = tapply(veri$kapanis, yil, max))
yt$yil_ici_degisim_yuzde <- round(100 * (yt$son / yt$ilk - 1), 1)
print(round(yt, 1))
cat("Tüm dönemin zirvesi:", format(veri$tarih[which.max(veri$kapanis)]), "-", round(max(veri$kapanis), 2), "TL\n")

yaz("3.1 Grafikte sıçrama olarak görülen en büyük 6 günlük hareket (|log değişim|)")
d <- data.frame(tarih = veri$tarih[-1], log_degisim = round(diff(log(veri$kapanis)), 4))
print(head(d[order(-abs(d$log_degisim)), ], 6), row.names = FALSE)

# ---- 3.3 Mevsimsel grafik (Bölüm 2.4) ---------------------------------------
kaydet(ggseasonplot(aylik, year.labels = TRUE, year.labels.left = TRUE) +
         labs(y = "TL", title = "Mevsimsel grafik: ay sonu kapanışları"), "3_3_mevsimsel.png")
kaydet(ggseasonplot(aylik, polar = TRUE) +
         labs(y = "TL", title = "Kutupsal mevsimsel grafik"), "3_3_mevsimsel_polar.png", w = 6.5, h = 6.5)

# ---- 3.4 Mevsimsel alt seri grafiği (Bölüm 2.5) -----------------------------
kaydet(ggsubseriesplot(aylik) +
         labs(y = "TL", title = "Mevsimsel alt seri grafiği: ay sonu kapanışları"), "3_4_alt_seri.png")

yaz("3.3-3.4 Destek tablosu: her ayın kendi içindeki % değişimi (ay sonu / önceki ay sonu)")
aylik_deg <- 100 * (aylik / stats::lag(aylik, -1) - 1)
tab <- tapply(as.numeric(aylik_deg), cycle(aylik_deg), function(x) c(n = length(x), ort = mean(x), en_az = min(x), en_cok = max(x)))
tab <- do.call(rbind, tab); rownames(tab) <- month.abb
print(round(tab, 1))
cat("(Son ayın değeri", format(max(veri$tarih)), "tarihine kadardır)\n")

# ---- 3.5 Gecikme grafikleri (Bölüm 2.7) -------------------------------------
kaydet(gglagplot(y, lags = 9, do.lines = FALSE) +
         labs(title = "Gecikme grafikleri: y_t ile y_(t-k), renk = haftanın günü (1 = Pzt ... 5 = Cum)"),
       "3_5_gecikme.png", w = 9, h = 8)

# ---- 3.6 ACF (Bölüm 2.8) ----------------------------------------------------
kaydet(ggAcf(y, lag.max = 60) + labs(title = "Gram altın fiyatının ACF'si (korelogram)"), "3_6_acf.png")

yaz("3.6 Seçili gecikmelerde otokorelasyon r_k")
r <- acf(y, lag.max = 60, plot = FALSE)$acf[-1]
k <- c(1, 2, 5, 10, 20, 40, 60)
print(setNames(round(r[k], 3), paste0("r", k)))
cat(sprintf("Beyaz gürültü sınırı ±2/sqrt(T) = ±%.3f (T = %d) | sınırın dışında kalan çubuk: %d / 60\n",
            2 / sqrt(length(y)), length(y), sum(abs(r) > 2 / sqrt(length(y)))))
