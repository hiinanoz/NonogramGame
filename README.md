# Catgrid Collection: Nonogram

Kedi türlerini topladığın, klasik kurallı iOS Nonogram (Picross) bulmaca oyunu. SwiftUI, iOS 17+, MVVM.
Ana ekranda adı **Catgrid**; App Store adı **Catgrid Collection: Nonogram**.


## Kurulum

**Gereksinimler:** macOS 13 Ventura+, **Xcode 15.2** (Swift 5.9, iOS 17.2 SDK). Testler XCTest kullanır.
Kod Xcode 15.2 ile uyumlu tutulur; her push'ta GitHub Actions aynı sürümle derler ve testleri
iOS 17.2 simülatöründe çalıştırır (`.github/workflows/ci.yml`).

Xcode projesi [XcodeGen](https://github.com/yonaskolb/XcodeGen) ile `project.yml`'den üretilir.

```bash
git clone https://github.com/hiinanoz/NonogramGame
cd NonogramGame
./ProjeyiAc.command
```

Güncellemek için `./Guncelle.command` (Xcode'un kendiliğinden yaptığı değişiklikleri `git stash` ile kenara alır,
yeni sürümü indirir ve projeyi açar).

`ProjeyiAc.command` XcodeGen'i (Homebrew olmadan, Intel/Apple Silicon) `.tools/` içine indirir,
`project.yml`'den Xcode projesini üretir ve açar. Finder'da çift tıklayarak da çalıştırılabilir.

Testler:

```bash
# Oyun motoru (Xcode projesi gerekmez, macOS'ta çalışır)
cd Packages/NonogramKit && swift test

# Uygulama + paketlenmiş içerik doğrulama
xcodebuild test -scheme Catgrid -destination 'platform=iOS Simulator,name=iPhone 15'

# Bulmaca içeriği (yalnızca Python 3)
python3 Tools/validate_puzzles.py
```

## Mimari

İki katman:

- **NonogramKit** (yerel Swift Package): yalnızca Foundation. Bulmaca modeli, ipucu hesabı, çözücü,
  oyun kuralları, katalog yükleme, kilit sistemi. UI'dan bağımsız, saf değer tipleri, tamamen test edilebilir.
- **Uygulama**: SwiftUI View + `@Observable` ViewModel'ler ve servisler (kalıcılık, reklam, tema).

```
NonogramGame/
├── project.yml
├── Packages/NonogramKit/
│   ├── Sources/NonogramKit/
│   │   ├── Model/          Matrix, GridPosition, CellState, Puzzle, GameRules, LocalizedText, RGBColor
│   │   ├── Engine/         LineClue, LineSolver, PuzzleSolver, NonogramGame (+ GameSnapshot)
│   │   ├── Content/        LevelCatalog, Chapter, CatalogLoader (JSON → katalog)
│   │   └── Progression/    Progression (kilit kuralları), PuzzleCompletion
│   └── Tests/NonogramKitTests/
├── Catgrid/
│   ├── App/                CatgridApp, AppModel, Router (rotalar), RootView
│   ├── Core/
│   │   ├── Theme/          ThemePalette (4 palet × açık/koyu), AppTheme tokenları, ThemeManager, modifier'lar
│   │   └── Components/     Buton stilleri, ProgressBar, ArtworkThumbnail
│   ├── Features/
│   │   ├── Home/           Ana ekran: genel ilerleme, "Devam Et" kartı
│   │   ├── Levels/         Tür kartları (ChaptersView), 30 bulmacalık ızgara (ChapterView)
│   │   ├── Game/           GameView, BoardView (Canvas), GameViewModel
│   │   ├── Stats/          İstatistik ekranı
│   │   ├── Tutorial/       LessonBanner + ders metinleri
│   │   └── Settings/       Palet seçici, görünüm, titreşim, dil
│   ├── Services/
│   │   ├── Persistence/    PuzzleRecord (@Model), ProgressStore (SwiftData önbellekli ilerleme)
│   │   ├── Audio/          AudioManager (müzik + efektler, ayarlar)
│   │   └── Ads/            AdPolicy, AdService (Google / test), AdCoordinator
│   └── Resources/
│       ├── Puzzles/        catalog.json + bölüm başına bir JSON
│       ├── Sounds/         müzik (.m4a) ve efektler (.wav)
│       ├── Localizable.xcstrings, InfoPlist.xcstrings   (EN varsayılan, TR)
│       └── Assets.xcassets
├── CatgridTests/  ViewModel testleri + paketlenmiş içerik doğrulama
└── Tools/validate_puzzles.py
```

### Neden bu teknolojiler

| Konu | Seçim | Gerekçe |
|---|---|---|
| Bulmaca içeriği | Paketlenmiş **JSON** (salt okunur) | 460 bulmaca ~150 KB; git'te diff'lenebilir, Xcode'suz doğrulanabilir, uygulama güncellemesiyle değişir |
| İlerleme / yarım oyun | **SwiftData** (Aşama 3) | iOS 17+ ile yerleşik; tamamlanma, en iyi süre, yarım kalan tahta (`GameSnapshot`) |
| Basit ayarlar | `@AppStorage` | Tema paleti, ses, reklam sayacı |
| Yerelleştirme | **String Catalog** (`.xcstrings`) | `Localizable.strings`'in Xcode 15+ halefi; derlemede `.strings`'e dönüşür, eksik çevirileri gösterir. İçerik adları JSON'da `{ "en", "tr" }` |
| Reklam | Google Mobile Ads SDK (SPM) + UMP onayı | Aşama 4 |

## Tema sistemi

View'lar ham renk kullanmaz; `@Environment(\.appTheme)` üzerinden anlamsal tokenları okur
(`background`, `surface`, `accent`, `cellFilled`, `cellCross`, `gridLineMajor`, `highlight`, `mistake`...).
`RootView`, seçili `ThemePalette` ile pencerenin renk şemasından `AppTheme` üretip enjekte eder.
Yeni palet eklemek: `ThemePalette`'e bir case ve iki `ThemeSpec` (açık/koyu) eklemek yeterli.

## Bulmaca veri modeli

**`catalog.json`**: bölüm sırası ve varsayılan kurallar.

```json
{
  "schemaVersion": 1,
  "defaultRules": { "checksMoves": true, "mistakeLimit": 3, "timeLimitSeconds": null, "autoCrossCompletedLines": true },
  "chapters": [
    { "id": "tutorial", "kind": "tutorial", "title": { "en": "Kitten School", "tr": "Yavru Okulu" },
      "accentColor": "#F4A6A0", "file": "tutorial", "expectedPuzzleCount": 10 },
    { "id": "siamese", "kind": "breed", "title": { "en": "Siamese", "tr": "Siyam" },
      "accentColor": "#C9A27E", "file": "chapter_01_siamese", "expectedPuzzleCount": 30 }
  ]
}
```

**Bölüm dosyası** (`chapter_01_siamese.json`): çözüm renkli piksel görsel olarak tutulur.

```json
{
  "schemaVersion": 1,
  "chapterID": "siamese",
  "puzzles": [
    {
      "id": "siamese-001",
      "title": { "en": "Siamese Face", "tr": "Siyam Yüzü" },
      "palette": { "a": "#4A3B35", "b": "#F2E3CF" },
      "pixels": ["a...a", "aaaaa", "b.b.b", "bbbbb", ".bab."],
      "rules": { "mistakeLimit": 3, "timeLimitSeconds": 300 },
      "lesson": null
    }
  ]
}
```

- `.` boş kare; diğer her karakter `palette`teki bir renk ve **dolu** kare.
- İpuçları saklanmaz, yüklemede `pixels`'tan hesaplanır → veri ile ipucu asla çelişmez.
- Çözüm bitince tahta `palette` renkleriyle "kedi resmine" dönüşür.
- `rules` isteğe bağlı: süreli/sınırsız bölümler için katalog varsayılanını ezer.
- `lesson` yalnızca eğitim bölümlerinde: arayüz o dersin anlatımını gösterir.
- Kimlikler (`siamese-001`) kalıcıdır; ilerleme kaydı bunlara bağlanır, sonradan değiştirilmemeli.

**Kalite kuralı:** her bulmaca tahmin yapmadan, yalnızca satır mantığıyla çözülebilmeli
(bu, çözümün benzersiz olduğunu da garanti eder). `Tools/validate_puzzles.py` ve
`ContentValidationTests` bunu her bulmaca için kontrol eder.

## İçerik üretimi

Kedi türü bölümleri `Tools/generate_content.py` ile üretilir (yalnızca Python 3):

```bash
python3 Tools/generate_content.py   # bölüm JSON'larını yeniden yazar
python3 Tools/validate_puzzles.py   # tüm bulmacaları doğrular
```

- Her tür `BREEDS` içinde tanımlıdır: kulak şekli (büyük, katlanmış, püsküllü...), desen
  (uçlar, beyaz eldiven, benek, tekir, Van lekesi), göz rengi (Ankara/Van'da ela-mavi), palet ve
  türe özgü sahneler (Van kedisi gölde yüzer, Norveç orman kedisi çam ağacının yanında...).
- Motifler vektör olarak çizilir, ızgaraya oturtulur ve **yalnızca tahmin gerektirmeden çözülebilen**
  bulmacalar seçilir. Aynı kod her zaman aynı bulmacaları üretir.
- Zorluk tür sırasıyla artar: ilk tür 5x5–8x8, son türler 15x15. Her türde 15 bulmaca; şu an 25 tür.
  En büyük boyut bilerek 15x15: telefonda yakınlaştırma gerektirmeden rahat oynanır (20x20 ve üstünü
  sunan uygulamalar yakınlaştırma ekler; bu, sürükleyerek doldurmayla çakışır).
- Her türün katalogda bir **piksel portresi** (tür listesi ve kart görseli) ve bir **koleksiyon kartı**
  (köken, ömür, tüy, 1-5 karakter puanları, ilginç bilgi, nadirlik) vardır. Kart bilgileri `CARDS` içindedir.
  Assets'e `card-<tür-id>` adlı lisanslı bir fotoğraf eklenirse kartta portre yerine o görünür.
- **Yeni tür eklemek:** `BREEDS`'e bir giriş ekle, scripti çalıştır. Tür sayısı arayüzde sabit değildir;
  ana ekran toplam sayı yerine toplanan koleksiyonu gösterir.
- Elle çizilen küçük bulmacalar `HANDMADE` içinde tutulur.

## Ses

`Tools/generate_audio.py` (numpy + ffmpeg) müziği ve efektleri sentezler; çıktılar `Catgrid/Resources/Sounds/`.
Profesyonel seslerle değiştirmek için aynı dosya adlarını kullanmak yeterli. Ayarlar'da müzik ve efektler
ayrı ayrı açılıp kapatılabilir ve seviyeleri ayarlanabilir. Ses oturumu `.ambient`: sessiz anahtara uyar,
kullanıcının kendi müziğini kesmez.

## Koleksiyon kartları

Bir türün tüm bulmacaları çözülünce o türün kartı kazanılır ("Yeni kart kazandın!" penceresi). Kartlar ana
sayfadaki rafta ve Kart Koleksiyonu ekranında görünür. Toplam tür sayısı bilerek gösterilmez; yeni türler
geldikçe koleksiyon büyür. Nadirlik türün sırasına göre: Yaygın, Nadir, Destansı, Efsanevi.

## Uygulama simgesi

`Tools/generate_icon.py` (Pillow) pastel zemin üzerinde yavru kedi yüzü ve nonogram ızgarası çizer.

## Reklam ve gelir modeli

Uygulama ücretsiz; gelir Google AdMob'dan (SDK 11.5.0: Xcode 15.2 ile çalışan son sürüm; Xcode 15.3+ kullanılırsa yükseltilebilir):

| Reklam | Ne zaman | Kural |
|---|---|---|
| Geçiş (interstitial) | Her 2 çözülen tür bulmacasında bir | Yalnızca sonuç kartından ayrılırken; iki reklam arası en az 90 sn; **eğitimde asla** |
| Ödüllü (rewarded) | Canlar ya da süre bitince, isteğe bağlı | "+1 pati" / "+60 sn", bulmaca başına bir kez |

- Açılışta Google UMP onay formu (AB/İngiltere) ve ardından iOS izleme izni (ATT) istenir.
  AB'de Ayarlar'da "Gizlilik Ayarları" görünür.
- Mantık `AdPolicy`'de (test edilebilir), SDK `GoogleAdService`'te, ekranlar yalnızca `AdCoordinator`'ı kullanır.
- Banner reklam bilerek yok: tahtada yanlış dokunmalara yol açar ve oyunu kalabalıklaştırır.
- **Reklamları Kaldır** (StoreKit 2, tek seferlik, `com.catgridcollection.nonogram.removeads`): geçiş reklamlarını
  kapatır, isteğe bağlı ödüllü reklam kalır. Ayarlar'da satın alma ve "Satın Alımları Geri Yükle".
  Simülatörde `Catgrid/Resources/Catgrid.storekit` ile App Store Connect olmadan denenebilir.
  Yayından önce aynı ürün kimliğiyle App Store Connect'te "Non-Consumable" ürün oluşturulmalı.

**AdMob hesabı onaylanınca:**
1. `project.yml` → `GADApplicationIdentifier` değerini kendi uygulama kimliğinle değiştir.
2. `Catgrid/Services/Ads/AdService.swift` → `AdConfiguration.production` içine reklam birimi kimliklerini yaz.
3. Debug derlemeler her zaman Google'ın test reklamlarını kullanır (kendi reklamına tıklamak hesabı riske atar).

## Yol haritası

- [x] **Aşama 1 — Core Engine ve veri modeli**: NonogramKit, JSON şeması, çözücü/doğrulayıcı,
      kilit sistemi, örnek içerik (10 eğitim + 3 Siyam), prototip oyun ekranı, testler
- [x] **Aşama 2 — UI/UX ve temalar**: 4 palet (Pastel, Gece Mavisi, Kahve Tonları, Matcha) × açık/koyu,
      ana ekran, tür kartları ve bulmaca ızgarası, temalı tahta (satır/sütun vurgusu, hata yanıp sönmesi,
      çözümde kedi resmi animasyonu), eğitim balonları, sonuç kartları, ayarlar, titreşim, EN/TR metinler
- [x] **Aşama 3 — Kalıcılık**: SwiftData (`PuzzleRecord`: ilk çözüm, en iyi süre, en az hata, yarım oyun),
      arka plana geçişte/ekrandan çıkışta otomatik kayıt, kaldığın yerden devam, "Yeni rekor!",
      istatistik ekranı, ilerlemeyi sıfırlama, eski UserDefaults ilerlemesinin taşınması
- [x] **Aşama 4 — Reklam, ses, içerik**: AdMob (test kimlikleriyle), UMP + ATT, geçiş ve ödüllü reklam,
      müzik ve ses efektleri, 15 tür × 15 bulmaca (5x5 → 20x20), koleksiyon odaklı ana ekran,
      uygulama adı: Catgrid Collection: Nonogram
- [ ] **Aşama 5 — Yayın hazırlığı**: gerçek AdMob kimlikleri, uygulama simgesi, büyük tahtalar için yakınlaştırma,
      "Reklamları Kaldır" satın alması, App Store görselleri
- [ ] **Aşama 6 — Cila ve yayın**: ses/haptik, erişilebilirlik (VoiceOver, Dynamic Type), performans,
      App Store materyalleri
