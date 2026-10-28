#!/usr/bin/env python3
"""String Catalog (.xcstrings) doğrulayıcı.

Kullanım:  python3 Tools/validate_strings.py

Kontroller:
  - Çoğul biçimli (plural) bir anahtar en fazla BİR biçim argümanı içerebilir.
    Birden fazlası varsa Xcode çoğul kuralını yanlış argümana uygulayabilir; sayı nesne (%@)
    gibi okunur ve uygulama EXC_BAD_ACCESS ile çöker.
  - Her çevirinin biçim argümanları (%@, %lld...) anahtardakilerle aynı türde ve sayıda olmalı.
    Çeviri argümanların sırasını değiştiriyorsa sıra numarası yazılmalı (%2$@ ... %1$lld);
    yoksa sayı nesne gibi okunur ve uygulama çöker.
  - Her anahtarın tüm dillerde (tr, ja, de, fr, es, pt-BR, ko) çevirisi olmalı.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LANGUAGES = ["tr", "ja", "de", "fr", "es", "pt-BR", "ko"]
CATALOGS = [ROOT / "Catgrid/Resources/Localizable.xcstrings", ROOT / "Catgrid/Resources/InfoPlist.xcstrings"]
SPEC = re.compile(r"%(?:(\d+)\$)?(lld|ld|d|@|f|%)")


def specs(text):
    """Argümanlar, karşılık geldikleri sıraya göre: [(sıra, tür), ...]."""
    found = [(position, kind) for position, kind in SPEC.findall(text) if kind != "%"]
    return sorted((int(position) if position else index, kind) for index, (position, kind) in enumerate(found, 1))


def values(localization):
    if "stringUnit" in localization:
        yield localization["stringUnit"]["value"]
    for variation in localization.get("variations", {}).values():
        for case in variation.values():
            yield from values(case)


def main():
    errors = []
    for path in CATALOGS:
        strings = json.loads(path.read_text())["strings"]
        for key, entry in strings.items():
            localizations = entry.get("localizations", {})
            expected = specs(key) if path.name == "Localizable.xcstrings" else None
            plural = any("variations" in loc for loc in localizations.values())
            if plural and expected is not None and len(expected) > 1:
                errors.append(f"{path.name}: çoğul anahtarda birden fazla argüman: {key!r}")
            for language in LANGUAGES:
                if language not in localizations:
                    errors.append(f"{path.name}: [{language}] çeviri yok: {key!r}")
            if expected is None:
                continue
            for language, localization in localizations.items():
                for value in values(localization):
                    if specs(value) != expected:
                        errors.append(f"{path.name}: [{language}] argümanlar uyuşmuyor: {key!r} -> {value!r}")
    for error in errors:
        print(f"✗ {error}")
    print(f"{len(errors)} hata")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
