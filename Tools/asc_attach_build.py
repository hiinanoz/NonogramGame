#!/usr/bin/env python3
"""App Store sürümüne (ör. 1.2.0) o sürümün en son yüklenen derlemesini bağlar.

İncelemeye GÖNDERMEZ; yalnızca App Store Connect'teki sürüm sayfasında "Derleme" seçilir.
Son derleme hâlâ işleniyorsa (en fazla 40 dk) bitmesini bekler.

Kullanım (iş akışında):  ASC_KEY_ID=… ASC_ISSUER_ID=… ASC_PRIVATE_KEY=… python3 Tools/asc_attach_build.py 1.2.0
"""
import sys
import time

from asc_subscriptions import BUNDLE_ID, call


def main(version):
    app_id = call("GET", f"/apps?filter[bundleId]={BUNDLE_ID}")["data"][0]["id"]
    versions = call("GET", f"/apps/{app_id}/appStoreVersions?filter[versionString]={version}&filter[platform]=IOS")["data"]
    if not versions:
        sys.exit(f"{version} sürümü App Store Connect'te yok (önce metinler yüklenmeli)")
    store_version = versions[0]
    print(f"Sürüm {version}: {store_version['attributes'].get('appStoreState')}")

    deadline = time.time() + 40 * 60
    while True:
        builds = call("GET", f"/builds?filter[app]={app_id}&filter[preReleaseVersion.version]={version}"
                             f"&sort=-uploadedDate&limit=1")["data"]
        if not builds:
            sys.exit(f"{version} için yüklenmiş derleme yok")
        build = builds[0]
        state = build["attributes"].get("processingState")
        print(f"Son derleme {build['attributes'].get('version')}: {state}")
        if state == "VALID":
            break
        if state in ("FAILED", "INVALID") or time.time() > deadline:
            sys.exit("Derleme kullanılabilir değil")
        time.sleep(60)

    call("PATCH", f"/appStoreVersions/{store_version['id']}/relationships/build",
         {"data": {"type": "builds", "id": build["id"]}})
    print(f"Derleme {build['attributes'].get('version')}, {version} sürümüne bağlandı (incelemeye gönderilmedi)")


if __name__ == "__main__":
    main(sys.argv[1])
