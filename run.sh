#!/usr/bin/env bash
#
# run.sh — Launch the MM3-style blobber game.
#
# Plays the main scene (res://presentation/world/main.tscn) in a window.
# Any extra arguments are passed straight through to Godot.
#
#   ./run.sh                       # play the game (windowed)
#   ./run.sh --headless            # run without a window (boot smoke check)
#   ./run.sh -e                    # open the project in the Godot editor
#   GODOT=/path/to/godot ./run.sh  # use a specific Godot binary
#
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v "$GODOT" >/dev/null 2>&1; then
  echo "Godot not found (tried: '$GODOT')." >&2
  echo "Install Godot 4 and put it on PATH, or run: GODOT=/path/to/godot ./run.sh" >&2
  exit 1
fi

exec "$GODOT" --path "$PROJECT_DIR" "$@"
