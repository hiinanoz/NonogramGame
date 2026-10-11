"""Art/incoming/ altındaki yeni tasarım çizimlerini Assets.xcassets/Illustrations'a aktarır.

- Sahneler (home-hero, celebrate-hero, cat-theme-N) JPEG'e çevrilip küçültülür.
- Kesik kediler (mode-*, daily-cat, premium-cat) şeffaf PNG kalır, boş kenarları kırpılır.
- Şeffaflık deseni (gri-beyaz kareler) resmin içine çizilmişse arka plan olarak silinir.

Kullanım: python3 Tools/import_illustrations.py
"""
from pathlib import Path
import json

import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Art/incoming"
DEST = ROOT / "Catgrid/Resources/Assets.xcassets/Illustrations"

# ad: (genişlik, şeffaf mı)
SPECS = {
    "home-hero": (1800, False),
    "home-hero-dark": (1800, False),
    "home-premium": (1600, False),
    "home-premium-dark": (1600, False),
    "celebrate-hero": (1600, False),
    "cat-theme-1": (1500, False),
    "cat-theme-2": (1500, False),
    "cat-theme-3": (1500, False),
    "cat-theme-4": (1500, False),
    "mode-daily": (900, True),
    "mode-collection": (900, True),
    "mode-cats": (900, True),
    "daily-cat": (600, True),
    "premium-cat": (500, True),
}


def remove_baked_checkerboard(image: Image.Image) -> Image.Image:
    """Açık renkli, renksiz (gri/beyaz) arka planı siler; kedinin içindeki beyazlar korunur."""
    rgb = image.convert("RGB")
    pixels = np.array(rgb).astype(int)
    background = ((pixels.max(2) - pixels.min(2)) <= 10) & (pixels.min(2) >= 180)
    foreground = ndimage.binary_opening(~background, iterations=2)
    labels, count = ndimage.label(foreground)
    sizes = ndimage.sum(foreground, labels, range(1, count + 1))
    foreground = labels == 1 + int(np.argmax(sizes))
    foreground = ndimage.binary_fill_holes(foreground)
    foreground = ndimage.binary_erosion(foreground, iterations=1)
    alpha = Image.fromarray((foreground * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(1.0))
    result = rgb.convert("RGBA")
    result.putalpha(alpha)
    return result


def has_real_alpha(image: Image.Image) -> bool:
    if image.mode not in ("RGBA", "LA", "P"):
        return False
    alpha = image.convert("RGBA").getchannel("A")
    return alpha.getextrema()[0] < 250


def write_imageset(name: str, filename: str) -> None:
    folder = DEST / f"{name}.imageset"
    (folder / "Contents.json").write_text(json.dumps({
        "images": [{"filename": filename, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")


def main() -> None:
    DEST.mkdir(parents=True, exist_ok=True)
    (DEST / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    for name, (width, transparent) in SPECS.items():
        source = next((p for p in SRC.glob(f"{name}.*") if p.suffix.lower() in (".png", ".jpg", ".jpeg")), None)
        if source is None:
            print(f"yok: {name}")
            continue
        image = Image.open(source)
        folder = DEST / f"{name}.imageset"
        folder.mkdir(exist_ok=True)
        for old in folder.glob("*.*"):
            if old.name != "Contents.json":
                old.unlink()
        if transparent:
            image = image.convert("RGBA") if has_real_alpha(image) else remove_baked_checkerboard(image)
            box = image.getchannel("A").point(lambda v: 255 if v > 10 else 0).getbbox()
            if box:
                image = image.crop(box)
            if image.width > width:
                image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
            filename = f"{name}.png"
            image.save(folder / filename, optimize=True)
        else:
            image = image.convert("RGB")
            if image.width > width:
                image = image.resize((width, round(image.height * width / image.width)), Image.LANCZOS)
            filename = f"{name}.jpg"
            image.save(folder / filename, quality=86, optimize=True, progressive=True)
        write_imageset(name, filename)
        print(f"{name}: {image.size} → {filename} ({(folder / filename).stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
