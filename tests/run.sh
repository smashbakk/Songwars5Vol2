#!/usr/bin/env bash
# Property of LiveLayer Technology LLC.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
godot_bin="${GODOT_BIN:-godot4}"
mkdir -p work
"$godot_bin" --headless --editor --path "$project_dir" --log-file "$project_dir/work/import.log" --import
"$godot_bin" --headless --path "$project_dir" --log-file "$project_dir/work/tests.log" --script tests/run_tests.gd
"$godot_bin" --headless --path "$project_dir" --log-file "$project_dir/work/ui.log" --script tests/ui_smoke.gd -- --save-path=res://work/ui_save.json
"$godot_bin" --headless --path "$project_dir" --log-file "$project_dir/work/startup.log" --quit-after 10 -- --save-path=res://work/startup_save.json
if grep -Eq 'SCRIPT ERROR|Invalid polygon' work/import.log work/tests.log work/ui.log work/startup.log; then
  echo "Godot reported a script or rendering error."
  exit 1
fi
echo "All simulation, progression, UI, and startup checks passed."
