#!/usr/bin/env python3
"""Ham App Store ekran görüntülerini başlıklı mağaza görsellerine dönüştürür.

Kullanım:  python3 Tools/frame_screenshots.py <fastlane/screenshots klasörü>

Her <dil>/<sıra>_<ad>.png için: sıcak renkli zemin, üstte o dilde kısa bir başlık,
altında yuvarlatılmış köşeli ve gölgeli ekran görüntüsü. Görsel aynı boyutta kalır
(6,9" için 1320×2868) ve dosyanın üzerine yazılır. Pillow gerekir.

Yazı tipleri macOS'tan alınır (SF Pro Rounded, Hiragino, Apple SD Gothic Neo); başka
sistemde denemek için CATGRID_FONT=<yol> ile tek bir yazı tipi verilebilir.
"""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

# Sıra: 01 ana sayfa, 02 Miyav Crush, 03 Miyav Sort, 04 Kedi Kutusu, 05 Kedi Bulmaca haritası,
# 06 Kedi Bulmaca oyunu, 07 nonogram, 08 günlük, 09 koleksiyon.
# Yalnızca herkesin oynayarak ulaştığı ekranlar; Premium'a özel içerik gösterilmez.
CAPTIONS = {
    "en-US": ["5 cozy cat games\nin one app", "Meow Crush:\nmatch treats in\nthe Cat Tower", "Meow Sort:\nsort the birds\non their branches",
              "Cat Block:\nclear lines,\nbeat your record", "Cat Puzzle:\n335 levels across\n4 seasons", "One cat per color,\nrow and column",
              "Picture logic puzzles\nwith 26 cat breeds", "A fresh puzzle\nevery day", "Collect a card\nfor every breed"],
    "tr": ["Tek uygulamada\n5 sevimli kedi oyunu", "Miyav Crush:\nKedi Kulesi'nde\neşleştir", "Miyav Sort:\nkuşları dallarına\ngöre sırala",
           "Kedi Kutusu:\nsatırları temizle,\nrekorunu geç", "Kedi Bulmaca:\n4 mevsimde\n335 bölüm", "Her renge, satıra ve\nsütuna bir kedi",
           "26 kedi türüyle\nresimli mantık\nbulmacaları", "Her gün\nyeni bir bulmaca", "Her türün kartını\nkoleksiyonuna ekle"],
    "de-DE": ["5 gemütliche\nKatzenspiele\nin einer App", "Meow Crush:\nLeckerlis kombinieren\nim Katzenturm",
              "Miau Sort:\nVögel auf ihre\nÄste sortieren", "Katzenblock:\nReihen abräumen,\nRekord knacken",
              "Katzenrätsel:\n335 Level in\n4 Jahreszeiten", "Eine Katze pro Farbe,\nZeile und Spalte", "Bilderrätsel mit\n26 Katzenrassen",
              "Jeden Tag\nein neues Rätsel", "Sammle eine Karte\nfür jede Rasse"],
    "fr-FR": ["5 jeux de chats\ndouillets\ndans une appli", "Meow Crush :\nassocie les friandises\ndans la Tour des Chats",
              "Miaou Sort :\ntrie les oiseaux\nsur leurs branches", "Bloc Chat :\nefface les lignes,\nbats ton record",
              "Puzzle Chat :\n335 niveaux en\n4 saisons", "Un chat par couleur,\nligne et colonne", "Grilles logiques\navec 26 races de chats",
              "Une nouvelle grille\nchaque jour", "Une carte\npour chaque race"],
    "es-ES": ["5 juegos de gatos\nen una sola app", "Meow Crush:\ncombina premios en\nla Torre Gatuna", "Miau Sort:\nordena los pájaros\nen sus ramas",
              "Bloque Gatuno:\nlimpia líneas y\nsupera tu récord", "Puzle Gatuno:\n335 niveles en\n4 estaciones", "Un gato por color,\nfila y columna",
              "Puzles lógicos con\n26 razas de gatos", "Un puzle nuevo\ncada día", "Una carta para\ncada raza"],
    "pt-BR": ["5 jogos de gatos\nem um só app", "Meow Crush:\ncombine petiscos na\nTorre dos Gatos", "Miau Sort:\norganize os pássaros\nnos galhos",
              "Bloco do Gato:\nlimpe linhas e\nbata seu recorde", "Quebra-Gato:\n335 fases em\n4 estações", "Um gato por cor,\nlinha e coluna",
              "Desafios lógicos com\n26 raças de gatos", "Um desafio novo\ntodo dia", "Uma carta para\ncada raça"],
    "ja": ["5つの癒し猫ゲームが\nひとつに", "ニャンクラッシュ：\nキャットタワーで\nおやつをそろえよう", "ニャンソート：\n鳥を枝ごとに\n並べ替えよう",
           "ネコブロック：\nラインを消して\nハイスコアに挑戦", "ねこパズル：\n4つの季節に\n335ステージ", "色・行・列に\n猫を1匹ずつ",
           "26の猫種の\nイラストロジック", "毎日\n新しいパズル", "猫種ごとの\nカードを集めよう"],
    "ko": ["귀여운 고양이 게임\n5가지를 한 앱에서", "야옹 크러시:\n캣타워에서\n간식을 맞춰요", "냥 정렬:\n새들을 가지별로\n정렬해요",
           "고양이 블록:\n줄을 지우고\n최고 점수에 도전", "고양이 퍼즐:\n사계절 335개 레벨", "색, 행, 열마다\n고양이 한 마리",
           "26가지 품종의\n그림 로직 퍼즐", "매일 새로운\n퍼즐", "품종마다\n카드를 모아요"],
}

TOP = (255, 226, 214)
BOTTOM = (253, 244, 236)
INK = (74, 59, 53)
ACCENT = (232, 134, 128)

MAC_LATIN = "/System/Library/Fonts/SFNSRounded.ttf"
MAC_FONTS = {
    "ja": ["/System/Library/Fonts/ヒラギノ角ゴシック W7.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    "ko": ["/System/Library/Fonts/AppleSDGothicNeo.ttc"],
}


def load_font(locale, size):
    override = os.environ.get("CATGRID_FONT")
    if override:
        return ImageFont.truetype(override, size)
    for path in MAC_FONTS.get(locale, []):
        if Path(path).exists():
            return bold_face(path, size)
    font = ImageFont.truetype(MAC_LATIN, size)
    try:
        font.set_variation_by_axes([700])  # wght
    except (OSError, ValueError):
        pass
    return font


def bold_face(path, size):
    """.ttc içinden kalın yüzü seçer (Apple SD Gothic Neo'da Bold, Hiragino W7 zaten kalın)."""
    best = None
    for index in range(20):
        try:
            face = ImageFont.truetype(path, size, index=index)
        except OSError:
            break
        style = face.getname()[1].lower()
        if style in ("bold", "w7"):
            return face
        best = best or face
    return best


def gradient(size):
    width, height = size
    column = Image.new("RGB", (1, height))
    for y in range(height):
        t = y / (height - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return column.resize(size)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def frame(shot_path, caption, locale):
    shot = Image.open(shot_path).convert("RGB")
    width, height = shot.size
    canvas = gradient((width, height))
    draw = ImageDraw.Draw(canvas)
    unit = width / 1320

    # Başlık: iki-üç satır, sığmazsa küçülür
    caption_box = (round(70 * unit), round(110 * unit), width - round(70 * unit), round(585 * unit))
    size = round(118 * unit)
    while True:
        font = load_font(locale, size)
        bbox = draw.multiline_textbbox((0, 0), caption, font=font, align="center", spacing=round(size * 0.22))
        fits = bbox[2] - bbox[0] <= caption_box[2] - caption_box[0] and bbox[3] - bbox[1] <= caption_box[3] - caption_box[1]
        if fits or size <= 60:
            break
        size -= 4
    text_w, text_h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (width - text_w) / 2 - bbox[0]
    y = caption_box[1] + (caption_box[3] - caption_box[1] - text_h) / 2 - bbox[1]
    draw.multiline_text((x, y), caption, font=font, fill=INK, align="center", spacing=round(size * 0.22))

    # Başlığın altında küçük mercan çizgi
    bar_w, bar_h = round(120 * unit), round(14 * unit)
    bar_y = round(y + bbox[3] + 44 * unit)
    draw.rounded_rectangle([(width - bar_w) / 2, bar_y, (width + bar_w) / 2, bar_y + bar_h], radius=bar_h / 2, fill=ACCENT)

    # Ekran görüntüsü: küçültülmüş, yuvarlak köşeli, beyaz kenarlı ve gölgeli
    scale = 0.74
    inner = shot.resize((round(width * scale), round(height * scale)), Image.LANCZOS)
    border = round(14 * unit)
    radius = round(84 * unit)
    framed_size = (inner.width + 2 * border, inner.height + 2 * border)
    left = (width - framed_size[0]) // 2
    top = height - framed_size[1] - round(60 * unit)

    shadow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shadow).rounded_rectangle(
        [left, top + round(24 * unit), left + framed_size[0], top + framed_size[1] + round(24 * unit)],
        radius=radius + border, fill=90)
    shadow = shadow.filter(ImageFilter.GaussianBlur(round(40 * unit)))
    canvas.paste(Image.new("RGB", (width, height), (120, 80, 60)), (0, 0), shadow)

    canvas.paste(Image.new("RGB", framed_size, (255, 255, 255)), (left, top), rounded_mask(framed_size, radius + border))
    canvas.paste(inner, (left + border, top + border), rounded_mask(inner.size, radius))
    canvas.save(shot_path, "PNG")


def main(root):
    root = Path(root)
    total = 0
    for locale, captions in CAPTIONS.items():
        folder = root / locale
        if not folder.is_dir():
            print(f"{locale}: klasör yok, atlandı")
            continue
        shots = sorted(folder.glob("*.png"))
        if len(shots) != len(captions):
            # Test o dilde yarıda kaldıysa iş akışı sonradan durur; teşhis için diğerleri işlenir
            print(f"✗ {locale}: {len(shots)} görüntü var, {len(captions)} başlık bekleniyordu")
            continue
        for shot, caption in zip(shots, captions):
            frame(shot, caption, locale)
            total += 1
    print(f"{total} görüntü başlıklandı")


if __name__ == "__main__":
    main(sys.argv[1])
