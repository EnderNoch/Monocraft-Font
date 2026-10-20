#!/bin/zsh
# ./publish.sh build   — zip the pack into dist/
# ./publish.sh         — zip it and upload it to Modrinth as the version in VERSION
#                        (set CHANGELOG="..." for the changelog)
set -euo pipefail
cd "${0:A:h}"

PROJECT=monocraft-font
GAME_VERSION=26.3
VERSION=$(<VERSION)
ZIP="dist/Monocraft-Font-$VERSION.zip"

mkdir -p dist
rm -f "$ZIP"
(cd pack && zip -qrX "../$ZIP" . -x '.*')
echo "Built $ZIP"
[[ "${1:-}" == build ]] && exit 0

TOKEN=${MODRINTH_TOKEN:-$(tr -d ' \n\r' < ~/.config/modrinth/token)}
DATA=$(python3 -I -c 'import json,sys; print(json.dumps({
    "project_id": sys.argv[1], "version_number": sys.argv[2], "name": f"{sys.argv[2]} for Minecraft {sys.argv[3]}",
    "changelog": sys.argv[4], "game_versions": [sys.argv[3]], "loaders": ["minecraft"], "version_type": "release",
    "featured": True, "dependencies": [], "file_parts": ["file"], "primary_file": "file"}))' \
    "$PROJECT" "$VERSION" "$GAME_VERSION" "${CHANGELOG:-}")
RESPONSE=$(curl -sS -f -X POST -H "Authorization: $TOKEN" -F "data=$DATA" -F "file=@$ZIP;type=application/zip" \
    https://api.modrinth.com/v2/version)
ID=$(python3 -I -c 'import json,sys; print(json.loads(sys.argv[1])["id"])' "$RESPONSE")
echo "Uploaded version $VERSION as $ID"

# Resource packs are client-only; the version upload cannot say so, the v3 API can.
curl -sS -f -X PATCH -H "Authorization: $TOKEN" -H "Content-Type: application/json" \
    --data '{"environment":"client_only"}' "https://api.modrinth.com/v3/version/$ID"
echo "Marked $ID as client-only"
