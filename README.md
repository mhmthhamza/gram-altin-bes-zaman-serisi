# Gram Altın ile BES Kararı: Zaman Serisi Projesi

İstatistik dersi (zaman serisi, fpp2/R — Hyndman & Athanasopoulos, Bölüm 1–3) kapsamında yapılan bir karar analizi projesi.

## Soru

BES'teki birikimin bir kısmı 22 Aralık 2026'da **1.504,94 TL** kazanç getiriyor. 5 gram gram altının aynı tarihe kadar değer artışı bu kazancı geçer mi?

- Geçerse: **A (altın)** daha kârlı.
- Geçmezse: **B (BES)** daha kârlı.

Soru, gram altının 22 Aralık kapanışının bir **eşik fiyatın** üstünde mi altında mı kalacağına indirgeniyor; tahmin ufku 22 iş günü.

## Sonuç (özet)

- **Veri:** Investing.com GAU/TRY günlük kapanışları, 1 Ocak 2021 – 20 Kasım 2026 (1.536 gözlem).
- **Yöntemler:** Ortalama, naive, mevsimsel naive, drift (Bölüm 3.1), eğitim/test ve zaman serisi çapraz doğrulama (tsCV, Bölüm 3.4) ile kıyaslandı.
- **Seçilen yöntem:** Drift (tüm geçmiş) — tsCV'de en küçük hatayı verdiği için.
- **Tahmin:** 22 Aralık kapanışı için nokta tahmini 5.960,67 TL (eşiğin 88 TL altı).
- **Karar olasılığı:** P(B) ≈ %58, P(A) ≈ %42 — B'ye hafif eğilim var, ama karar belirsiz (tahmin aralığı eşiği kapsıyor).

Tüm hesaplar, grafikler ve yorum için: **[BULGULAR.md](BULGULAR.md)**.

## Klasör yapısı

| Dosya / klasör | İçerik |
|---|---|
| `PLAN.md` | Proje planı ve karar kaydı (her adımda alınan kararlar, tarih sırasıyla) |
| `BULGULAR.md` | Asıl rapor: tüm adımların tabloları, grafikleri, yorumları |
| `takip_kodu.R` | Ders notları tarzında, satır satır takip edilebilen özet kod |
| `01_veri.R` | Veri okuma ve takvim düzenlemesi (Pazar/tatil günleri, `ts` nesnesi) |
| `01b_pazar_tatil_karsilastirma.R` | Veri temizliği kararlarının betimsel karşılaştırması |
| `02_kesif.R` | Keşifsel analiz grafikleri (zaman, mevsimsel, gecikme, ACF) |
| `03_donusum.R` | Box-Cox/log dönüşümü, artık (residual) kontrolü |
| `04_tahmin.R` | Kıyaslama yöntemleri, tsCV, tahmin aralıkları, karar olasılığı |
| `data/` | Ham veri (Investing.com CSV, değiştirilmedi) ve temizlenmiş veri |
| `ciktilar/` | Üretilen grafikler (PNG) |

## Çalıştırma

```r
setwd("zaman_serisi_R")  # bu klasörün yolu
source("01_veri.R")      # veri temizliği (önce bu çalıştırılmalı)
source("02_kesif.R")
source("03_donusum.R")
source("04_tahmin.R")
```

Gereken paket: [`fpp2`](https://cran.r-project.org/package=fpp2).

`takip_kodu.R`, aynı analizi R 4.4.1 ile doğrulanmış, sade ve yorumlu tek bir dosyada; ders notlarını takip eder tarzda satır satır çalıştırmak için kullanılabilir.

## Not

Bu bir ders projesidir, yatırım tavsiyesi değildir. Kullanılan yöntemler (ortalama, naive, mevsimsel naive, drift) giriş seviyesinde zaman serisi tahmin yöntemleridir.
