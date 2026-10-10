#!/usr/bin/env bash
set -euo pipefail
SOURCE="ios_app_icon.png"
ICONSET="ios/Runner/Assets.xcassets/AppIcon.appiconset"
if [[ ! -f "$SOURCE" ]]; then
  echo "::error::Missing $SOURCE. Upload the approved 1024x1024 opaque JETKIZ app icon before releasing."
  exit 1
fi
if [[ "$(sips -g pixelWidth "$SOURCE" | tail -1 | awk '{print $2}')" != "1024" ]] || [[ "$(sips -g pixelHeight "$SOURCE" | tail -1 | awk '{print $2}')" != "1024" ]]; then
  echo "::error::Icon must be exactly 1024x1024"; exit 1
fi
if sips -g hasAlpha "$SOURCE" | grep -q 'hasAlpha: yes'; then
  echo "::error::Icon must not have transparency"; exit 1
fi
python3 - <<'PY'
import json, pathlib, subprocess
folder=pathlib.Path("ios/Runner/Assets.xcassets/AppIcon.appiconset")
data=json.loads((folder/"Contents.json").read_text())
src="ios_app_icon.png"
for item in data["images"]:
    name=item.get("filename")
    if not name:
        continue
    size=float(item["size"].split("x")[0])
    scale=int(item.get("scale","1x").rstrip("x"))
    pixels=round(size*scale)
    if pixels==1024:
        import shutil
        shutil.copyfile(src, folder/name)
    else:
        subprocess.run(["sips","-s","format","png","-z",str(pixels),str(pixels),src,"--out",str(folder/name)],check=True,stdout=subprocess.DEVNULL)
print("Generated all iOS AppIcon assets from approved JETKIZ logo")
PY
