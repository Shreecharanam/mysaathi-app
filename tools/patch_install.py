"""Patch the generated Android project so the app can install its own update.

Adds:
  * REQUEST_INSTALL_PACKAGES permission
  * androidx FileProvider (authority = <applicationId>.fileprovider)
  * res/xml/file_paths.xml so the cached APK can be shared with the installer

Run after `flutter create` has generated the android/ folder.
"""

import os

MANIFEST = "android/app/src/main/AndroidManifest.xml"
PERMISSION = (
    '    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>\n'
)
PROVIDER = """
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
"""

FILE_PATHS = """<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="cache" path="." />
    <files-path name="files" path="." />
    <external-cache-path name="extcache" path="." />
</paths>
"""


def main() -> None:
    if not os.path.exists(MANIFEST):
        print("ERROR: manifest not found:", MANIFEST)
        raise SystemExit(1)

    with open(MANIFEST, encoding="utf-8") as fh:
        manifest = fh.read()

    changed = False

    if "REQUEST_INSTALL_PACKAGES" not in manifest:
        manifest = manifest.replace(
            "<application", PERMISSION + "    <application", 1
        )
        changed = True
        print("added REQUEST_INSTALL_PACKAGES")

    if "androidx.core.content.FileProvider" not in manifest:
        manifest = manifest.replace("</application>", PROVIDER + "    </application>", 1)
        changed = True
        print("added FileProvider")

    if changed:
        with open(MANIFEST, "w", encoding="utf-8") as fh:
            fh.write(manifest)

    xml_dir = os.path.join("android", "app", "src", "main", "res", "xml")
    os.makedirs(xml_dir, exist_ok=True)
    with open(os.path.join(xml_dir, "file_paths.xml"), "w", encoding="utf-8") as fh:
        fh.write(FILE_PATHS)
    print("wrote res/xml/file_paths.xml")

    print("install patch done")


if __name__ == "__main__":
    main()
