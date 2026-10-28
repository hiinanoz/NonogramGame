#!/usr/bin/env python3
"""Game Center'ı App Store Connect'te kurar: uygulamanın Game Center kaydı, altı sıralama listesi
ve 8 dildeki adları (altı liste); düzenlenebilir sürümde Game Center'ı açar. Tekrar çalıştırmak güvenlidir.

Kullanım (iş akışında):  ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… python3 Tools/asc_gamecenter.py [--report]

Kimlikler uygulamadaki GameCenterService.Leaderboard ile aynı olmalı. Gerekenler: PyJWT, cryptography.
"""
import sys

from asc_subscriptions import BUNDLE_ID, call

# kimlik: (kısa ad, sıralama türü, gönderim türü, {dil: (ad, ek, tekil ek)})
LEADERBOARDS = {
    "catgrid.daily.streak": ("Daily streak", "DESC", "BEST_SCORE", {
        "en-US": ("Longest Daily Streak", " days", " day"),
        "tr": ("En Uzun Günlük Seri", " gün", " gün"),
        "ja": ("最長デイリー連続記録", "日", "日"),
        "de-DE": ("Längste Tagesserie", " Tage", " Tag"),
        "fr-FR": ("Plus longue série quotidienne", " jours", " jour"),
        "es-ES": ("Racha diaria más larga", " días", " día"),
        "pt-BR": ("Maior sequência diária", " dias", " dia"),
        "ko": ("최장 데일리 연속 기록", "일", "일"),
    }),
    "catgrid.nonogram.solved": ("Nonograms solved", "DESC", "MOST_RECENT_SCORE", {
        "en-US": ("Nonograms Solved", " puzzles", " puzzle"),
        "tr": ("Çözülen Nonogramlar", " bulmaca", " bulmaca"),
        "ja": ("解いたノノグラム", "問", "問"),
        "de-DE": ("Gelöste Nonogramme", " Rätsel", " Rätsel"),
        "fr-FR": ("Nonogrammes résolus", " grilles", " grille"),
        "es-ES": ("Nonogramas resueltos", " puzles", " puzle"),
        "pt-BR": ("Nonogramas resolvidos", " desafios", " desafio"),
        "ko": ("푼 노노그램", "개", "개"),
    }),
    "catgrid.cats.levels": ("Cat Puzzle levels", "DESC", "MOST_RECENT_SCORE", {
        "en-US": ("Cat Puzzle Levels", " levels", " level"),
        "tr": ("Kedi Bulmaca Bölümleri", " bölüm", " bölüm"),
        "ja": ("ねこパズル クリア数", "ステージ", "ステージ"),
        "de-DE": ("Katzenrätsel-Level", " Level", " Level"),
        "fr-FR": ("Niveaux Puzzle Chat", " niveaux", " niveau"),
        "es-ES": ("Niveles de Puzle Gatuno", " niveles", " nivel"),
        "pt-BR": ("Fases do Quebra-Gato", " fases", " fase"),
        "ko": ("고양이 퍼즐 레벨", "레벨", "레벨"),
    }),
    "catgrid.crush.levels": ("Meow Crush levels", "DESC", "MOST_RECENT_SCORE", {
        "en-US": ("Meow Crush Levels", " levels", " level"),
        "tr": ("Miyav Crush Bölümleri", " bölüm", " bölüm"),
        "ja": ("ニャンクラッシュ クリア数", "ステージ", "ステージ"),
        "de-DE": ("Meow Crush Level", " Level", " Level"),
        "fr-FR": ("Niveaux Meow Crush", " niveaux", " niveau"),
        "es-ES": ("Niveles de Meow Crush", " niveles", " nivel"),
        "pt-BR": ("Fases do Meow Crush", " fases", " fase"),
        "ko": ("야옹 크러시 레벨", "레벨", "레벨"),
    }),
    "catgrid.sort.levels": ("Meow Sort levels", "DESC", "MOST_RECENT_SCORE", {
        "en-US": ("Meow Sort Levels", " levels", " level"),
        "tr": ("Miyav Sort Bölümleri", " bölüm", " bölüm"),
        "ja": ("ニャンソート クリア数", "ステージ", "ステージ"),
        "de-DE": ("Miau Sort Level", " Level", " Level"),
        "fr-FR": ("Niveaux Miaou Sort", " niveaux", " niveau"),
        "es-ES": ("Niveles de Miau Sort", " niveles", " nivel"),
        "pt-BR": ("Fases do Miau Sort", " fases", " fase"),
        "ko": ("냥 정렬 레벨", "레벨", "레벨"),
    }),
    "catgrid.block.best": ("Cat Block best score", "DESC", "BEST_SCORE", {
        "en-US": ("Cat Block Best Score", " points", " point"),
        "tr": ("Kedi Kutusu Rekoru", " puan", " puan"),
        "ja": ("ネコブロック ベストスコア", "点", "点"),
        "de-DE": ("Katzenblock Rekord", " Punkte", " Punkt"),
        "fr-FR": ("Record Bloc Chat", " points", " point"),
        "es-ES": ("Récord de Bloque Gatuno", " puntos", " punto"),
        "pt-BR": ("Recorde do Bloco do Gato", " pontos", " ponto"),
        "ko": ("고양이 블록 최고 점수", "점", "점"),
    }),
}


def body(kind, attributes=None, **relations):
    data = {"type": kind}
    if attributes:
        data["attributes"] = attributes
    if relations:
        data["relationships"] = {name: {"data": {"type": t, "id": i}} for name, (t, i) in relations.items()}
    return {"data": data}


def main():
    report_only = "--report" in sys.argv
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        sys.exit(f"{BUNDLE_ID} bulunamadı")
    app_id = apps[0]["id"]
    print(f"Uygulama Apple ID: {app_id}")

    detail = call("GET", f"/apps/{app_id}/gameCenterDetail", tolerant=True).get("data")
    if not detail:
        if report_only:
            print("Game Center kaydı YOK")
            return
        detail = call("POST", "/gameCenterDetails", body("gameCenterDetails", app=("apps", app_id)))["data"]
        print("Game Center kaydı oluşturuldu")
    detail_id = detail["id"]
    print(f"Game Center kaydı: {detail_id}")

    boards = call("GET", f"/gameCenterDetails/{detail_id}/gameCenterLeaderboards?limit=200")["data"]
    existing = {b["attributes"]["vendorIdentifier"]: b for b in boards}
    for vendor_id, (reference, sort, submission, texts) in LEADERBOARDS.items():
        board = existing.get(vendor_id)
        if not board:
            if report_only:
                print(f"{vendor_id}: YOK")
                continue
            board = call("POST", "/gameCenterLeaderboards", body(
                "gameCenterLeaderboards",
                {"referenceName": reference, "vendorIdentifier": vendor_id, "defaultFormatter": "INTEGER",
                 "submissionType": submission, "scoreSortType": sort},
                gameCenterDetail=("gameCenterDetails", detail_id)))["data"]
            print(f"{vendor_id}: oluşturuldu")
        else:
            print(f"{vendor_id}: var ({board['attributes'].get('archived') and 'arşivde' or 'etkin'})")
        locs = call("GET", f"/gameCenterLeaderboards/{board['id']}/localizations?limit=50")["data"]
        have = {loc["attributes"]["locale"]: loc for loc in locs}
        for locale, (name, suffix, singular) in texts.items():
            attrs = {"name": name, "formatterSuffix": suffix, "formatterSuffixSingular": singular}
            current = have.get(locale)
            if report_only:
                print(f"  [{locale}] {'var' if current else 'YOK'}")
                continue
            if current:
                if all(current["attributes"].get(k) == v for k, v in attrs.items()):
                    continue
                call("PATCH", f"/gameCenterLeaderboardLocalizations/{current['id']}",
                     {"data": {"type": "gameCenterLeaderboardLocalizations", "id": current["id"], "attributes": attrs}})
                print(f"  [{locale}] güncellendi")
            else:
                call("POST", "/gameCenterLeaderboardLocalizations", body(
                    "gameCenterLeaderboardLocalizations", {**attrs, "locale": locale},
                    gameCenterLeaderboard=("gameCenterLeaderboards", board["id"])))
                print(f"  [{locale}] eklendi")

    # Düzenlenebilir sürümde Game Center açık olsun (inceleme ile birlikte listeler de yayına girer)
    versions = call("GET", f"/apps/{app_id}/appStoreVersions?limit=10")["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in (
        "PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED",
        "WAITING_FOR_REVIEW", "READY_FOR_REVIEW")]
    for version in editable:
        state = version["attributes"]["appStoreState"]
        number = version["attributes"]["versionString"]
        gc = call("GET", f"/appStoreVersions/{version['id']}/gameCenterAppVersion", tolerant=True).get("data")
        if gc:
            print(f"Sürüm {number} ({state}): Game Center açık")
        elif report_only:
            print(f"Sürüm {number} ({state}): Game Center KAPALI")
        else:
            result = call("POST", "/gameCenterAppVersions",
                          body("gameCenterAppVersions", appStoreVersion=("appStoreVersions", version["id"])),
                          tolerant=True)
            print(f"Sürüm {number} ({state}): Game Center "
                  f"{'açıldı' if 'error' not in result else 'açılamadı (' + str(result['error']) + ')'}")


if __name__ == "__main__":
    main()
