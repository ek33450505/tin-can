# shellcheck shell=bash
# shellcheck disable=SC2034  # variables here are consumed by the .bats files that load this
#
# Shared helpers for tin-can BATS tests. Source with: load helpers
#
# Every test gets an isolated temp HOME and a PATH made only of STUB
# cmux/tmux/claude/codex scripts plus symlinks to the few coreutils the script
# needs, so no real terminal or agent is ever touched.

# Script under test. TIN_CAN_BIN lets the mutation harness point at a mutant.
TC="${TIN_CAN_BIN:-$BATS_TEST_DIRNAME/../bin/tin-can}"
# Interpreter. On macOS CI set TIN_CAN_TEST_BASH=/bin/bash to run under 3.2.
TC_BASH="${TIN_CAN_TEST_BASH:-$BASH}"

# Each stub records "PWD NUL arg NUL arg ..." into $STUB_CALLS/<name>.<seq>,
# where seq is a global counter, so the most recent call is well defined.
make_stubs() {
  local pair name upper
  for pair in cmux:CMUX tmux:TMUX claude:CLAUDE codex:CODEX; do
    name="${pair%%:*}"
    upper="${pair##*:}"
    printf '%s\n' \
      '#!/bin/sh' \
      "mkdir -p \"\$STUB_CALLS\"" \
      "n=0; if [ -f \"\$STUB_CALLS/.seq\" ]; then read n < \"\$STUB_CALLS/.seq\"; fi" \
      "n=\$((n + 1)); echo \"\$n\" > \"\$STUB_CALLS/.seq\"" \
      "f=\"\$STUB_CALLS/$name.\$n\"" \
      "{ printf '%s\\000' \"\$PWD\"; for a in \"\$@\"; do printf '%s\\000' \"\$a\"; done; } > \"\$f\"" \
      "rc=\"\${STUB_EXIT_$upper:-0}\"" \
      "if [ \"\$rc\" != 0 ]; then echo \"stub $name failing on request\" >&2; fi" \
      "exit \"\$rc\"" >"$STUBS/$name"
    chmod +x "$STUBS/$name"
  done
}

setup() {
  TEST_ROOT="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tin-can.XXXXXX")"
  TEST_ROOT="$(cd -P "$TEST_ROOT" && pwd -P)"
  export HOME="$TEST_ROOT/home"
  STUBS="$TEST_ROOT/stubs"
  TOOLS="$TEST_ROOT/tools"
  STUB_CALLS="$TEST_ROOT/calls"
  export STUB_CALLS
  RESUME="$HOME/.claude/resume-prompts"
  WORK="$TEST_ROOT/work/myrepo"
  mkdir -p "$HOME" "$STUBS" "$TOOLS" "$RESUME" "$WORK"
  chmod 755 "$HOME" "$RESUME"

  local t p
  for t in dirname basename readlink ls cat mkdir find; do
    p="$(command -v "$t")"
    ln -s "$p" "$TOOLS/$t"
  done
  make_stubs
  TC_PATH="$STUBS:$TOOLS"

  unset CMUX_WORKSPACE_ID TMUX TIN_CAN_AGENT TIN_CAN_TERM TIN_CAN_DIR
  unset STUB_EXIT_CMUX STUB_EXIT_TMUX STUB_EXIT_CLAUDE STUB_EXIT_CODEX

  HF="$TEST_ROOT/handoff.md"
  printf '# handoff\n\n## KICKOFF\nDo the thing.\n' >"$HF"
}

teardown() {
  case "${TEST_ROOT:-}" in
    "${BATS_TMPDIR:-/tmp}"/tin-can.* | /tmp/tin-can.* | /var/folders/*/tin-can.* | /private/var/folders/*/tin-can.*)
      chmod -R u+rwX "$TEST_ROOT" 2>/dev/null || true
      rm -rf "$TEST_ROOT"
      ;;
    *) echo "teardown: refusing to rm outside tmpdir: ${TEST_ROOT:-}" >&2 ;;
  esac
}

# run_tc ARGS...  -> bats `run` of the script with the hermetic PATH.
run_tc() {
  run env "PATH=$TC_PATH" "$TC_BASH" "$TC" "$@"
}

# tc_cmd ARGS... -> prints the launch command (print mode, stderr dropped).
tc_cmd() {
  env "PATH=$TC_PATH" "$TC_BASH" "$TC" --term print "$@" 2>/dev/null
}

# load_call NAME -> CALL_PWD, ARGS (array) and CALL_COUNT for the most recent
# (highest sequence number) call of stub NAME.
load_call() {
  local name="$1" f a seq best=0 bestf="" first=1
  CALL_PWD=""
  ARGS=()
  CALL_COUNT=0
  for f in "$STUB_CALLS/$name".*; do
    [ -f "$f" ] || continue
    CALL_COUNT=$((CALL_COUNT + 1))
    seq="${f##*.}"
    if [ "$seq" -gt "$best" ]; then
      best="$seq"
      bestf="$f"
    fi
  done
  [ -n "$bestf" ] || return 0
  while IFS= read -r -d '' a; do
    if [ "$first" -eq 1 ]; then
      CALL_PWD="$a"
      first=0
    else
      ARGS+=("$a")
    fi
  done <"$bestf"
}

call_count() {
  local n=0 f
  for f in "$STUB_CALLS/$1".*; do
    if [ -f "$f" ]; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

total_calls() {
  local n=0 f
  for f in "$STUB_CALLS"/*; do
    if [ -f "$f" ]; then n=$((n + 1)); fi
  done
  printf '%s' "$n"
}

# set_mtime FILE YYYYMMDDhhmm
set_mtime() {
  touch -t "$2" "$1"
}
