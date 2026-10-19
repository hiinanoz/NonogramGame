# Miyav Crush (Meow Crush): yol haritası ve mimari

Candy Crush tarzı 3'lü eşleştirme modu, "Kedi Dünyası" temasıyla. Ana sayfada Günlük Bulmaca ve
Kart Koleksiyonu kartlarının altına eklenecek. Mevcut modlara dokunmadan, ayrı klasörlerde.

## Yol haritası

| Aşama | İçerik | Durum |
|---|---|---|
| 1. Motor | Veri modelleri, eşleşme bulma, özel eşyalar ve birleşimler, yerçekimi/dolum, zincirleme, olası hamle, karıştırma, testler | **Bitti** (`NonogramKit/Crush`) |
| 2. Bölümler ve hedefler | Bölüm dosyası (şekilli tahtalar, hamle sayısı, hedefler, yıldız eşikleri), ilerleme kaydı, 1-3 yıldız, ilk 60 bölüm | **Bitti** (`CrushSession`, `CrushCatalog`, `CrushLevels`) |
| 3. Oyun ekranı (temel) | Tahta çizimi, kaydırarak takas, geçersiz takasın geri dönmesi, adımların sırayla oynatılması (patla → düş → dol), hamle/puan/hedef çubuğu | **Bitti** (`Catgrid/Features/Crush`) |
| 4. His ve efektler | Pofuduk tüy/pati parçacıkları, sekmeli düşüş, iplik/patlama/lazer efektleri, "Miyav!", "Harika!", "Pati Gücü!" yazıları, sesler ve titreşim | **Bitti** (mevcut seslerle) |
| 5. Ödül sistemi | Bölüm sonu yıldız ve puan, kalan hamlelerin özel eşyaya dönüşmesi ("Kedi Çılgınlığı", Candy Crush'taki "Sugar Crush"), rozetler, Game Center sıralaması | **Bitti** (Game Center sıralaması onay bekliyor) |
| 6. Güçlendiriciler ve can | Çekiç, karıştır, +5 hamle (ödüllü reklam / Premium); can sistemi (5 can, zamanla dolar) | **Güçlendiriciler bitti**; can sistemi onay bekliyor |
| 7. Harita ve entegrasyon | Ana sayfa kartı (hareketli kedi), bölüm haritası, istatistikler, 8 dil, App Store metinleri | **Bitti** (App Store metinleri yayından önce) |
| 8. Görseller | 6 eşya × (normal, çizgili, kutu) + altın kedi gözü; arka planlar; kart görseli | Liste aşağıda; şimdilik kodla çizilenler kullanılıyor |

## Mimari (katmanlar)

```
NonogramKit/Crush            ← saf motor (Foundation dışında bağımlılık yok, swift test ile test edilir)
  CrushModels.swift          renkler, özel eşyalar, tahta, takas, adım/sonuç, bölüm, hedef, tohumlu rastgele
  CrushEngine.swift          kurallar ve algoritmalar
  CrushSession.swift         hamle sayısı, hedef sayaçları, yıldızlar, bölüm sonu, Kedi Çılgınlığı
  CrushCatalog.swift         maceralar (15'er bölüm), tahta şekilleri
  CrushLevels.swift          60 bölüm (simülasyonla ayarlandı)
  CrushRewards.swift         ilerleme kaydı, kilitler, yıldız sandıkları, macera ödülleri, rozetler, güçlendiriciler
Catgrid/Features/Crush       ← arayüz (SwiftUI)
  CrushViewModel             motoru sürer; adımları zaman çizelgesine çevirir (animasyon durumları)
  CrushBoardView             tahta + eşyalar (Canvas/TimelineView, 60 FPS)
  CrushEffects               parçacıklar, iplik, patlama, lazer, kombo yazıları
  CrushHubView / LevelsView  harita, bölümler
```

- **Motor ile arayüz ayrı:** Motor zamanı ve animasyonu bilmez. Her hamle, sırayla oynatılacak
  `CrushStep` listesi döndürür. Arayüz bu listeyi efektlere çevirir; oyun mantığı arayüzde değildir.
- **Tekrarlanabilirlik:** `CrushRandom` (SplitMix64) tohumlu: aynı tohum aynı tahtayı verir.
  Bu sayede testler kararlı, bölüm başlangıçları sabit ve kayıt/geri yükleme kolay.
- **Kimlikler:** Her eşyanın kalıcı `id`'si var; arayüz aynı eşyayı düşerken, kayarken takip eder.

## Oyun döngüsü (bir hamle)

```
apply(swap)
 ├─ komşu ve dolu mu? değilse → hata (UI geri kaydırır)
 ├─ özel + özel (ya da altın göz) → birleşim: temizlenecek hücreler hesaplanır
 ├─ değilse eşleşme bul → yoksa takas geri alınır, hata
 └─ zincir döngüsü (adım = 1, 2, 3 …):
      1. eşleşen hücreler + (varsa) ikinci patlamasını yapacak çıngırak kutuları
      2. temizleme kuyruğu: temizlenen özel eşya kendi efektini tetikler
         (yumak → satır/sütun, kutu → 3x3 ve "hazır" kalır, altın göz → en çok bulunan renk)
      3. eşleşmeden doğan özel eşyalar yerleşir
      4. yerçekimi: her sütunda eşyalar aşağı kayar (deliklerin üstünden geçer)
      5. dolum: boşluklar yukarıdan yeni rastgele eşyalarla dolar
      6. yeni eşleşme ya da hazır kutu yoksa döngü biter
 └─ geçerli hamle kalmadıysa → karıştır (özel eşyalar korunur)
```

## Eşleşme algoritması

1. Her satır ve sütunda aynı renkteki ardışık eşyalar taranır; uzunluğu 3+ olan **diziler** bulunur.
2. Ortak hücresi olan diziler birleşim-bul (union-find) ile tek **grup** olur (T ve L şekilleri).
3. Grubun ürettiği özel eşya:
   - içinde 5+ düz dizi → **Altın Kedi Gözü** (renk bombası)
   - yatay ve dikey dizi kesişiyor → **Çıngırak Kutusu** (paketli şeker)
   - en uzun dizi 4 → **Çizgili Işıltılı Yumak**; oyuncunun takasıyla oluştuysa yönü takas yönünü izler
   - aksi hâlde düz 3'lü
4. Özel eşya, oyuncunun taşıdığı eşyanın hücresinde doğar; zincirde ise grubun merkezinde/kesişiminde.

Olası hamle kontrolü bütün tahtayı değil, takas edilen iki hücrenin çevresini tarar (yaklaşık 20 kat
hızlı); testte tam taramayla birebir aynı sonucu verdiği doğrulanır.

## Özel eşyalar ve birleşimler

| Eşya | Nasıl oluşur | Etkisi |
|---|---|---|
| Çizgili Işıltılı Yumak | 4'lü düz | Bütün satırı ya da sütunu iplikle temizler |
| Çıngırak Kutusu | T/L 5'li | 3x3 patlar, düştükten sonra bir kez daha patlar |
| Altın Kedi Gözü | 5'li düz | Takas edildiği renkteki her eşyayı temizler |
| Yumak + Yumak | takas | Satır ve sütun birlikte |
| Yumak + Kutu | takas | 3 satır + 3 sütun |
| Kutu + Kutu | takas | 5x5 patlama |
| Göz + Yumak | takas | O renkteki her eşya yumağa dönüşüp patlar |
| Göz + Kutu | takas | O renkteki her eşya kutuya dönüşüp patlar |
| Göz + Göz | takas | Bütün tahta temizlenir |

## Puanlama (ilk sürüm)

- Temizlenen her eşya: 20 × zincir adımı (2. adımda 40, 3. adımda 60 …)
- Özel eşya doğunca: yumak 60, kutu 100, altın göz 200
- Kombo yazıları adım sayısına göre: 2 → "Miyav!", 3 → "Harika!", 4+ → "Pati Gücü!"

## Bölümler, hedefler ve yıldızlar

- **4 macera × 75 bölüm (300 bölüm):** Yumak Apartmanı, Ay Işığı Konağı, Deniz Tatili Rezidansı, Karlı Pati Kuleleri. Bölümler sırayla açılır.
- **Tahta şekilleri:** 8x8, 9x9, kedi başı, elmas, kalp, halka (ortası delik), artı, kum saati, pati.
- **Renk sayısı:** 1-30. bölüm 5 renk, 31-60. bölüm 6 renk (renk arttıkça eşleşme zorlaşır).
- **Hedef türleri:** puan, belirli eşyadan şu kadar topla (ör. 25 yumak), şu kadar özel eşya patlat;
  bir bölümde birden çok hedef olabilir.
- **Bitiş:** Toplama/özel eşya hedefli bölüm hedefler tamamlanınca hemen kazanılır. Yalnızca puan
  hedefli bölüm bütün hamleler oynanınca biter. Hamle biter, hedef tamamlanmazsa kaybedilir
  (+5 hamle güçlendiricisiyle devam).
- **Kedi Çılgınlığı:** Kazanınca kalan her hamle rastgele bir eşyayı çizgili yumağa çevirir
  (+300 puan/hamle), sonra tahtadaki bütün özel eşyalar patlar.
- **Yıldız:** Kazanılan bölüm en az 1 yıldız; 2. ve 3. yıldız puan eşiklerinden.
- **Ayar (simülasyon):** Bir bot (çoğunlukla en iyi hamle, bazen rastgele) her bölümü 150 kez oynar.
  Hedef sayıları, botun kazanma oranı 1. bölümde ~%99, 60. bölümde ~%65 olacak şekilde seçilir
  (macera sonları biraz daha zor). 2. yıldız botun ortalama puanı, 3. yıldız en iyi %12'si.
  Gerçek oyuncu bottan iyi oynar. Yeniden üretmek: `CRUSH_BALANCE=1 swift test -c release
  -Xswiftc -enable-testing --filter CrushBalanceTests`.

## Ödüller

| Ödül | Ne zaman | İçerik |
|---|---|---|
| Başlangıç hediyesi | İlk açılış | Kedi Patisi, Karıştır, +5 Hamle (birer) |
| Yıldız sandığı | Her 15 yıldızda | Sırayla değişen 2-4 güçlendirici |
| Macera ödülü | Bir macerada 75 bölümün hepsi kazanılınca (bir kez) | Her güçlendiriciden 2-3 |
| Rozetler | İlk zafer, macera bitirme, maceranın hepsi 3 yıldız, 50/150/300/600/900 yıldız, bir hamlede 5+ zincir, Kedi Çılgınlığı'nda 10+ hamle | — |
| Game Center | Toplam yıldız sıralaması (Aşama 7) | — |

Güçlendiriciler: **Kedi Patisi** (tek eşyayı patlatır), **Karıştır**, **+5 Hamle**. Ödüllü reklam ve
Premium ile de kazanılacak (Aşama 6).

## Dikkat

- **İsim ve görseller:** "Candy Crush" King'in tescilli markası. Mağaza metinlerinde ve uygulamada bu adı
  kullanmayacağız; mekanik benzer olabilir ama görseller, isimler ve sesler özgün olmalı.
  "Meow Crush / Miyav Crush" adı sorun değil, açıklamada "Candy Crush gibi" ifadesi kullanılmamalı.

## Görsel listesi (Aşama 8, isteğe bağlı)

Oyun şu an görselsiz de tam çalışır: eşyalar, zemin ve ana sayfa kartı kodla çiziliyor. Aşağıdaki
dosyalar Assets'e bu adlarla eklenirse kendiliğinden kullanılır (eklenmeyenler çizimle kalır).

| Dosya adı | Ne | Boyut |
|---|---|---|
| `crush-yarn` | Mavi yün yumağı | 256×256, saydam PNG |
| `crush-wand` | Kırmızı tüylü kedi oltası | 256×256, saydam PNG |
| `crush-treat` | Sarı balık ödül maması | 256×256, saydam PNG |
| `crush-bowl` | Yeşil mama kabı | 256×256, saydam PNG |
| `crush-mouse` | Mor peluş fare | 256×256, saydam PNG |
| `crush-paw` | Turuncu pati tırmalağı | 256×256, saydam PNG |
| `crush-background` | Oyun ekranının zemini (dikey) | 1290×2796 |
| `crush-map-1` … `crush-map-4` | Macera haritası zeminleri (Yumak Apartmanı, Ay Işığı Konağı, Deniz Tatili Rezidansı, Karlı Pati Kuleleri) | 1290×2796 |
| `mode-crush` | Ana sayfa kartının sağındaki küçük çizim | 360×120, saydam PNG |
| `crush-cat-loop.webp` | (İsteğe bağlı) ana sayfa kartı için hareketli kedi | diğer animasyonlar gibi |

Çizgili yumak, çıngırak kutusu ve altın kedi gözü süslemeleri eşyanın üstüne kodla eklenir; ayrı
görsel gerekmez. Eşyaların her biri tahtada farklı bir zemin şekliyle ayırt edilir (renk körlüğü).

## Kedi Kulesi (bölüm seçme ekranı)

Her bölüm kulenin bir katı; katlar alttan üste artan numarayla dizilir, ekranda ~4,5 kat görünür
(kat yüksekliği ekrana göre 112–176 pt). Kod: `Catgrid/Features/Crush/CatTowerLevelMap.swift`.

- **Durumlar** (`CrushModel.towerFloors`): tamamlanan (1–3 yıldız), sıradaki (pembe çerçeve, nefes
  alan rozet, hareketli kedi), kilitli (gri, perdeli oda, kilit; dokununca "önce N. bölümü geç").
- **Seçim:** kata dokununca seçilir ve alt panel o bölümü gösterir; seçili kata tekrar dokunmak oyunu açar.
- **Çizim:** odalar, süsler (kitaplık, yumak, yastık, bitki, oyuncak; bölüm numarasından sırayla),
  balkon sarmaşıkları, merdiven, fenerler, çatı, zemin ve gökyüzü kodla çizilir. Kat kedileri kendi
  animasyonlarımızın karelerinden (`crush-tower-cat-1…5`). Numara, yıldız ve kilit görsele işlenmez.
- **Gündüz/gece:** açık temada gündüz gökyüzü ve pastel şehir; koyu temada gece, ay, yıldızlar,
  yanan fenerler ve ışıklı pencereler.
- **Eski harita:** `crush.classicMap` ayarı (UserDefaults) ya da `-crushClassicMap` başlatma argümanı.
- **Binalar:** Yumak Apartmanı (1–75), Ay Işığı Konağı (76–150), Deniz Tatili Rezidansı (151–225),
  Karlı Pati Kuleleri (226–300). Aynı yerleşim motoru; renk, pencere manzarası, mobilya, aksesuar,
  çatı ve gökyüzü binaya göre (`CatTowerTheme`). Yeni bölümler yeni binalarla eklenir.
- **Katmanlı oda** (`CatTowerRoomPlan`, sabit tohum, komşu katlarda tekrar yok): arka duvar → pencere →
  zemin → ana mobilya → 1–3 aksesuar (sol, sağ, duvar rafı yuvaları) → kedi (mobilyanın üstünde).
  Her 5 katta özel oda (bayrak süsü), her 15 katta dönüm noktası (altın çerçeve, altın bayraklar).
- **Görseller** (Assets'e bu adlarla eklenince çizimin yerine geçer; numara/yazı yok). Anahtarlar:
  `yarn`, `moon`, `seaside`, `snow`.

| Dosya adı | Ne | Önerilen adet | Boyut |
|---|---|---|---|
| `tower-<anahtar>-wall-1…` | Oda arka duvarı (pencere dahil, mobilyasız) | 3+ | 1200×700 |
| `tower-<anahtar>-furniture-1…` | Ana mobilya (koltuk, yatak, minder, kedi yatağı), saydam | 3+ | ~600×400 |
| `tower-<anahtar>-accessory-1…` | Aksesuar (lamba, bitki, kitaplık…), saydam | 5+ | ~300×300 |
| `tower-<anahtar>-special` | Dönüm noktası odası (her 15 kat) | 1 | 1200×700 |
| `tower-<anahtar>-roof` / `-base` | Çatı / kule dibi | 1+1 | ~1200×800 |
| `tower-<anahtar>-sky` / `-sky-night` | Gökyüzü (dikey, ortası boş) | 1+1 | 1290×2796 |
| `crush-tower-cat-<n>-blink-1…` | (İsteğe bağlı) kedinin göz kırpma kareleri | 3–4 | kediyle aynı |
