#!/usr/bin/env python3
"""App Store'a göndermeden önce kalan eksikleri listeler.

Kullanım:  python3 Tools/release_check.py

Kodla çözülemeyen (hesap, kimlik, adres) eksikleri yakalar; hepsi ✓ olmadan yükleme yapılmamalı.
"""
import re
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
problems, notes = [], []


def read(path):
    return (ROOT / path).read_text()


project = read("project.yml")
if "3940256099942544" in project:
    problems.append("project.yml: GADApplicationIdentifier hâlâ Google'ın test kimliği (gerçek AdMob uygulama kimliği gir)")
# DEVELOPMENT_TEAM: bulutta yüklemede APPLE_TEAM_ID sırrından verilir (bkz. .github/workflows/release.yml)
if len(re.findall(r"SKAdNetworkIdentifier", project)) < 10:
    problems.append("project.yml: SKAdNetworkItems eksik (Google'ın yayımladığı tam listeyi ekle)")

ads = read("Catgrid/Services/Ads/AdService.swift")
production = ads[ads.index("static let production"):ads.index("static var current")]
if re.search(r'UnitID: ""', production):
    problems.append("AdService.swift: AdConfiguration.production reklam birimi kimlikleri boş")

for page in ("docs/support.html", "docs/privacy.html"):
    if "SUPPORT_EMAIL" in read(page):
        problems.append(f"{page}: SUPPORT_EMAIL yer tutucusu duruyor (destek e-postası gir)")

links = read("Catgrid/Core/AppLinks.swift")
for url in re.findall(r'URL\(string: "(https://[^"]+github\.io[^"]+)"\)', links):
    try:
        with urllib.request.urlopen(url, timeout=10) as response:
            if response.status != 200:
                raise OSError(response.status)
    except Exception as error:  # noqa: BLE001
        problems.append(f"{url} açılmıyor ({error}); GitHub Pages'i /docs için aç")
if 'appStoreID = ""' in links:
    notes.append("AppLinks.appStoreID boş: App Store Connect'te uygulama oluşunca rakam kimliği gir (zorunlu değil)")

# Sıradaki güncelleme için not alınan, henüz yapılmamış işler (hatırlatma; yüklemeyi durdurmaz)
todo = ROOT / "Planning/Guncelleme-Listesi.md"
if todo.exists():
    for item in re.findall(r"^- \[ \] \*{0,2}(.+?)(?:\*\*|$)", todo.read_text(), re.M):
        notes.append(f"Güncelleme listesi: {item.strip()}")

for problem in problems:
    print(f"✗ {problem}")
for note in notes:
    print(f"• {note}")
print("✓ Yüklemeye hazır" if not problems else f"\n{len(problems)} eksik var")
sys.exit(1 if problems else 0)
