# Adım 5-7: Tahmin (PLAN.md; ders Bölüm 3.1, 3.4, 3.5)
# Bu dosya adım adım büyüyecek. Şu an: Adım 5 (dört kıyaslama yöntemi, log ölçekte, h = karar gününe kadar iş günü).
# Çalıştırma: çalışma dizini zaman_serisi_R  ->  Rscript 04_tahmin.R   (önce 01_veri.R)
# Çıktılar : ciktilar/5_*.png

library(fpp2)

p    <- readRDS("data/proje.rds")
y    <- p$y
h    <- p$h
P0   <- p$P0
esik <- p$esik
dir.create("ciktilar", showWarnings = FALSE)
kaydet <- function(g, ad, w = 9, h = 4.5) ggsave(file.path("ciktilar", ad), g, width = w, height = h, dpi = 120)
yaz <- function(baslik) cat("\n==== ", baslik, " ====\n", sep = "")

# ---- Adım 5: dört kıyaslama yöntemi (Bölüm 3.1), lambda = 0 ------------------
fc_ort    <- meanf (y, h = h, lambda = 0)
fc_naive  <- naive (y, h = h, lambda = 0)
fc_snaive <- snaive(y, h = h, lambda = 0)
fc_drift  <- rwf   (y, h = h, lambda = 0, drift = TRUE)
yontemler <- list(Ortalama = fc_ort, Naive = fc_naive, "Mevsimsel naive" = fc_snaive, Drift = fc_drift)

yaz(sprintf("5.1 %d. gün (karar günü) nokta tahminleri", h))
tablo <- data.frame(
  yontem       = names(yontemler),
  tahmin_TL    = round(sapply(yontemler, function(f) tail(f$mean, 1)), 2),
  P0a_gore     = sprintf("%+.2f%%", 100 * (sapply(yontemler, function(f) tail(f$mean, 1)) / P0 - 1)),
  esige_gore   = ifelse(sapply(yontemler, function(f) tail(f$mean, 1)) > esik, "ÜSTÜNDE (A)", "altında (B)")
)
print(tablo, row.names = FALSE)
cat(sprintf("Karşılaştırma: P0 = %.2f TL, eşik = %.2f TL (%+.2f%%)\n", P0, esik, 100 * (esik / P0 - 1)))

yaz("5.2 Yöntemlerin dayandığı tek sayılar")
cat(sprintf("Ortalama: tüm log fiyatların ortalaması = %.4f -> exp = %.2f TL\n", mean(log(y)), exp(mean(log(y)))))
cat(sprintf("Naive   : son gözlem = %.2f TL\n", P0))
cat("Mevsimsel naive: son haftanın aynı günü. Son 5 gün (", paste(format(tail(p$veri$tarih, 5), "%a"), collapse = ","), "):",
    paste(round(tail(y, 5), 2), collapse = ", "), "\n")
drift_egim <- (log(y[length(y)]) - log(y[1])) / (length(y) - 1)
cat(sprintf("Drift   : eğim = (log y_T - log y_1)/(T-1) = %.6f/gün -> %d günde %.4f (%+.2f%%)\n",
            drift_egim, h, h * drift_egim, 100 * (exp(h * drift_egim) - 1)))

yaz("5.3 Haftalık ara noktalar (Naive ve Mevsimsel naive aynı mı?)")
adim <- sort(unique(c(c(1, 2, 3, 4, 5, 10, 20, 30)[c(1, 2, 3, 4, 5, 10, 20, 30) < h], h)))
print(data.frame(adim, naive = round(fc_naive$mean[adim], 1), mevsimsel_naive = round(fc_snaive$mean[adim], 1),
                 drift = round(fc_drift$mean[adim], 1)), row.names = FALSE)

# Grafik: son 1 yıl + h günlük tahminler, eşik kesikli çizgi
son_yil <- window(y, start = time(y)[length(y) - 260])
g <- autoplot(son_yil) +
  autolayer(fc_ort,    series = "Ortalama",        PI = FALSE) +
  autolayer(fc_naive,  series = "Naive",           PI = FALSE) +
  autolayer(fc_snaive, series = "Mevsimsel naive", PI = FALSE) +
  autolayer(fc_drift,  series = "Drift",           PI = FALSE) +
  geom_hline(yintercept = esik, linetype = "dashed", colour = "red") +
  annotate("text", x = time(son_yil)[20], y = esik, vjust = -0.5, colour = "red",
           label = paste("eşik", format(round(esik, 2), big.mark = ".", decimal.mark = ",", nsmall = 2), "TL")) +
  labs(x = "Hafta (1 = Ocak 2021'in ilk haftası)", y = "TL",
       title = sprintf("Kıyaslama yöntemleriyle %d iş günlük tahmin (son 1 yıl + tahmin)", h)) +
  guides(colour = guide_legend(title = "Yöntem"))
kaydet(g, "5_1_kiyaslama_tahminleri.png")

# Ortalama yöntemi çok aşağıda kaldığı için ayrıca yakın plan (ortalamasız)
g2 <- autoplot(son_yil) +
  autolayer(fc_naive,  series = "Naive",           PI = FALSE) +
  autolayer(fc_snaive, series = "Mevsimsel naive", PI = FALSE) +
  autolayer(fc_drift,  series = "Drift",           PI = FALSE) +
  geom_hline(yintercept = esik, linetype = "dashed", colour = "red") +
  labs(x = "Hafta (1 = Ocak 2021'in ilk haftası)", y = "TL",
       title = "Yakın plan: Naive, Mevsimsel naive ve Drift (kesikli çizgi: eşik)") +
  guides(colour = guide_legend(title = "Yöntem"))
kaydet(g2, "5_2_kiyaslama_yakin.png")

# =====================================================================
# ---- Adım 6: doğruluk değerlendirmesi (Bölüm 3.3, 3.4) ----------------
# =====================================================================
n      <- length(y)
tarih  <- as.Date(p$veri$tarih)
oran   <- esik / P0                    # eşik / son fiyat = 1.0466 (her başlangıç için aynı oran)

yaz("6.1 Artık kontrolü (Bölüm 3.3) - log ölçekte, Ljung-Box lag = 10")
for (ad in c("Naive", "Mevsimsel naive", "Drift")) {
  r  <- residuals(yontemler[[ad]])     # lambda = 0 -> artıklar log ölçekte
  K  <- ifelse(ad == "Drift", 1, 0)
  bt <- Box.test(r, lag = 10, fitdf = K, type = "Ljung")
  cat(sprintf("%-16s ortalama = %+.6f  sd = %.5f  Q* = %6.2f  p = %.5f\n",
              ad, mean(r, na.rm = TRUE), sd(r, na.rm = TRUE), bt$statistic, bt$p.value))
}

yaz(sprintf("6.2 Eğitim / test ayrımı (Bölüm 3.4): son %d gün test", h))
egitim <- subset(y, end = n - h)
test   <- subset(y, start = n - h + 1)
cat(sprintf("Eğitim: 1..%d (%s'e kadar)  Test: %d..%d (%s - %s)\n", n - h, tarih[n - h],
            n - h + 1, n, tarih[n - h + 1], tarih[n]))
tt <- list(Ortalama          = meanf (egitim, h = h, lambda = 0),
           Naive             = naive (egitim, h = h, lambda = 0),
           "Mevsimsel naive" = snaive(egitim, h = h, lambda = 0),
           Drift             = rwf   (egitim, h = h, lambda = 0, drift = TRUE))
acc <- t(sapply(tt, function(f) accuracy(f, test)["Test set", c("RMSE", "MAE", "MAPE", "MASE")]))
print(round(acc, 3))
P0_tt   <- y[n - h]
esik_tt <- P0_tt * oran
cat(sprintf("Bu ayrımda başlangıç fiyatı %.2f, eşik %.2f, gerçek %d. gün %.2f -> gerçek: %s\n",
            P0_tt, esik_tt, h, y[n], ifelse(y[n] > esik_tt, "A", "B")))
print(data.frame(yontem = names(tt),
                 tahmin_son = round(sapply(tt, function(f) tail(f$mean, 1)), 2),
                 karar = ifelse(sapply(tt, function(f) tail(f$mean, 1)) > esik_tt, "A", "B")), row.names = FALSE)

g <- autoplot(subset(y, start = n - 300)) +
  autolayer(tt$`Mevsimsel naive`, series = "Mevsimsel naive", PI = FALSE) +
  autolayer(tt$Naive,             series = "Naive",           PI = FALSE) +
  autolayer(tt$Drift,             series = "Drift",           PI = FALSE) +
  geom_hline(yintercept = esik_tt, linetype = "dashed", colour = "red") +
  labs(x = "Hafta", y = "TL", title = sprintf("Eğitim/test: son %d gün saklandı, tahminler gerçekle kıyaslanıyor (kesikli: o günkü eşik)", h)) +
  guides(colour = guide_legend(title = "Yöntem"))
kaydet(g, "6_1_egitim_test.png")

yaz(sprintf("6.3 Zaman serisi çapraz doğrulama (tsCV), h = %d", h))
e_ort    <- tsCV(y, meanf,  h = h, lambda = 0)
e_naive  <- tsCV(y, naive,  h = h, lambda = 0)
e_snaive <- tsCV(y, snaive, h = h, lambda = 0)
e_drift  <- tsCV(y, rwf, drift = TRUE, h = h, lambda = 0)
# (22 Kasım: window = 500 ders dışı olduğu için çıkarıldı - D4.
#  23 Kasım: proje sahibinin isteğiyle ana yöntem (son 250 gün drift) window = 250 ile sınanıyor.
#  window argümanı derste yok: her başlangıç gününde sadece son 250 günü kullanır.)
e_d250   <- tsCV(y, rwf, drift = TRUE, h = h, lambda = 0, window = 250)
E <- list(Ortalama = e_ort, Naive = e_naive, "Mevsimsel naive" = e_snaive, Drift = e_drift,
          "Drift (son 250 gün)" = e_d250)

# Ortak başlangıç günleri: 500. günden itibaren (ilk ~2 yılda drift eğimi az veriyle hesaplanıyor)
ortak <- 500:(n - h)
cat(sprintf("Ortak başlangıç günü sayısı: %d (%s - %s)\n", length(ortak), tarih[min(ortak)], tarih[max(ortak)]))

degerlendir <- function(e, satir) {
  hata   <- e[satir, h]                       # h. gün hatası (TL)
  gercek <- y[satir + h]
  tahmin <- gercek - hata
  esik_t <- y[satir] * oran
  # (22 Kasım: "karar isabeti" ve "A deme oranı" ders dışı olduğu için çıkarıldı - D5)
  c(RMSE = sqrt(mean(hata^2)), MAE = mean(abs(hata)), MAPE = mean(abs(100 * hata / gercek)))
}
s2026 <- ortak[tarih[ortak] >= as.Date("2026-01-01")]
cat("\n-- Tüm ortak başlangıçlar --\n")
print(round(t(sapply(E, degerlendir, satir = ortak)), 2))
cat(sprintf("\n-- Sadece 2026 başlangıçları (%d gün) --\n", length(s2026)))
print(round(t(sapply(E, degerlendir, satir = s2026)), 2))

# Yıllara göre RMSE (h. gün)
yil <- format(tarih[ortak], "%Y")
cat(sprintf("\n-- Başlangıç yılına göre %d. gün RMSE (TL) --\n", h))
print(round(sapply(E[-1], function(e) tapply(e[ortak, h]^2, yil, function(z) sqrt(mean(z)))), 1))

# Ufka göre RMSE (kitaptaki MSE - h grafiği gibi)
rmse_h <- sapply(E[-1], function(e) sqrt(colMeans(e[ortak, ]^2)))
cat("\n-- Ufka göre RMSE (seçili ufuklar) --\n")
print(round(rmse_h[sort(unique(pmin(c(1, 5, 10, 20, 30, h), h))), ], 1))
df <- data.frame(h = rep(1:h, ncol(rmse_h)), RMSE = as.vector(rmse_h),
                 yontem = rep(colnames(rmse_h), each = h))
g <- ggplot(df, aes(x = h, y = RMSE, colour = yontem)) + geom_line() + geom_point(size = 0.8) +
  labs(x = "Tahmin ufku (iş günü)", y = "RMSE (TL)", colour = "Yöntem",
       title = "tsCV: ufuk büyüdükçe hata artıyor (ortak başlangıç günleri)")
kaydet(g, "6_2_tscv_ufuk_rmse.png")

# (22 Kasım: 6_3 karar isabeti grafiği D5 ile birlikte çıkarıldı)

# =====================================================================
# ---- Adım 7: tahmin aralıkları ve karar olasılığı (Bölüm 3.5) ----------
# =====================================================================
set.seed(2026)
lr   <- residuals(naive(log(y)))                     # günlük log değişimler (Adım 4)
lr   <- lr[!is.na(lr)]
T_   <- length(lr)                                   # 1514
sig  <- sd(lr)                                       # artık sd (naive)
sigd <- sd(lr - mean(lr))                            # drift artık sd (aynı)
log_esik <- log(esik)

yaz(sprintf("7.1 %d. gün standart sapması (log ölçek) - kitaptaki formüller", h))
sh_naive <- sig  * sqrt(h)
sh_drift <- sigd * sqrt(h * (1 + h / T_))
cat(sprintf("sigma (artık sd) = %.5f\nNaive: sigma*sqrt(h)         = %.5f\nDrift: sigma*sqrt(h(1+h/T))  = %.5f\n",
            sig, sh_naive, sh_drift))
cat(sprintf("Gerçekleşen h günlük log değişimlerin sd'si (örtüşen pencereler) = %.5f\n",
            sd(diff(log(y), lag = h))))
for (yl in 2021:2026) {
  s <- sd(lr[format(tarih[-1], "%Y") == yl])
  cat(sprintf("  %d günlük sd = %.5f -> h gün: %.5f\n", yl, s, s * sqrt(h)))
}

yaz(sprintf("7.2 Normal tahmin aralıkları (%%80 / %%95), %d. gün, TL", h))
fcN <- list(Naive = naive(y, h = h, lambda = 0, level = c(80, 95)),
            Drift = rwf(y, h = h, lambda = 0, drift = TRUE, level = c(80, 95)))
for (ad in names(fcN)) {
  f <- fcN[[ad]]
  cat(sprintf("%-6s tahmin %.2f | %%80: [%.2f, %.2f] | %%95: [%.2f, %.2f]\n", ad, f$mean[h],
              f$lower[h, 1], f$upper[h, 1], f$lower[h, 2], f$upper[h, 2]))
}
cat(sprintf("Elle kontrol (naive %%95): exp(log(P0) ± 1.96*%.5f) = [%.2f, %.2f]\n", sh_naive,
            exp(log(P0) - 1.96 * sh_naive), exp(log(P0) + 1.96 * sh_naive)))

yaz("7.3 Eşiğin altında kalma olasılığı P(B) - level yöntemi (22 Kasım, D6)")
# Fikir: tahmin aralığını (level) eşik tam sınırına değene kadar daraltıp genişlet.
#  Nokta eşiğin altındaysa: %L aralığın üst sınırı = eşik  ->  P(B) = %L (içi) + (100-L)/2 (altı) = 0.5 + L/200
#  Nokta eşiğin üstündeyse: %L aralığın alt sınırı = eşik  ->  P(B) = (100-L)/2 = 0.5 - L/200
esik_seviyesi <- function(tahmin_fn) {
  m <- tahmin_fn(50)$mean[h]
  L <- uniroot(function(L) { f <- tahmin_fn(L); (if (m < esik) f$upper[h] else f$lower[h]) - esik },
               c(0.01, 99.9), tol = 1e-8)$root
  c(nokta = m, L = L, P_B = if (m < esik) 0.5 + L / 200 else 0.5 - L / 200)
}
y250 <- subset(y, start = n - 249)
seviye <- rbind(
  Naive                 = esik_seviyesi(function(L) naive(y, h = h, lambda = 0, level = L)),
  Drift                 = esik_seviyesi(function(L) rwf(y, h = h, lambda = 0, drift = TRUE, level = L)),
  "Drift (son 250 gün)" = esik_seviyesi(function(L) rwf(y250, h = h, lambda = 0, drift = TRUE, level = L)))
pB <- seviye[, "P_B"]
print(data.frame(yontem = rownames(seviye), nokta = round(seviye[, "nokta"], 2),
                 esigin_sinirda_oldugu_aralik = sprintf("%%%.1f", seviye[, "L"]),
                 P_B = round(100 * pB, 1), P_A = round(100 * (1 - pB), 1)), row.names = FALSE)
cat("Kontrol: aralık sınırları eşiğe eşit mi?\n")
for (ad in rownames(seviye)) {
  L <- round(seviye[ad, "L"], 1)
  f <- switch(ad, Naive = naive(y, h = h, lambda = 0, level = L),
              Drift = rwf(y, h = h, lambda = 0, drift = TRUE, level = L),
              rwf(y250, h = h, lambda = 0, drift = TRUE, level = L))
  cat(sprintf("  %-20s level = %.1f -> [%.1f, %.1f]  (eşik %.2f)\n", ad, L, f$lower[h], f$upper[h], esik))
}
# Eski yöntemle (pnorm, kendi sd hesabımız) karşılaştırma - sadece kontrol, raporda kullanılmıyor
olas <- function(merkez, s) pnorm((log_esik - merkez) / s)
merkez_naive <- log(P0); merkez_drift <- log(P0) + h * mean(lr)
lr250 <- tail(lr, 250)
merkez_d250 <- log(P0) + h * mean(lr250); sh_d250 <- sd(lr250) * sqrt(h * (1 + h / 250))
cat(sprintf("pnorm ile (kontrol): naive %.1f%%, drift %.1f%%, son 250 gün %.1f%%\n",
            100 * olas(merkez_naive, sh_naive), 100 * olas(merkez_drift, sh_drift), 100 * olas(merkez_d250, sh_d250)))

yaz("7.4 Bootstrap (Bölüm 3.5): forecast paketinin aralıkları")
fcB <- list(Naive = naive(y, h = h, lambda = 0, bootstrap = TRUE, npaths = 5000, level = c(80, 95)),
            Drift = rwf(y, h = h, lambda = 0, drift = TRUE, bootstrap = TRUE, npaths = 5000, level = c(80, 95)))
for (ad in names(fcB)) {
  f <- fcB[[ad]]
  cat(sprintf("%-6s tahmin %.2f | %%80: [%.2f, %.2f] | %%95: [%.2f, %.2f]\n", ad, f$mean[h],
              f$lower[h, 1], f$upper[h, 1], f$lower[h, 2], f$upper[h, 2]))
}

# DERS DIŞI (D7) - 22 Kasım kararıyla rapordan çıkarıldı; 7_3 grafiği ve P_B_boot sütunu raporda kullanılmıyor
yaz("7.5 Bootstrap ile P(B): artıklardan 43 gün yeniden örnekleme (10.000 yol)")
B <- 10000
# Naive: gelecekte ortalama değişim 0 -> artıklar merkezlenir; Drift: artıklar olduğu gibi (ortalama = eğim)
sim_naive <- replicate(B, sum(sample(lr - mean(lr), h, replace = TRUE)))
sim_drift <- replicate(B, sum(sample(lr, h, replace = TRUE)))
sim_d250  <- replicate(B, sum(sample(lr250, h, replace = TRUE)))
gerekli <- log_esik - log(P0)
pBb <- c(Naive = mean(sim_naive < gerekli), Drift = mean(sim_drift < gerekli),
         "Drift (son 250 gün)" = mean(sim_d250 < gerekli))
print(data.frame(yontem = names(pBb), P_B_normal = round(100 * pB, 1), P_B_bootstrap = round(100 * pBb, 1)),
      row.names = FALSE)
cat(sprintf("Simüle 43 günlük değişim sd: naive %.4f, drift %.4f (formül %.4f)\n",
            sd(sim_naive), sd(sim_drift), sh_naive))

yaz("7.6 Yanlılık düzeltmesi (Bölüm 3.2): medyan mi ortalama mı?")
for (ad in c("Naive", "Drift")) {
  f0 <- if (ad == "Naive") naive(y, h = h, lambda = 0) else rwf(y, h = h, lambda = 0, drift = TRUE)
  f1 <- if (ad == "Naive") naive(y, h = h, lambda = 0, biasadj = TRUE) else rwf(y, h = h, lambda = 0, drift = TRUE, biasadj = TRUE)
  cat(sprintf("%-6s medyan (biasadj=FALSE) %.2f | ortalama (biasadj=TRUE) %.2f | fark %.2f TL\n",
              ad, f0$mean[h], f1$mean[h], f1$mean[h] - f0$mean[h]))
}
cat("Karar 'fiyat eşiğin altında mı' sorusu olduğundan ilgili olan olasılık; medyan > eşik <=> P(A) > %50.\n")

lam <- BoxCox.lambda(y)
yaz(sprintf("7.7 Duyarlılık: lambda = %.3f (BoxCox.lambda önerisi)", lam))
fz <- y; bc <- BoxCox(fz, lam); d <- diff(bc)
bc_esik <- BoxCox(esik, lam); bc_P0 <- BoxCox(P0, lam)
pB_lam <- c(Naive = esik_seviyesi(function(L) naive(y, h = h, lambda = lam, level = L))["P_B"],
            Drift = esik_seviyesi(function(L) rwf(y, h = h, lambda = lam, drift = TRUE, level = L))["P_B"],
            D250  = esik_seviyesi(function(L) rwf(y250, h = h, lambda = lam, drift = TRUE, level = L))["P_B"])
cat(sprintf("lambda = %.3f -> P(B) (level yöntemi): naive %.1f%%, drift %.1f%%, son 250 gün drift %.1f%%\n",
            lam, 100 * pB_lam[1], 100 * pB_lam[2], 100 * pB_lam[3]))
cat(sprintf("Son 250 gün sd (BC ölçek) %.4f vs tüm dönem %.4f\n", sd(tail(d, 250)), sd(d)))

# Grafikler
yakin <- subset(y, start = n - 260)
g <- autoplot(yakin) + autolayer(fcN$Naive, series = "Naive") +
  geom_hline(yintercept = esik, linetype = "dashed", colour = "red") +
  labs(x = "Hafta", y = "TL", title = sprintf("Naive: %%80 ve %%95 tahmin aralığı  |  P(B) = %%%.1f", 100 * pB["Naive"])) +
  theme(legend.position = "none")
kaydet(g, "7_1_naive_aralik.png")
g <- autoplot(yakin) + autolayer(fcN$Drift, series = "Drift") +
  geom_hline(yintercept = esik, linetype = "dashed", colour = "red") +
  labs(x = "Hafta", y = "TL", title = sprintf("Drift: %%80 ve %%95 tahmin aralığı  |  P(B) = %%%.1f", 100 * pB["Drift"])) +
  theme(legend.position = "none")
kaydet(g, "7_2_drift_aralik.png")

df3 <- data.frame(fiyat = P0 * exp(c(sim_naive, sim_drift, sim_d250)),
                  yontem = factor(rep(c("Naive", "Drift (tüm geçmiş)", "Drift (son 250 gün)"), each = B),
                                  levels = c("Naive", "Drift (tüm geçmiş)", "Drift (son 250 gün)")))
g <- ggplot(df3, aes(x = fiyat)) + geom_histogram(bins = 60, fill = "grey60", colour = "white") +
  geom_vline(xintercept = esik, colour = "red", linetype = "dashed", linewidth = 1) +
  geom_vline(xintercept = P0, colour = "black") +
  facet_wrap(~ yontem, ncol = 1) +
  labs(x = "22 Aralık simüle kapanış (TL)", y = "Yol sayısı",
       title = "Bootstrap: 10.000 olası gelecek. Kırmızı çizginin solu = B, sağı = A (siyah: bugünkü fiyat)")
kaydet(g, "7_3_bootstrap_dagilim.png", h = 7)

# DERS DIŞI (D8) - 22 Kasım kararıyla rapordan çıkarıldı; sadece arşiv için duruyor
yaz("7.8 Duyarlılık: değişen varyans - 2026 oynaklığıyla P(B)")
s26 <- sd(lr[format(tarih[-1], "%Y") == "2026"]) * sqrt(h)
cat(sprintf("2026 sd ile 43 gün sd = %.4f (tüm dönem %.4f)\n", s26, sh_naive))
cat(sprintf("Naive P(B) = %.1f%% | Drift (tüm geçmiş eğim) P(B) = %.1f%%\n",
            100 * olas(merkez_naive, s26), 100 * olas(merkez_drift, s26)))

# =====================================================================
# ---- Adım 8: sonuç tablosu (Bölüm 1.2) - yeni model yok, önceki adımların özeti
# =====================================================================
yaz("8.1 Sonuç tablosu")
fc_d250 <- rwf(subset(y, start = n - 249), h = h, lambda = 0, drift = TRUE, level = c(80, 95))
son <- list(Naive = fcN$Naive, "Drift (tüm geçmiş)" = fcN$Drift, "Drift (son 250 gün)" = fc_d250)
pB_tablo <- c(pB["Naive"], pB["Drift"], pB["Drift (son 250 gün)"])
# Beklenen fiyat = R'ın biasadj = TRUE ortalaması (Bölüm 3.2)
ort_tl <- c(naive(y, h = h, lambda = 0, biasadj = TRUE)$mean[h],
            rwf(y, h = h, lambda = 0, drift = TRUE, biasadj = TRUE)$mean[h],
            rwf(subset(y, start = n - 249), h = h, lambda = 0, drift = TRUE, biasadj = TRUE)$mean[h])
cv_all <- sapply(E[c("Naive", "Drift", "Drift (son 250 gün)")], function(e) sqrt(mean(e[ortak, h]^2)))
cv_26  <- sapply(E[c("Naive", "Drift", "Drift (son 250 gün)")], function(e) sqrt(mean(e[s2026, h]^2)))
sonuc <- data.frame(
  yontem   = names(son),
  nokta    = round(sapply(son, function(f) f$mean[h]), 2),
  pi80     = sapply(son, function(f) sprintf("%.0f-%.0f", f$lower[h, 1], f$upper[h, 1])),
  pi95     = sapply(son, function(f) sprintf("%.0f-%.0f", f$lower[h, 2], f$upper[h, 2])),
  P_B      = round(100 * pB_tablo, 1),
  rmse_cv  = round(cv_all, 1),
  rmse_26  = round(cv_26, 1),
  bekl_fark_5g = round(5 * (ort_tl - esik), 0))
print(sonuc, row.names = FALSE)
cat("bekl_fark_5g = 5 x (beklenen fiyat - eşik): A'nın B'ye göre beklenen TL farkı (pozitifse A lehine)\n")
