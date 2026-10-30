# Sıradaki güncelleme (1.2.1) listesi

Yayındaki sürüm: 1.1.0 · İncelemede: 1.2.0 (derleme 136, 29 Ekim 2026'da gönderildi)

Güncelleme hazırlanmadan önce bu liste gözden geçirilir. Açık maddeler `Tools/release_check.py`
çıktısında ve TestFlight yükleme iş akışında hatırlatma olarak görünür. Biten madde `[x]` yapılır.

## Yapılacaklar

- [ ] **Geçiş reklamlarını kapat.** Bölümler arasında çıkan tam ekran reklamlar kaldırılacak
  (`AdCoordinator.continueAfterPuzzle`, `AdPolicy`). İsteğe bağlı ödüllü reklamlar ("izle, can kazan")
  kalır. Geçiş reklamından sonra çıkan Premium tanıtımı başka bir tetikleyiciye bağlanmalı ya da
  kaldırılmalı. Mağaza açıklamasındaki ve inceleme notlarındaki reklam cümleleri buna göre
  güncellenir. Ara çözüm: geçiş reklamı AdMob'dan kapatıldı (29-30 Ekim 2026).

## İsteğe bağlı

- [ ] Koyu modda kedi gölgesi.
