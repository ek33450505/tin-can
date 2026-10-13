#!/usr/bin/env bash
# Install tin-can by symlinking it into place (no copying, no sudo).
#
#   bin/tin-can     -> ${TIN_CAN_BIN_DIR:-$HOME/.local/bin}/tin-can
#   skills/tin-can  -> ${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/tin-can
#
# Usage: ./install.sh [--force] [--uninstall]
#
# Idempotent. A link that already points at this checkout is left alone.
# An existing regular file or directory at the destination is never
# overwritten. An existing symlink pointing somewhere else is refused unless
# --force is given. Uninstall removes only links that point exactly at this
# checkout's files.

set -euo pipefail
# A set CDPATH makes `cd` print to stdout and would corrupt the ROOT capture.
unset CDPATH

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
BIN_DIR="${TIN_CAN_BIN_DIR:-${HOME:-}/.local/bin}"
SKILLS_DIR="${CLAUDE_SKILLS_DIR:-${HOME:-}/.claude/skills}"

mode="install"
force=0
while [ $# -gt 0 ]; do
  case "$1" in
    --uninstall) mode="uninstall" ;;
    --force) force=1 ;;
    -h | --help)
      sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'install.sh: unknown argument: %s (try --help)\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

fail=0

# Every step checks its own status: this runs as `link_one ... || fail=1`,
# which suspends set -e inside the function.
link_one() { # link_one SRC DEST
  local src="$1" dest="$2" cur
  if [ ! -e "$src" ]; then
    printf 'error:   source missing: %s\n' "$src" >&2
    return 1
  fi
  if [ -L "$dest" ]; then
    cur="$(readlink "$dest")" || {
      printf 'error:   cannot read link %s\n' "$dest" >&2
      return 1
    }
    if [ "$cur" = "$src" ]; then
      printf 'ok:      %s already links to %s\n' "$dest" "$src"
      return 0
    fi
    if [ "$force" -ne 1 ]; then
      printf 'error:   %s is a symlink to %s, not this checkout; refusing (use --force to repoint)\n' "$dest" "$cur" >&2
      return 1
    fi
    rm -f -- "$dest" || {
      printf 'error:   cannot remove %s\n' "$dest" >&2
      return 1
    }
  elif [ -e "$dest" ]; then
    printf 'error:   %s exists and is not a symlink; refusing to overwrite\n' "$dest" >&2
    return 1
  fi
  mkdir -p -- "$(dirname -- "$dest")" || {
    printf 'error:   cannot create directory for %s\n' "$dest" >&2
    return 1
  }
  ln -s "$src" "$dest" || {
    printf 'error:   cannot link %s\n' "$dest" >&2
    return 1
  }
  if [ ! -L "$dest" ] || [ "$(readlink "$dest")" != "$src" ]; then
    printf 'error:   %s was not linked to %s as expected\n' "$dest" "$src" >&2
    return 1
  fi
  printf 'linked:  %s -> %s\n' "$dest" "$src"
}

unlink_one() { # unlink_one SRC DEST
  local src="$1" dest="$2" cur
  if [ ! -L "$dest" ]; then
    if [ -e "$dest" ]; then
      printf 'skip:    %s is not a symlink; leaving it alone\n' "$dest"
    else
      printf 'ok:      %s not present\n' "$dest"
    fi
    return 0
  fi
  cur="$(readlink "$dest")" || {
    printf 'error:   cannot read link %s\n' "$dest" >&2
    return 1
  }
  if [ "$cur" != "$src" ]; then
    printf 'skip:    %s points elsewhere (%s); leaving it alone\n' "$dest" "$cur"
    return 0
  fi
  rm -f -- "$dest" || {
    printf 'error:   cannot remove %s\n' "$dest" >&2
    return 1
  }
  if [ -L "$dest" ] || [ -e "$dest" ]; then
    printf 'error:   %s still present after removal\n' "$dest" >&2
    return 1
  fi
  printf 'removed: %s\n' "$dest"
}

if [ "$mode" = "install" ]; then
  link_one "$ROOT/bin/tin-can" "$BIN_DIR/tin-can" || fail=1
  link_one "$ROOT/skills/tin-can" "$SKILLS_DIR/tin-can" || fail=1
  case ":${PATH:-}:" in
    *":$BIN_DIR:"*) ;;
    *) printf 'note:    %s is not on PATH\n' "$BIN_DIR" ;;
  esac
else
  unlink_one "$ROOT/bin/tin-can" "$BIN_DIR/tin-can" || fail=1
  unlink_one "$ROOT/skills/tin-can" "$SKILLS_DIR/tin-can" || fail=1
fi

exit "$fail"
