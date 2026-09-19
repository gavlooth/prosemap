#!/bin/sh
set -eu

SELF=$(readlink -f "$0")
ROOT=$(dirname "$SELF")
SOURCE="$ROOT/bin/prosemap"
MAIN="$ROOT/prosemap/main.bend"
CORE_DIR="$ROOT/.prosemap/native"
CORE="$CORE_DIR/prosemap-core"
BIN_DIR="$HOME/.local/bin"
FORCE=false

usage() {
  cat <<'EOF'
Usage: ./install.sh [--bin-dir DIR] [--force]

Installs the Prosemap command as a symlink in ~/.local/bin by default.
Use --bin-dir to select another user-writable directory. Existing unrelated
files are never replaced unless --force is supplied.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --bin-dir)
      if [ "$#" -lt 2 ]; then
        printf '%s\n' 'install.sh: --bin-dir requires a directory' >&2
        exit 2
      fi
      BIN_DIR=$2
      shift 2
      ;;
    --force)
      FORCE=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'install.sh: unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ ! -x "$SOURCE" ]; then
  printf 'install.sh: launcher is missing or not executable: %s\n' "$SOURCE" >&2
  exit 1
fi

if command -v bend >/dev/null 2>&1; then
  BEND=$(command -v bend)
elif [ -x "$HOME/.bend/bin/bend" ]; then
  BEND="$HOME/.bend/bin/bend"
else
  printf '%s\n' 'install.sh: Bend is not installed or not on PATH' >&2
  exit 127
fi

mkdir -p "$CORE_DIR"
CORE_TMP="$CORE.tmp.$$"
trap 'rm -f "$CORE_TMP"' EXIT HUP INT TERM
printf '%s\n' 'Building native Prosemap core...'
"$BEND" "$MAIN" -o "$CORE_TMP"
chmod +x "$CORE_TMP"
mv -f "$CORE_TMP" "$CORE"
trap - EXIT HUP INT TERM

mkdir -p "$BIN_DIR"
BIN_DIR=$(readlink -f "$BIN_DIR")
TARGET="$BIN_DIR/prosemap"

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  CURRENT=$(readlink -f "$TARGET" 2>/dev/null || true)
  if [ "$CURRENT" = "$SOURCE" ]; then
    "$TARGET" --help >/dev/null
    printf 'Prosemap is installed and its native core was rebuilt: %s -> %s\n' "$TARGET" "$SOURCE"
    exit 0
  fi
  if [ "$FORCE" != true ]; then
    printf 'install.sh: refusing to replace existing path: %s\n' "$TARGET" >&2
    printf '%s\n' 'Re-run with --force only if replacing it is intentional.' >&2
    exit 1
  fi
fi

TMP="$TARGET.tmp.$$"
trap 'rm -f "$TMP"' EXIT HUP INT TERM
ln -s "$SOURCE" "$TMP"
mv -f "$TMP" "$TARGET"
trap - EXIT HUP INT TERM

"$TARGET" --help >/dev/null
printf 'Installed Prosemap: %s -> %s\n' "$TARGET" "$SOURCE"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *)
    printf 'Add this directory to PATH to run `prosemap` directly:\n  %s\n' "$BIN_DIR"
    ;;
esac
