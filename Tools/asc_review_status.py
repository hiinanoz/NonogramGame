#!/usr/bin/env python3
"""App Store Connect'teki inceleme durumunu raporlar (hiçbir şeyi değiştirmez): sürümler ve
durumları, inceleme gönderimleri ve içindekiler, sürüme bağlı yapı, abonelikler ve Game Center.

Kullanım (iş akışında):  ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… python3 Tools/asc_review_status.py
"""
from asc_subscriptions import BUNDLE_ID, call


def attrs(item):
    return item.get("attributes", {}) if item else {}


def main():
    apps = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    app = apps[0]
    app_id = app["id"]
    print(f"Uygulama: {attrs(app).get('name')} ({app_id})")

    print("\n== Sürümler ==")
    versions = call("GET", f"/apps/{app_id}/appStoreVersions?limit=6", tolerant=True).get("data", [])
    for v in versions:
        a = attrs(v)
        print(f"- {a.get('versionString')}  durum: {a.get('appStoreState')} / {a.get('appVersionState')}"
              f"  oluşturma: {a.get('createdDate')}  yayın türü: {a.get('releaseType')}")
        build = call("GET", f"/appStoreVersions/{v['id']}/build", tolerant=True).get("data")
        if build:
            b = attrs(build)
            print(f"    yapı: {b.get('version')}  işleme: {b.get('processingState')}  yüklenme: {b.get('uploadedDate')}")
        else:
            print("    yapı: BAĞLI DEĞİL")
        phased = call("GET", f"/appStoreVersions/{v['id']}/appStoreVersionSubmission", tolerant=True).get("data")
        if phased:
            print(f"    (eski tip gönderim kaydı var: {phased['id']})")

    print("\n== İnceleme gönderimleri ==")
    subs = call("GET", f"/reviewSubmissions?filter[app]={app_id}&limit=10", tolerant=True)
    if "error" in subs:
        print(f"okunamadı: {subs['error']}")
    for s in subs.get("data", []):
        a = attrs(s)
        print(f"- {s['id']}  durum: {a.get('state')}  gönderildi: {a.get('submittedDate')}  platform: {a.get('platform')}")
        items = call("GET", f"/reviewSubmissions/{s['id']}/items?limit=20", tolerant=True).get("data", [])
        for item in items:
            ia = attrs(item)
            related = [name for name, rel in item.get("relationships", {}).items()
                       if isinstance(rel, dict) and rel.get("data")]
            print(f"    öğe: {ia.get('state')}  {', '.join(related)}")

    print("\n== Abonelikler ==")
    groups = call("GET", f"/apps/{app_id}/subscriptionGroups?limit=10", tolerant=True).get("data", [])
    for g in groups:
        print(f"- grup: {attrs(g).get('referenceName')}")
        for s in call("GET", f"/subscriptionGroups/{g['id']}/subscriptions?limit=20", tolerant=True).get("data", []):
            a = attrs(s)
            print(f"    {a.get('productId')}: {a.get('state')}")

    print("\n== Uygulama içi satın almalar ==")
    iaps = call("GET", f"/apps/{app_id}/inAppPurchasesV2?limit=20", tolerant=True)
    for i in iaps.get("data", []):
        a = attrs(i)
        print(f"- {a.get('productId')}: {a.get('state')}")
    if not iaps.get("data"):
        print("- yok")

    print("\n== Game Center ==")
    detail = call("GET", f"/apps/{app_id}/gameCenterDetail", tolerant=True).get("data")
    print("- kayıt var" if detail else "- kayıt yok")

    print("\n== Uygulama bilgisi ==")
    infos = call("GET", f"/apps/{app_id}/appInfos", tolerant=True).get("data", [])
    for info in infos:
        a = attrs(info)
        print(f"- durum: {a.get('appStoreState') or a.get('state')}  yaş sınırı: {a.get('appStoreAgeRating')}")


if __name__ == "__main__":
    main()
