import NonogramKit
import SwiftUI

/// Kedi Kulesi bina teması: dört bina aynı yerleşim motorunu kullanır; renkler, pencere manzarası,
/// mobilya ve aksesuarlar binaya göre değişir. Görseller Assets'e şu adlarla eklenirse çizilenlerin
/// yerine kendiliğinden kullanılır (numara/yazı/arayüz olmadan):
///
///     tower-<anahtar>-wall-<1…>        oda arka duvarı (pencere dahil, mobilyasız)
///     tower-<anahtar>-furniture-<1…>   ana mobilya (koltuk, yatak, minder, kedi yatağı)
///     tower-<anahtar>-accessory-<1…>   aksesuar (lamba, bitki, kitaplık…)
///     tower-<anahtar>-special          her 15 katta dönüm noktası odası
///     tower-<anahtar>-roof, tower-<anahtar>-base, tower-<anahtar>-sky(-night)
///
/// Anahtarlar: yarn (Yumak Apartmanı), moon (Ay Işığı Konağı), seaside (Deniz Tatili Rezidansı),
/// snow (Karlı Pati Kuleleri). Kedi kareleri: crush-tower-cat-<1…5>; göz kırpma için isteğe bağlı
/// crush-tower-cat-<n>-blink-<1…k>.
@MainActor
struct CatTowerTheme {
    enum Scenery {
        case garden
        case night
        case sea
        case snow
    }

    let index: Int
    let key: String
    let scenery: Scenery
    /// Arka duvar kâğıtları (çizim yedeği): zemin rengi ve desen rengi
    let wallpapers: [(base: Color, pattern: Color)]
    let floors: [Color]
    let furniture: [Color]
    /// Aksesuarlar (çizim yedeği): SF Symbol ve rengi
    let accessories: [(symbol: String, color: Color)]
    /// Dış taş duvar (gündüz)
    let stone: (top: Color, bottom: Color, joint: Color)
    let roof: [Color]
    let flowers: [Color]
    /// Gökyüzü: gündüz ve gece
    let sky: [Color]
    let nightSky: [Color]

    static let keys = ["yarn", "moon", "seaside", "snow"]

    init(index: Int) {
        self.index = index
        let k = max(0, min(index, Self.keys.count - 1))
        key = Self.keys[k]
        switch k {
        case 0:
            scenery = .garden
            wallpapers = [(Color(hex: "#FBE3D6"), Color(hex: "#F2C3B0")), (Color(hex: "#E5F1DD"), Color(hex: "#C7DFB8")), (Color(hex: "#FFF1D6"), Color(hex: "#F3D79F"))]
            floors = [Color(hex: "#D9A57A"), Color(hex: "#C98E62"), Color(hex: "#E2B98C")]
            furniture = [Color(hex: "#F09AB2"), Color(hex: "#9FCB9A"), Color(hex: "#F5C78E")]
            accessories = [("leaf.fill", Color(hex: "#5FA86B")), ("books.vertical.fill", Color(hex: "#9C6B47")), ("lamp.table.fill", Color(hex: "#E6A04B")),
                           ("teddybear.fill", Color(hex: "#C08A5E")), ("birthday.cake.fill", Color(hex: "#F28AA8"))]
            stone = (Color(hex: "#F6E7D2"), Color(hex: "#EBD5B8"), Color(hex: "#D9BE9C"))
            roof = [Color(hex: "#F08A6C"), Color(hex: "#D9634A")]
            flowers = [Color(hex: "#F49AB8"), .white, Color(hex: "#FFD36E")]
            sky = [Color(hex: "#BFE4FA"), Color(hex: "#E7F1FB"), Color(hex: "#FFE4D2")]
            nightSky = [Color(hex: "#1E2250"), Color(hex: "#3B3172"), Color(hex: "#6B4C8E")]
        case 1:
            scenery = .night
            wallpapers = [(Color(hex: "#E6DDF6"), Color(hex: "#C9B8EA")), (Color(hex: "#D9E0F5"), Color(hex: "#B5C2EA")), (Color(hex: "#F1E4F2"), Color(hex: "#D9BEDC"))]
            floors = [Color(hex: "#8E6E8F"), Color(hex: "#A07E9E"), Color(hex: "#7C6A92")]
            furniture = [Color(hex: "#9F8AD8"), Color(hex: "#7F96D8"), Color(hex: "#D7A0D8")]
            accessories = [("moon.stars.fill", Color(hex: "#F5D77A")), ("lamp.floor.fill", Color(hex: "#E8B85A")), ("books.vertical.fill", Color(hex: "#7E6AA8")),
                           ("sparkles", Color(hex: "#F5D77A")), ("hourglass", Color(hex: "#B08A6A"))]
            stone = (Color(hex: "#E9E1EF"), Color(hex: "#D3C8DE"), Color(hex: "#B9A9C9"))
            roof = [Color(hex: "#8F86D6"), Color(hex: "#5F57A8")]
            flowers = [Color(hex: "#C9B6F0"), .white, Color(hex: "#F5D77A")]
            sky = [Color(hex: "#C9C2EE"), Color(hex: "#E8DDF6"), Color(hex: "#FBDDE6")]
            nightSky = [Color(hex: "#15183F"), Color(hex: "#2E2766"), Color(hex: "#56417F")]
        case 2:
            scenery = .sea
            wallpapers = [(Color(hex: "#DDF2F2"), Color(hex: "#B5E1E1")), (Color(hex: "#FFF4E2"), Color(hex: "#F5DDB4")), (Color(hex: "#E2EEFA"), Color(hex: "#BED6EF"))]
            floors = [Color(hex: "#E6CFA6"), Color(hex: "#D8BB8C"), Color(hex: "#C9E0E0")]
            furniture = [Color(hex: "#6CC3C8"), Color(hex: "#F6A889"), Color(hex: "#F3D58A")]
            accessories = [("sun.max.fill", Color(hex: "#F5B93B")), ("fish.fill", Color(hex: "#F28C5A")), ("sailboat.fill", Color(hex: "#5A9BD6")),
                           ("beach.umbrella.fill", Color(hex: "#EA6F7E")), ("leaf.fill", Color(hex: "#3FA67A"))]
            stone = (Color(hex: "#FBF7F0"), Color(hex: "#EDE4D6"), Color(hex: "#D8CBB6"))
            roof = [Color(hex: "#6CC3C8"), Color(hex: "#3E99A3")]
            flowers = [Color(hex: "#F6A889"), .white, Color(hex: "#FFD36E")]
            sky = [Color(hex: "#A9E0F5"), Color(hex: "#DFF4FB"), Color(hex: "#FFF0DA")]
            nightSky = [Color(hex: "#13244A"), Color(hex: "#1E3E6E"), Color(hex: "#3C6A8E")]
        default:
            scenery = .snow
            wallpapers = [(Color(hex: "#F6EBDD"), Color(hex: "#E7CFB2")), (Color(hex: "#E5EEF6"), Color(hex: "#C6D8EA")), (Color(hex: "#F8E1DF"), Color(hex: "#E8B9B4"))]
            floors = [Color(hex: "#A97B57"), Color(hex: "#8E6446"), Color(hex: "#C49A74")]
            furniture = [Color(hex: "#C8584F"), Color(hex: "#7FA8C8"), Color(hex: "#E8C9A0")]
            accessories = [("flame.fill", Color(hex: "#F08A3C")), ("mug.fill", Color(hex: "#C8584F")), ("gift.fill", Color(hex: "#5FA86B")),
                           ("snowflake", Color(hex: "#7FB7E0")), ("tree.fill", Color(hex: "#3F8A5A"))]
            stone = (Color(hex: "#F2EEEA"), Color(hex: "#DCD3CA"), Color(hex: "#C2B4A6"))
            roof = [Color(hex: "#C8584F"), Color(hex: "#963B35")]
            flowers = [.white, Color(hex: "#E8F2FA"), Color(hex: "#C8584F")]
            sky = [Color(hex: "#CFE3F2"), Color(hex: "#EEF5FA"), Color(hex: "#FFFFFF")]
            nightSky = [Color(hex: "#1A2340"), Color(hex: "#2E3C63"), Color(hex: "#5A6E92")]
        }
    }

    // MARK: - Görseller (varsa)

    func asset(_ kind: String, _ number: Int? = nil) -> UIImage? {
        let name = number.map { "tower-\(key)-\(kind)-\($0)" } ?? "tower-\(key)-\(kind)"
        return CatTowerImageCache.image(name)
    }

    /// Katman sayıları: görsel set eklenince onun boyutu, yoksa çizim yedeğinin sayısı.
    var counts: CatTowerRoomPlan.Counts {
        CatTowerRoomPlan.Counts(
            walls: CatTowerImageCache.count(prefix: "tower-\(key)-wall-") ?? wallpapers.count,
            windows: 3,
            floors: floors.count,
            furniture: CatTowerImageCache.count(prefix: "tower-\(key)-furniture-") ?? furniture.count,
            accessories: CatTowerImageCache.count(prefix: "tower-\(key)-accessory-") ?? accessories.count,
            cats: CatTowerImageCache.count(prefix: "crush-tower-cat-") ?? 5
        )
    }
}

/// Kule görsellerinin önbelleği: aynı oda görseli yüzlerce katta bir kez yüklenir.
@MainActor
enum CatTowerImageCache {
    private static var images: [String: UIImage?] = [:]
    private static var counts: [String: Int?] = [:]

    static func image(_ name: String) -> UIImage? {
        if let cached = images[name] { return cached }
        let image = UIImage(named: name)
        images[name] = image
        return image
    }

    /// `prefix1`, `prefix2`… dizisinde kaç görsel var (hiç yoksa `nil`).
    static func count(prefix: String) -> Int? {
        if let cached = counts[prefix] { return cached }
        var n = 0
        while image("\(prefix)\(n + 1)") != nil { n += 1 }
        let result: Int? = n > 0 ? n : nil
        counts[prefix] = result
        return result
    }
}
