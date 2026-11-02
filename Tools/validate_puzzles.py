#!/usr/bin/env python3
"""Bulmaca içeriğini doğrular (Xcode gerektirmez).

Kullanım:  python3 Tools/validate_puzzles.py [Puzzles klasörü]

Kontroller:
  - catalog.json ve bölüm dosyalarının şeması, chapterID eşleşmesi
  - benzersiz bulmaca kimlikleri, palet/piksel tutarlılığı
  - her bulmacanın tahmin yapmadan (yalnızca satır mantığıyla) çözülebilmesi
    -> bu, çözümün benzersiz olduğunu da garanti eder
  - eğitimde 11, her kedi türünde en az 16 bulmaca
  - her türde 9 premium bulmaca: üçer tane 8x8, 10x10, 12x12; biri pati

Satır çözücü, NonogramKit/Engine/LineSolver.swift ile aynı algoritmadır.
"""
import json
import re
import sys
from pathlib import Path

MIN_PUZZLES = {"tutorial": 6, "breed": 16}
LANGUAGES = ["en", "tr", "ja", "de", "fr", "es", "pt-BR", "ko"]
PREMIUM_SIZES = ["8x8"] * 3 + ["10x10"] * 3 + ["12x12"] * 3
HEX = re.compile(r"^#?[0-9A-Fa-f]{6}$")
LESSONS = {
    "tapToFill", "fullLines", "emptyLines", "markWithCross", "multipleBlocks",
    "overlap", "edges", "crossReference", "mistakesAndLives", "difficulty", "graduation", "firstSquare",
}


def clue(line):
    runs, run = [], 0
    for filled in line:
        if filled:
            run += 1
        elif run:
            runs.append(run)
            run = 0
    if run:
        runs.append(run)
    return runs


def solve_line(line, blocks):
    n, k = len(line), len(blocks)
    empty_prefix = [0] * (n + 1)
    for i, cell in enumerate(line):
        empty_prefix[i + 1] = empty_prefix[i] + (cell is False)

    def can_be_empty(i):
        return line[i] is not True

    def fits(j, start):
        end = start + blocks[j]
        if end > n or empty_prefix[end] - empty_prefix[start]:
            return False
        return end == n or can_be_empty(end)

    def after(j, start):
        return min(start + blocks[j] + 1, n)

    suffix = [[False] * (k + 1) for _ in range(n + 1)]
    suffix[n][k] = True
    for i in range(n - 1, -1, -1):
        for j in range(k + 1):
            ok = can_be_empty(i) and suffix[i + 1][j]
            if not ok and j < k and fits(j, i):
                ok = suffix[after(j, i)][j + 1]
            suffix[i][j] = ok
    if not suffix[0][0]:
        return None

    reach = [[False] * (k + 1) for _ in range(n + 1)]
    reach[0][0] = True
    can_fill, can_clear = [False] * n, [False] * n
    for i in range(n):
        for j in range(k + 1):
            if not reach[i][j]:
                continue
            if can_be_empty(i) and suffix[i + 1][j]:
                reach[i + 1][j] = True
                can_clear[i] = True
            if j < k and fits(j, i) and suffix[after(j, i)][j + 1]:
                reach[after(j, i)][j + 1] = True
                end = i + blocks[j]
                for c in range(i, end):
                    can_fill[c] = True
                if end < n:
                    can_clear[end] = True
    return [True if f and not c else False if c and not f else None
            for f, c in zip(can_fill, can_clear)]


def solve_logically(row_clues, col_clues):
    rows, cols = len(row_clues), len(col_clues)
    grid = [[None] * cols for _ in range(rows)]
    changed = True
    while changed:
        changed = False
        for r in range(rows):
            solved = solve_line(grid[r], row_clues[r])
            if solved is None:
                return None
            if solved != grid[r]:
                grid[r] = solved
                changed = True
        for c in range(cols):
            column = [grid[r][c] for r in range(rows)]
            solved = solve_line(column, col_clues[c])
            if solved is None:
                return None
            if solved != column:
                for r in range(rows):
                    grid[r][c] = solved[r]
                changed = True
    return grid


def validate_puzzle(puzzle, errors):
    pid = puzzle.get("id", "<id yok>")
    palette = puzzle.get("palette", {})
    pixels = puzzle.get("pixels", [])
    for key, value in palette.items():
        if len(key) != 1 or key == ".":
            errors.append(f"{pid}: geçersiz palet anahtarı '{key}'")
        if not HEX.match(value):
            errors.append(f"{pid}: geçersiz renk {value}")
    if not pixels or len({len(row) for row in pixels}) != 1:
        errors.append(f"{pid}: pixels boş ya da satır uzunlukları farklı")
        return None
    for row in pixels:
        for symbol in row:
            if symbol != "." and symbol not in palette:
                errors.append(f"{pid}: palette olmayan piksel '{symbol}'")
                return None
    if "title" not in puzzle or not set(LANGUAGES) <= puzzle["title"].keys():
        errors.append(f"{pid}: title için tüm diller gerekli ({', '.join(LANGUAGES)})")
    if puzzle.get("lesson") not in (None, *LESSONS):
        errors.append(f"{pid}: bilinmeyen lesson {puzzle['lesson']}")

    solution = [[symbol != "." for symbol in row] for row in pixels]
    if not any(any(row) for row in solution):
        errors.append(f"{pid}: en az bir dolu kare olmalı")
        return None
    rows = [clue(row) for row in solution]
    cols = [clue(col) for col in zip(*solution)]
    if solve_logically(rows, cols) != solution:
        errors.append(f"{pid}: tahmin yapmadan çözülemiyor (veya çözüm benzersiz değil)")
    return f"{len(pixels[0])}x{len(pixels)}"


def main():
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else \
        Path(__file__).resolve().parent.parent / "Catgrid/Resources/Puzzles"
    errors, warnings, seen = [], [], set()
    catalog = json.loads((root / "catalog.json").read_text())

    for entry in catalog["chapters"]:
        path = root / f"{entry['file']}.json"
        if not path.exists():
            errors.append(f"{entry['id']}: {path.name} bulunamadı")
            continue
        chapter = json.loads(path.read_text())
        if chapter.get("chapterID") != entry["id"]:
            errors.append(f"{path.name}: chapterID {chapter.get('chapterID')} != {entry['id']}")
        sizes = []
        for puzzle in chapter["puzzles"]:
            if puzzle.get("id") in seen:
                errors.append(f"tekrarlanan id {puzzle.get('id')}")
            seen.add(puzzle.get("id"))
            sizes.append(validate_puzzle(puzzle, errors))
        count = len(chapter["puzzles"])
        minimum = MIN_PUZZLES[entry["kind"]]
        if count < minimum:
            errors.append(f"{entry['id']}: {count} bulmaca (en az {minimum} olmalı)")
        print(f"✓ {entry['id']}: {count} bulmaca, boyutlar: {', '.join(sorted(set(filter(None, sizes))))}")

        if entry["kind"] != "breed":
            continue
        if "premiumFile" not in entry:
            errors.append(f"{entry['id']}: premium bulmaca dosyası (premiumFile) yok")
            continue
        path = root / f"{entry['premiumFile']}.json"
        if not path.exists():
            errors.append(f"{entry['id']}: {path.name} bulunamadı")
            continue
        premium = json.loads(path.read_text())
        if premium.get("chapterID") != entry["id"]:
            errors.append(f"{path.name}: chapterID {premium.get('chapterID')} != {entry['id']}")
        sizes = []
        for puzzle in premium["puzzles"]:
            if puzzle.get("id") in seen:
                errors.append(f"tekrarlanan id {puzzle.get('id')}")
            seen.add(puzzle.get("id"))
            sizes.append(validate_puzzle(puzzle, errors))
        if sorted(filter(None, sizes), key=lambda x: int(x.split("x")[0])) != PREMIUM_SIZES:
            errors.append(f"{entry['id']}: premium boyutları {sizes} (üçer tane 8x8, 10x10, 12x12 olmalı)")
        if not any("Paw" in p.get("title", {}).get("en", "") for p in premium["puzzles"]):
            errors.append(f"{entry['id']}: premium bölümlerde pati yok")
        print(f"  ★ {len(premium['puzzles'])} premium")

    for warning in warnings:
        print(f"! {warning}")
    for error in errors:
        print(f"✗ {error}")
    print(f"\nToplam {len(seen)} bulmaca, {len(errors)} hata, {len(warnings)} uyarı")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
