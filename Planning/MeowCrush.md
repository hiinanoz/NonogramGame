# Miyav Crush (Meow Crush): yol haritası ve mimari

Candy Crush tarzı 3'lü eşleştirme modu, "Kedi Dünyası" temasıyla. Ana sayfada Günlük Bulmaca ve
Kart Koleksiyonu kartlarının altına eklenecek. Mevcut modlara dokunmadan, ayrı klasörlerde.

## Yol haritası

| Aşama | İçerik | Durum |
|---|---|---|
| 1. Motor | Veri modelleri, eşleşme bulma, özel eşyalar ve birleşimler, yerçekimi/dolum, zincirleme, olası hamle, karıştırma, testler | **Bitti** (`NonogramKit/Crush`) |
| 2. Bölümler ve hedefler | Bölüm dosyası (şekilli tahtalar, hamle sayısı, hedefler, yıldız eşikleri), ilerleme kaydı, 1-3 yıldız, ilk 60 bölüm | Sırada |
| 3. Oyun ekranı (temel) | Tahta çizimi, kaydırarak takas, geçersiz takasın geri dönmesi, adımların sırayla oynatılması (patla → düş → dol), hamle/puan/hedef çubuğu | |
| 4. His ve efektler | Pofuduk tüy/pati parçacıkları, sekmeli düşüş, iplik/patlama/lazer efektleri, "Miyav!", "Harika!", "Pati Gücü!" yazıları, sesler ve titreşim | |
| 5. Ödül sistemi | Bölüm sonu yıldız ve puan, kalan hamlelerin özel eşyaya dönüşmesi ("Kedi Çılgınlığı", Candy Crush'taki "Sugar Crush"), rozetler, Game Center sıralaması | |
| 6. Güçlendiriciler ve can | Çekiç, karıştır, +5 hamle (ödüllü reklam / Premium); can sistemi (5 can, zamanla dolar) | |
| 7. Harita ve entegrasyon | Ana sayfa kartı (hareketli kedi), bölüm haritası, istatistikler, 8 dil, App Store metinleri | |
| 8. Görseller | 6 eşya × (normal, çizgili, kutu) + altın kedi gözü; arka planlar; kart görseli | Görsel listesi Aşama 3'te |

## Mimari (katmanlar)

```
NonogramKit/Crush            ← saf motor (Foundation dışında bağımlılık yok, swift test ile test edilir)
  CrushModels.swift          renkler, özel eşyalar, tahta, takas, adım/sonuç, bölüm, hedef, tohumlu rastgele
  CrushEngine.swift          kurallar ve algoritmalar
  (Aşama 2) CrushSession     hamle sayısı, hedef sayaçları, yıldızlar, bölüm sonu
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

## Dikkat

- **İsim ve görseller:** "Candy Crush" King'in tescilli markası. Mağaza metinlerinde ve uygulamada bu adı
  kullanmayacağız; mekanik benzer olabilir ama görseller, isimler ve sesler özgün olmalı.
  "Meow Crush / Miyav Crush" adı sorun değil, açıklamada "Candy Crush gibi" ifadesi kullanılmamalı.
