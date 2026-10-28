#!/usr/bin/env bash
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
GODOT_BIN="${GODOT_BIN:-godot}"
# The cloud image keeps verified export templates outside the source checkout.
# Local development can use templates installed normally through the editor.
if [[ -n "${GODOT_DATA_HOME:-}" ]]; then
  export XDG_DATA_HOME="$GODOT_DATA_HOME"
elif [[ -d /workspace/.tools/godot/data/godot/export_templates/4.6.3.stable ]]; then
  export XDG_DATA_HOME=/workspace/.tools/godot/data
fi
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/william-godot-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/william-godot-config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" build/windows build/linux build/licenses
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --editor --import --quit
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --script tests/combat_test.gd
if [[ -f tests/flow_test.gd ]]; then
  FLOW_TEST_DATA="$(mktemp -d /tmp/william-flow-test.XXXXXX)"
  XDG_DATA_HOME="$FLOW_TEST_DATA" "$GODOT_BIN" --headless --audio-driver Dummy --path "$PROJECT_DIR" --script tests/flow_test.gd
else
  echo "Flow test not present; not executed."
fi
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release Windows build/windows/William.exe
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release Linux build/linux/William.x86_64
chmod +x build/linux/William.x86_64
for license_file in LICENSE.txt COPYRIGHT.txt; do
  curl --fail --location --silent --show-error --retry 2 \
    "https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/$license_file" \
    -o "build/licenses/GODOT-$license_file"
done
for platform in windows linux; do
  cp README.md "build/$platform/LEIA-ME.md"
  cp build/licenses/GODOT-*.txt "build/$platform/"
  if [[ -f assets/FONT-LICENSE.txt ]]; then
    cp assets/FONT-LICENSE.txt "build/$platform/FONT-LICENSE.txt"
  fi
done
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
build = Path('build')
for platform, suffix in [('windows', 'Windows-x64'), ('linux', 'Linux-x64')]:
    archive = build / f'William-Ecos-do-Ultimo-Trem-{suffix}.zip'
    with ZipFile(archive, 'w', ZIP_DEFLATED, compresslevel=9) as bundle:
        for source in sorted((build / platform).iterdir()):
            if source.is_file():
                bundle.write(source, arcname=f'William/{source.name}')
source_archive = build / 'William-Ecos-do-Ultimo-Trem-Projeto.zip'
with ZipFile(source_archive, 'w', ZIP_DEFLATED, compresslevel=9) as bundle:
    for source in sorted(Path('.').rglob('*')):
        if source.is_file() and not any(part in {'.git', '.godot', 'build'} for part in source.parts):
            bundle.write(source, arcname=f'William-Projeto/{source.as_posix()}')
outputs = sorted(build.glob('*.zip')) + [build/'windows/William.exe', build/'linux/William.x86_64']
lines = [f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(build)}' for path in outputs]
(build / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n')
print('\n'.join(str(path) for path in outputs))
PY
