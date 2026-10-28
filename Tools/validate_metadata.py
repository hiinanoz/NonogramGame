#!/usr/bin/env python3
"""App Store mağaza metinlerinin Apple sınırlarına uyduğunu doğrular.

Kullanım:  python3 Tools/validate_metadata.py
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "fastlane/metadata"
LOCALES = ["en-US", "tr", "ja", "de-DE", "fr-FR", "es-ES", "pt-BR", "ko"]
LIMITS = {"name": 30, "subtitle": 30, "promotional_text": 170, "keywords": 100, "description": 4000, "release_notes": 4000}
URLS = ["privacy_url", "support_url", "marketing_url"]

errors = []
for locale in LOCALES:
    folder = ROOT / locale
    for field, limit in LIMITS.items():
        path = folder / f"{field}.txt"
        if not path.exists():
            errors.append(f"{locale}/{field}.txt yok")
            continue
        text = path.read_text().strip()
        if not text:
            errors.append(f"{locale}/{field}.txt boş")
        if len(text) > limit:
            errors.append(f"{locale}/{field}.txt {len(text)} karakter (sınır {limit})")
        if field == "keywords" and ", " in text:
            errors.append(f"{locale}/keywords.txt virgülden sonra boşluk var (karakter israfı)")
    for field in URLS:
        if not (folder / f"{field}.txt").read_text().strip().startswith("https://"):
            errors.append(f"{locale}/{field}.txt geçersiz")
for error in errors:
    print(f"✗ {error}")
print(f"{len(LOCALES)} dil, {len(errors)} hata")
sys.exit(1 if errors else 0)
