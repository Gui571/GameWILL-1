#!/usr/bin/env bash
# Build the introductory experience; the previous campaign packages are preserved.
set -euo pipefail
PROJECT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
GODOT_BIN="${GODOT_BIN:-godot}"
if [[ -n "${GODOT_DATA_HOME:-}" ]]; then
  export XDG_DATA_HOME="$GODOT_DATA_HOME"
elif [[ -d /workspace/.tools/godot/data/godot/export_templates/4.6.3.stable ]]; then
  export XDG_DATA_HOME=/workspace/.tools/godot/data
fi
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-/tmp/william-godot-cache}"
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-/tmp/william-godot-config}"
mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" build/intro/{windows,linux,licenses,logs}
run_godot() {
  local log_name="$1"
  shift
  "$GODOT_BIN" "$@" 2>&1 | tee "build/intro/logs/$log_name.log"
  # Godot's import process can return zero after a script parse error.
  python3 - "build/intro/logs/$log_name.log" <<'PY'
from pathlib import Path
import sys
lines = Path(sys.argv[1]).read_text(errors='replace').splitlines()
if any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) for line in lines):
    raise SystemExit('Godot reported an error; distribution stopped.')
PY
}
run_godot import --headless --path "$PROJECT_DIR" --editor --import --quit
for test_name in intro_model_test intro_terrain_test intro_flow_test; do
  if [[ ! -f "tests/$test_name.gd" ]]; then
    echo "Missing required introductory test: tests/$test_name.gd" >&2
    exit 1
  fi
  INTRO_TEST_DATA="$(mktemp -d /tmp/william-intro-test.XXXXXX)"
  XDG_DATA_HOME="$INTRO_TEST_DATA" run_godot "$test_name" \
    --headless --audio-driver Dummy --path "$PROJECT_DIR" --script "tests/$test_name.gd"
done
run_godot export_windows --headless --path "$PROJECT_DIR" --export-release Windows \
  build/intro/windows/William-Limiar-de-Aurora.exe
run_godot export_linux --headless --path "$PROJECT_DIR" --export-release Linux \
  build/intro/linux/William-Limiar-de-Aurora.x86_64
chmod +x build/intro/linux/William-Limiar-de-Aurora.x86_64
for license_file in LICENSE.txt COPYRIGHT.txt; do
  if [[ -f "build/licenses/GODOT-$license_file" ]]; then
    cp "build/licenses/GODOT-$license_file" "build/intro/licenses/GODOT-$license_file"
  else
    curl --fail --location --silent --show-error --retry 2 \
      "https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/$license_file" \
      -o "build/intro/licenses/GODOT-$license_file"
  fi
done
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
import hashlib
import shutil

root = Path('.')
build = root / 'build' / 'intro'
# Preserve paths to avoid overwriting licenses with the same filename.
license_sources = [Path('assets/FONT-LICENSE.txt')]
for source_root in (Path('tools/creature_generator'), Path('intro/creatures'), Path('docs/references')):
    if source_root.exists():
        license_sources.extend(path for path in source_root.rglob('*')
            if path.is_file() and any(term in path.name.upper() for term in ('LICENSE', 'COPYRIGHT', 'THIRD_PARTY', 'NOTICE', 'ORIGIN', 'UPSTREAM'))
            and not any(part in {'bin', 'obj', '.git', '.dotnet', '.tools'} for part in path.parts))
if not any('creature' in path.as_posix().lower() and 'LICENSE' in path.name.upper() for path in license_sources):
    raise SystemExit('Required procedural creature license missing; distribution stopped.')
for platform in ('windows', 'linux'):
    destination = build / platform
    shutil.copyfile('README.md', destination/'LEIA-ME.md')
    shutil.copyfile('docs/INTRODUCAO.md', destination/'INTRODUCAO.md')
    license_dir = destination/'LICENSES'
    license_dir.mkdir(exist_ok=True)
    for path in sorted((build/'licenses').glob('*.txt')):
        shutil.copyfile(path, license_dir/path.name)
    for path in sorted(set(license_sources)):
        target = license_dir/path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path,target)

outputs = []
for platform,suffix in [('windows','Windows-x64'),('linux','Linux-x64')]:
    archive = build / f'William-Limiar-de-Aurora-{suffix}.zip'
    with ZipFile(archive,'w',ZIP_DEFLATED,compresslevel=9) as bundle:
        for source in sorted((build/platform).rglob('*')):
            if source.is_file():
                bundle.write(source,arcname=f'William-Limiar-de-Aurora/{source.relative_to(build/platform).as_posix()}')
    outputs.append(archive)
source_archive = build/'William-Limiar-de-Aurora-Projeto.zip'
excluded = {'.git','.godot','build','downloads','bin','obj','.tools','.dotnet','.nuget','__pycache__'}
with ZipFile(source_archive,'w',ZIP_DEFLATED,compresslevel=9) as bundle:
    for source in sorted(root.rglob('*')):
        if source.is_file() and not any(part in excluded for part in source.parts):
            bundle.write(source,arcname=f'William-Projeto/{source.as_posix()}')
outputs += [source_archive,build/'windows/William-Limiar-de-Aurora.exe',build/'linux/William-Limiar-de-Aurora.x86_64']
for archive in outputs[:3]:
    with ZipFile(archive) as bundle:
        if bundle.testzip() is not None:
            raise SystemExit(f'Archive integrity failed: {archive}')
checksums = [f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(build)}' for path in outputs]
(build/'SHA256SUMS.txt').write_text('\n'.join(checksums)+'\n')
print('\n'.join(str(path) for path in outputs))
PY
