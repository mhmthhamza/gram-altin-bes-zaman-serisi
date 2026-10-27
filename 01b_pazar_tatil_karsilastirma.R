# Adım 2 ek: Pazar satırları ve tatil günleri için seçeneklerin karşılaştırılması
# 22 Kasım (D1): Pazar karşılaştırması (bölüm 1-4) ders dışı olduğu için RAPORDAN ÇIKARILDI, sadece arşiv.
#                Bölüm 5 (tatil günleri) hâlâ BULGULAR.md 2.3 tablosunun kaynağı.
# Dayanak: Bölüm 3.2 "takvim düzenlemeleri" ilkesi. Karşılaştırmanın kendisi ders dışı, düz betimsel bir kontroldür
# (gün içi aralık, gün bazında ortalama/std notlarda yok). Model yok.
# İki seçenek: "Pazarsız seri" (Pazarlar çıkarılır, seçilen) ve "Pazarlı seri" (var olan Pazarlar tutulur).
# Çalıştırma: çalışma dizini zaman_serisi_R  ->  Rscript 01b_pazar_tatil_karsilastirma.R

VERI_BITIS <- as.Date("2026-10-22")

dosyalar <- list.files("data", pattern = "^GAU_TRY.*\\.csv$", full.names = TRUE)
ham <- read.csv(dosyalar[which.max(file.mtime(dosyalar))], fileEncoding = "UTF-8", check.names = FALSE)
sayi <- function(x) as.numeric(gsub(",", ".", gsub(".", "", x, fixed = TRUE)))
v <- data.frame(tarih   = as.Date(ham$Tarih, format = "%d.%m.%Y"),
                kapanis = sayi(ham[["Şimdi"]]),
                yuksek  = sayi(ham[["Yüksek"]]),
                dusuk   = sayi(ham[["Düşük"]]))
v <- v[order(v$tarih), ]
v <- v[v$tarih <= VERI_BITIS, ]
v$gun   <- as.integer(format(v$tarih, "%u"))
v$aralik <- 100 * (v$yuksek - v$dusuk) / v$kapanis       # gün içi aralık, fiyatın %'si

gun_ad <- c("Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz")
yaz <- function(baslik) cat("\n==== ", baslik, " ====\n", sep = "")

# ---------------------------------------------------------------------------
yaz("1. Pazar satırları: yıllara göre haftalık gözlem sayısı (Pazarlı seri)")
v$hafta <- format(v$tarih - (v$gun %% 7), "%Y-%m-%d")   # haftayı Pazar'dan başlat (Pazar + izleyen Pzt-Cum)
gozlem  <- tapply(v$tarih, v$hafta, length)
yil     <- substr(names(gozlem), 1, 4)
print(table(Yil = yil, Haftadaki_gozlem = gozlem))

# ---------------------------------------------------------------------------
yaz("2. Gün içi aralık (Yüksek-Düşük, fiyatın %'si): Pazar gerçek bir işlem günü mü?")
print(round(tapply(v$aralik, factor(gun_ad[v$gun], levels = gun_ad[c(1:5, 7)]), median), 2))

# ---------------------------------------------------------------------------
pazarsiz <- v[v$gun <= 5, ]   # seçilen hâl
pazarli  <- v
pazarsiz$r <- c(NA, diff(log(pazarsiz$kapanis)))
pazarli$r  <- c(NA, diff(log(pazarli$kapanis)))

yaz("3. Toplam değişim: Pazarları çıkarmak bilgi kaybettiriyor mu?")
cat(sprintf("Pazarsız seri : gözlem = %d, toplam log değişim = %.6f\n", nrow(pazarsiz), sum(pazarsiz$r, na.rm = TRUE)))
cat(sprintf("Pazarlı seri  : gözlem = %d, toplam log değişim = %.6f\n", nrow(pazarli),  sum(pazarli$r,  na.rm = TRUE)))

ornek <- pazarli[pazarli$tarih >= as.Date("2026-10-09") & pazarli$tarih <= as.Date("2026-10-13"), c("tarih", "kapanis", "r")]
ornek$gun <- gun_ad[as.integer(format(ornek$tarih, "%u"))]
cat("\nÖrnek hafta sonu (Pazarlı serideki satırlar):\n"); print(ornek, row.names = FALSE)
cuma <- pazarli$kapanis[pazarli$tarih == as.Date("2026-10-09")]; pzt <- pazarli$kapanis[pazarli$tarih == as.Date("2026-10-12")]
cat(sprintf("Pazarsız seride Pazartesi değişimi = log(Pzt/Cum) = %.6f  (Pazarlı serideki Pazar + Pazartesi toplamı ile aynı)\n",
            log(pzt / cuma)))

yaz("4. Günlük log değişimin haftanın gününe göre dağılımı")
ozet <- function(d, ad) {
  g <- factor(gun_ad[d$gun], levels = gun_ad[c(1:5, 7)])
  out <- data.frame(seri = ad, gun = levels(g),
                    n    = as.vector(tapply(d$r, g, function(x) sum(!is.na(x)))),
                    ort  = round(as.vector(tapply(d$r, g, mean, na.rm = TRUE)), 5),
                    std  = round(as.vector(tapply(d$r, g, sd,   na.rm = TRUE)), 5))
  out[!is.na(out$n) & out$n > 0, ]
}
print(rbind(ozet(pazarsiz, "Pazarsız"), ozet(pazarli, "Pazarlı")), row.names = FALSE)

# ---------------------------------------------------------------------------
yaz("5. Eksik hafta içi günler (tatiller) ve çevresindeki kapanışlar")
tum <- seq(min(pazarsiz$tarih), VERI_BITIS, by = "day"); tum <- tum[as.integer(format(tum, "%u")) <= 5]
eksik <- tum[!tum %in% pazarsiz$tarih]
for (e in as.list(eksik)) {
  once  <- tail(pazarsiz[pazarsiz$tarih < e, c("tarih", "kapanis")], 1)
  sonra <- head(pazarsiz[pazarsiz$tarih > e, c("tarih", "kapanis")], 1)
  cat(sprintf("\nEksik gün: %s (%s)\n", e, gun_ad[as.integer(format(e, "%u"))]))
  cat(sprintf("  önceki kapanış %s : %.3f\n  sonraki kapanış %s: %.3f  (iki kapanış arası log değişim %.5f)\n",
              once$tarih, once$kapanis, sonra$tarih, sonra$kapanis, log(sonra$kapanis / once$kapanis)))
  cat(sprintf("  (a) önceki kapanışla doldurma : %.3f  -> Cuma değişimi 0, Pazartesi değişimi %.5f\n",
              once$kapanis, log(sonra$kapanis / once$kapanis)))
  ara <- exp((log(once$kapanis) + log(sonra$kapanis)) / 2)
  cat(sprintf("  (b) ara değer (interpolasyon) : %.3f  -> değişim iki güne bölünür: %.5f + %.5f\n",
              ara, log(ara / once$kapanis), log(sonra$kapanis / ara)))
  cat("  (c) boş bırakma               : o hafta 4 gözlem olur\n")
}
sonra_kayan <- sum(pazarsiz$tarih > eksik[1])
cat(sprintf("\n(c) seçilirse frequency = 5 serisinde %s sonrasındaki %d gözlemin 'haftanın günü' konumu kayar\n",
            eksik[1], sonra_kayan))
