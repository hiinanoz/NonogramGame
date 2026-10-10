# App Store'a yükleme (bulut)

Uygulama GitHub'daki bir Mac sunucusunda **Xcode 26** ile derlenir, imzalanır ve App Store Connect'e
(TestFlight) gönderilir. Kendi Mac'inde Xcode 15.2 ile geliştirmeye devam edebilirsin.

## Bir kez yapılacak kurulum

### 1. Bundle ID'yi kaydet
1. https://developer.apple.com/account → **Certificates, IDs & Profiles** → **Identifiers** → **+**
2. **App IDs** → **App** → Continue
3. Description: `Catgrid`, Bundle ID: **Explicit** → `com.catgridcollection.nonogram`
4. Capabilities listesinde **In-App Purchase** işaretli kalsın → Continue → Register

### 2. App Store Connect'te uygulamayı oluştur
1. https://appstoreconnect.apple.com → **Apps** → **+** → **New App**
2. Platform: iOS · Name: `Catgrid Collection: Nonogram` · Primary Language: **English (U.S.)**
3. Bundle ID: `com.catgridcollection.nonogram` · SKU: `catgrid001` · User Access: Full Access → Create

### 3. API anahtarı oluştur
1. App Store Connect → **Users and Access** → **Integrations** → **App Store Connect API**
   (ilk seferde "Request Access" çıkarsa kabul et)
2. **Team Keys** → **+** → Name: `GitHub Upload` · Access: **Admin** → Generate
3. Sayfada görünen **Issuer ID** ve anahtarın **Key ID**'sini not et
4. **Download API Key** → `AuthKey_XXXXXXXXXX.p8` dosyası iner (**yalnızca bir kez** indirilebilir, sakla)

### 4. Team ID'yi bul
https://developer.apple.com/account → **Membership details** → **Team ID** (10 karakter)

### 5. GitHub'a sırları ekle
GitHub'da repo → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**.
Dört sır ekle (adlar birebir aynı olmalı):

| Name | Değer |
|---|---|
| `APPLE_TEAM_ID` | Team ID |
| `ASC_KEY_ID` | Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_PRIVATE_KEY` | `.p8` dosyasını TextEdit ile aç, **tüm içeriği** (BEGIN/END satırları dahil) kopyala-yapıştır |

Bu bilgileri hiçbir yere (mesaj, e-posta) yazma; yalnızca GitHub sırlarına gir.

## Her yüklemede
1. GitHub'da repo → **Actions** → solda **App Store'a yükle** → **Run workflow** → **Run workflow**
2. 15-25 dakika sürer. Yeşil tik = yüklendi.
3. 10-30 dakika sonra App Store Connect → uygulama → **TestFlight**'ta derleme görünür.
4. iPhone'una **TestFlight** uygulamasını kur, kendini "Internal Testing" grubuna ekle ve test et.

Derleme numarası her çalıştırmada otomatik artar. Sürüm numarası (`1.0.0`) `project.yml` içindeki
`MARKETING_VERSION`'dır; yeni bir App Store sürümünde bunu artırırız.

## Kontrol
`python3 Tools/release_check.py` App Store incelemesine göndermeden önce kalan eksikleri listeler.

## Sıradaki yüklemede hatırlanacaklar

- [ ] App Store Connect'te her dil için **Privacy Policy URL**, **Support URL** ve **Marketing URL** alanlarını
  güncelle: `https://hii.othinks.com/catgrid/privacy`, `https://hii.othinks.com/catgrid/support`,
  `https://hii.othinks.com/catgrid`. Uygulamadaki linkler ve `fastlane/metadata` metinleri zaten güncellendi;
  açıklamadaki gizlilik satırı yeni sürümle birlikte değişir.
