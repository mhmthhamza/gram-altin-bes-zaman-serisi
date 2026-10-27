# Adım 2: Veriyi okuma, takvim düzenlemesi ve ts nesnesi (PLAN.md, Adım 2)
# Çalıştırma: çalışma dizini zaman_serisi_R olmalı  ->  Rscript 01_veri.R
# Çıktılar : data/gram_altin_temiz.csv, data/proje.rds (02 ve 03 bunu okur)

library(fpp2)

# ---- Proje parametreleri --------------------------------------------------
# 23 Kasım güncellemesi (proje sahibinin kararı): başlangıç 22 Kasım, karar günü 22 Aralık
# (önceki sürüm: VERI_BITIS = 22 Ekim; yedek: zaman_serisi_R_proje_22Ekim.zip)
VERI_BITIS  <- as.Date("2026-11-22")   # 22 Kasım Pazar -> son işlem günü 20 Kasım Cuma
HEDEF_TARIH <- as.Date("2026-12-22")   # karar günü
GRAM        <- 5                       # karşılaştırılan altın miktarı (gram)
# BES kazancı (proje sahibinin senaryosu, 23 Kasım): BES'teki 33.443 TL'nin %30'unun %15'i 22 Aralık'ta kazanılıyor
BES_BAKIYE  <- 33443                   # TL
BES_FARK    <- BES_BAKIYE * 0.30 * 0.15   # = 1.504,935 TL (BES'in 22 Aralık'taki kazancı)

# ---- Okuma ----------------------------------------------------------------
# Dosya adında Türkçe karakter olduğu için adıyla değil kalıpla bulunur; birden fazlaysa en yenisi
dosyalar <- list.files("data", pattern = "^GAU_TRY.*\\.csv$", full.names = TRUE)
dosya    <- dosyalar[which.max(file.mtime(dosyalar))]
ham      <- read.csv(dosya, fileEncoding = "UTF-8", check.names = FALSE)

sayi <- function(x) as.numeric(gsub(",", ".", gsub(".", "", x, fixed = TRUE)))  # "6.426,707" -> 6426.707
veri <- data.frame(tarih   = as.Date(ham$Tarih, format = "%d.%m.%Y"),
                   kapanis = sayi(ham[["Şimdi"]]))
veri <- veri[order(veri$tarih), ]
stopifnot(!anyNA(veri$kapanis), !anyDuplicated(veri$tarih))
cat("Ham veri:", nrow(veri), "satır,", format(min(veri$tarih)), "-", format(max(veri$tarih)), "\n")

# ---- Takvim düzenlemesi (Bölüm 3.2) ----------------------------------------
# 1) Hafta sonu satırları çıkarılır (veride Cumartesi yok, Pazar satırları yıldan yıla tutarsız).
#    Cuma'dan sonra Pazartesi gelir; aradaki günler piyasanın kapalı olduğu, fiyatın değişmediği günler sayılır.
gun  <- as.integer(format(veri$tarih, "%u"))   # 1 = Pazartesi ... 7 = Pazar
cat("Çıkarılan hafta sonu satırı:", sum(gun >= 6), "\n")
veri <- veri[gun <= 5, ]

# 2) İndirme günündeki yarım satır ve VERI_BITIS sonrası çıkarılır
cat("VERI_BITIS sonrası çıkarılan satır:", sum(veri$tarih > VERI_BITIS), "\n")
veri <- veri[veri$tarih <= VERI_BITIS, ]

# 3) Hafta içi olup veride olmayan tatil günleri bir önceki kapanışla doldurulur
#    ("piyasa kapalı, fiyat değişmedi"). Böylece her hafta tam 5 gözlem olur ve frequency = 5 kayma yapmaz.
tum_gunler <- seq(min(veri$tarih), VERI_BITIS, by = "day")
tum_gunler <- tum_gunler[as.integer(format(tum_gunler, "%u")) <= 5]
eksik      <- tum_gunler[!tum_gunler %in% veri$tarih]
cat("Doldurulan tatil günü:", length(eksik), if (length(eksik)) paste0("(", paste(eksik, collapse = ", "), ")"), "\n")
veri <- merge(data.frame(tarih = tum_gunler), veri, all.x = TRUE)
for (i in which(is.na(veri$kapanis))) veri$kapanis[i] <- veri$kapanis[i - 1]
veri$doldurulan <- veri$tarih %in% eksik

# ---- ts nesnesi (Bölüm 2.1) ------------------------------------------------
# frequency = 5: bir "mevsim" = bir hafta (Pzt..Cum). İlk gözlemin haftadaki sırası start'a yazılır.
ilk_gun <- as.integer(format(veri$tarih[1], "%u"))
y <- ts(veri$kapanis, start = c(1, ilk_gun), frequency = 5)

# ---- Karar büyüklükleri (Bölüm 1) ------------------------------------------
P0   <- tail(veri$kapanis, 1)
esik <- P0 + BES_FARK / GRAM
ufuk <- seq(VERI_BITIS + 1, HEDEF_TARIH, by = "day")
h    <- sum(as.integer(format(ufuk, "%u")) <= 5)   # hafta içi gün sayısı

cat("\nTemiz seri:", length(y), "gözlem,", format(veri$tarih[1]), "-", format(max(veri$tarih)), "(son işlem günü)\n")
cat(sprintf("P0 = %.3f TL | eşik = %.3f TL (%%%.2f yukarıda) | h = %d iş günü (%s -> %s)\n",
            P0, esik, 100 * (esik / P0 - 1), h, VERI_BITIS, HEDEF_TARIH))

write.csv(veri, "data/gram_altin_temiz.csv", row.names = FALSE, fileEncoding = "UTF-8")
saveRDS(list(y = y, veri = veri, P0 = P0, esik = esik, h = h,
             VERI_BITIS = VERI_BITIS, HEDEF_TARIH = HEDEF_TARIH),
        "data/proje.rds")
cat("Yazıldı: data/gram_altin_temiz.csv, data/proje.rds\n")
