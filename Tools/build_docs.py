#!/usr/bin/env python3
"""docs/_src/<sayfa>.<dil>.html parçalarından çok dilli gizlilik ve destek sayfalarını üretir.

Kullanım:  python3 Tools/build_docs.py

Sayfa ziyaretçinin cihaz dilinde açılır; üstteki seçiciyle diğer dillere geçilir
(adres sonuna #de, #ja gibi eklenir). JavaScript kapalıysa tüm diller alt alta görünür.
"""
import html
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / "docs"
LANGS = [("en", "English"), ("tr", "Türkçe"), ("ja", "日本語"), ("de", "Deutsch"), ("fr", "Français"),
         ("es", "Español"), ("pt-BR", "Português"), ("ko", "한국어")]
PAGES = {
    "privacy": {
        "title": "Catgrid Privacy Policy",
        "headings": {"en": "Privacy Policy", "tr": "Gizlilik Politikası", "ja": "プライバシーポリシー",
                     "de": "Datenschutzerklärung", "fr": "Politique de confidentialité",
                     "es": "Política de privacidad", "pt-BR": "Política de Privacidade", "ko": "개인정보 처리방침"},
        "updated": "October 16, 2026",
    },
    "support": {
        "title": "Catgrid Support",
        "headings": {"en": "Support", "tr": "Destek", "ja": "サポート", "de": "Support", "fr": "Assistance",
                     "es": "Soporte", "pt-BR": "Suporte", "ko": "고객 지원"},
        "updated": None,
    },
}

SCRIPT = """<script>
(function () {
  var codes = %s;
  function pick() {
    var hash = location.hash.slice(1);
    if (codes.indexOf(hash) >= 0) return hash;
    var prefs = navigator.languages || [navigator.language || "en"];
    for (var i = 0; i < prefs.length; i++) {
      var p = prefs[i].toLowerCase();
      if (p.indexOf("pt") === 0) return "pt-BR";
      for (var j = 0; j < codes.length; j++) if (p.indexOf(codes[j].toLowerCase()) === 0) return codes[j];
    }
    return "en";
  }
  function show() {
    var lang = pick();
    document.documentElement.lang = lang;
    codes.forEach(function (code) {
      document.getElementById("lang-" + code).hidden = code !== lang;
      var link = document.querySelector('a[href="#' + code + '"]');
      if (link) link.setAttribute("aria-current", code === lang ? "true" : "false");
    });
  }
  window.addEventListener("hashchange", function () { show(); window.scrollTo(0, 0); });
  show();
})();
</script>"""


def build(page, meta):
    switcher = " ".join(f'<a href="#{code}" lang="{code}">{html.escape(name)}</a>' for code, name in LANGS)
    sections = []
    for code, _ in LANGS:
        source = DOCS / "_src" / f"{page}.{code}.html"
        if not source.exists():
            sys.exit(f"Eksik: {source.relative_to(DOCS.parent)}")
        heading = meta["headings"][code]
        sections.append(f'<section class="lang" id="lang-{code}" lang="{code}">\n<h2>{heading}</h2>\n'
                        f'{source.read_text().strip()}\n</section>')
    updated = f' · Last updated: {meta["updated"]}' if meta["updated"] else ""
    codes = "[" + ",".join(f'"{code}"' for code, _ in LANGS) + "]"
    page_html = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{meta["title"]}</title>
<link rel="stylesheet" href="style.css">
</head>
<body>
<main>
<header><img src="logo.png" alt=""><div><h1>Catgrid Collection: Nonogram</h1><div class="muted">{meta["headings"]["en"]}{updated}</div></div></header>
<nav class="langs" aria-label="Language">{switcher}</nav>

{chr(10).join(sections)}
</main>
{SCRIPT % codes}
</body>
</html>
"""
    (DOCS / f"{page}.html").write_text(page_html)
    print(f"✓ docs/{page}.html ({len(LANGS)} dil)")


if __name__ == "__main__":
    for page, meta in PAGES.items():
        build(page, meta)
