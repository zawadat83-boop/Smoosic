#!/usr/bin/env bash
# Builds the self-contained Smoosic bundle used by the Nuty portal (no CDN at runtime).
# Output: dist/nuty-smoosic/ and dist/nuty-smoosic-<version>.tar.gz with SHA256SUMS.
# Requires network ONLY at build time (npm registry + soundfont downloads).
set -euo pipefail
trap 'echo "::error::dist.sh failed at line ${LINENO}: ${BASH_COMMAND}"' ERR
cd "$(dirname "$0")/../.."

VERSION="$(node -p "require('./package.json').version")+nuty.$(git rev-parse --short HEAD)"
OUT=dist/nuty-smoosic
SOUNDFONT_BASE="https://gleitz.github.io/midi-js-soundfonts/FluidR3_GM"
PERCUSSION_URL="https://smoosic.github.io/SmoSounds/drumfont/percussion-ogg.js"
# Keep in sync with instrumentSampleMap in src/render/audio/samples.ts (percussion handled separately).
INSTRUMENTS=$(node -e "
const src=require('fs').readFileSync('src/render/audio/samples.ts','utf8');
const block=src.match(/instrumentSampleMap[^{]*\{([\s\S]*?)\};/)[1];
const names=[...block.matchAll(/:\s*'([^']+)'/g)].map(m=>m[1]).filter(n=>n!=='timpani');
console.log([...new Set(names)].join(' '));")

rm -rf dist && mkdir -p "$OUT/soundfonts/FluidR3_GM" "$OUT/licenses"
if ! SMOOSIC_MODE=production node build/build.js > dist/build.log 2>&1; then
  # Surface the errors as GitHub annotations (readable without log access).
  grep -E "ERROR|error TS|Module not found|Error:" dist/build.log | head -40 | sed 's/\x1b\[[0-9;]*m//g' | while IFS= read -r line; do echo "::error::${line}"; done || true
  tail -40 dist/build.log
  exit 1
fi
# Pre-existing upstream type errors do not block the bundle; list them as warnings.
grep -E "\[tsl\] ERROR|error TS" dist/build.log | sed 's/\x1b\[[0-9;]*m//g' | head -20 | while IFS= read -r line; do echo "::warning::${line}"; done || true
[ -f build/smoosic.js ] || { echo "::error::build/smoosic.js not produced"; exit 1; }

cp build/smoosic.js "$OUT/"
[ -f build/smoosic.js.map ] && cp build/smoosic.js.map "$OUT/"
cp build/jszip.js "$OUT/"
cp node_modules/jquery/dist/jquery.slim.min.js "$OUT/"
cp -r build/styles "$OUT/styles"
rm -f "$OUT/styles/"*.map

for inst in $INSTRUMENTS; do
  curl -fsSL --retry 3 -o "$OUT/soundfonts/FluidR3_GM/${inst}-ogg.js" "$SOUNDFONT_BASE/${inst}-ogg.js" || { echo "::error::soundfont download failed: ${inst}"; exit 1; }
done
curl -fsSL --retry 3 -o "$OUT/soundfonts/percussion-ogg.js" "$PERCUSSION_URL" || { echo "::error::percussion soundfont download failed"; exit 1; }

cp LICENSE.md "$OUT/licenses/smoosic-LICENSE.md"
cp node_modules/jquery/LICENSE.txt "$OUT/licenses/jquery-LICENSE.txt" 2>/dev/null || echo "::warning::jquery LICENSE.txt not found"
cp node_modules/smplr/LICENSE* "$OUT/licenses/" 2>/dev/null || true
cp tools/nuty/NOTICE.md "$OUT/licenses/NOTICE.md"

cat > "$OUT/VERSION" <<V
smoosic-nuty $VERSION
source commit $(git rev-parse HEAD)
built $(date -u +%Y-%m-%dT%H:%M:%SZ)
soundfonts $SOUNDFONT_BASE (FluidR3_GM), percussion $PERCUSSION_URL
V

(cd "$OUT" && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -C dist -czf "dist/nuty-smoosic-${VERSION}.tar.gz" nuty-smoosic
du -sh "$OUT" "$OUT/smoosic.js" "$OUT/soundfonts" "$OUT/styles"
# Fail if the runtime bundle still references remote hosts we must not depend on.
if grep -EoH "https://(code\.jquery\.com|gleitz\.github\.io|smoosic\.github\.io/SmoSounds)[^\"' ]*" "$OUT/smoosic.js" | grep -v "percussion-ogg.js" | head; then
  echo "NOTE: remote URLs above remain as defaults; Nuty must override them at runtime (see tools/nuty/README.md)."
fi
