#!/usr/bin/env bats

load require_bash4

# Script under test. TIN_CAN_HOOK_BIN lets the mutation harness point at a mutant.
HOOK="${TIN_CAN_HOOK_BIN:-$BATS_TEST_DIRNAME/../hooks/tin-can-hook}"
HOOK_BASH="${TIN_CAN_TEST_BASH:-$BASH}"

setup() {
  require_bash4 || return 1
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  TEST_ROOT="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tin-can-hook.XXXXXX")"
  TEST_ROOT="$(cd -P "$TEST_ROOT" && pwd -P)"
  export HOME="$TEST_ROOT/home"
  export TIN_CAN_DIR="$TEST_ROOT/resume"
  export CLAUDE_PLUGIN_DATA="$TEST_ROOT/data/plug"
  mkdir -p "$HOME" "$TIN_CAN_DIR" "$CLAUDE_PLUGIN_DATA"
  chmod 755 "$TIN_CAN_DIR"
  unset TIN_CAN_HOOKS
}

teardown() {
  case "${TEST_ROOT:-}" in
    */tin-can-hook.*) rm -rf "$TEST_ROOT" ;;
    *) echo "teardown: refusing to rm: ${TEST_ROOT:-}" >&2 ;;
  esac
}

# mk_input TOOL PATH [SESSION_ID] -> hook JSON on stdout
mk_input() {
  jq -n --arg t "$1" --arg p "$2" --arg s "${3-sess1}" \
    '{session_id: $s, hook_event_name: "PostToolUse", tool_name: $t, tool_input: {file_path: $p}}'
}

# run_hook TOOL PATH [SESSION_ID]
run_hook() {
  local input
  input="$(mk_input "$@")"
  run "$HOOK_BASH" "$HOOK" post-write <<<"$input"
}

@test "Write to a handoff: message, context and state" {
  f="$TIN_CAN_DIR/2026-01-01-x-next.md"
  echo hi >"$f"
  run_hook Write "$f"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null || return 1
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$f'"* ]] || return 1
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.hookEventName)" == PostToolUse ]] || return 1
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.additionalContext)" == *"! tin-can '$f'"* ]] || return 1
  [[ "$(cat "$CLAUDE_PLUGIN_DATA/tin-can-hook/sess1/handoff")" == "$f" ]] || return 1
}

@test "Edit and MultiEdit are handled, Read is not" {
  f="$TIN_CAN_DIR/2026-01-01-x-next.md"
  echo hi >"$f"
  for t in Edit MultiEdit; do
    run_hook "$t" "$f"
    [ "$status" -eq 0 ]
    [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$f'"* ]] || return 1
  done
  run_hook Read "$f"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "files outside the handoff dir or in a nested subdir are ignored" {
  mkdir -p "$TEST_ROOT/other" "$TIN_CAN_DIR/sub"
  echo hi >"$TEST_ROOT/other/x.md"
  echo hi >"$TIN_CAN_DIR/sub/x.md"
  run_hook Write "$TEST_ROOT/other/x.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_hook Write "$TIN_CAN_DIR/sub/x.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "names that --latest skips are ignored" {
  for n in _draft.md superseded-x.md x-auto.md notes.txt; do
    echo hi >"$TIN_CAN_DIR/$n"
    run_hook Write "$TIN_CAN_DIR/$n"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || return 1
  done
}

@test "names tin-can refuses (RLM, newline) are ignored" {
  rlm=$'a\xe2\x80\x8fb.md'
  nl=$'a\nb.md'
  for n in "$rlm" "$nl"; do
    echo hi >"$TIN_CAN_DIR/$n"
    run_hook Write "$TIN_CAN_DIR/$n"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || return 1
  done
}

@test "a path with a single quote round-trips through the command" {
  f="$TIN_CAN_DIR/it's-handoff.md"
  echo hi >"$f"
  run_hook Write "$f"
  [ "$status" -eq 0 ]
  msg="$(echo "$output" | jq -r .systemMessage)"
  args="${msg#*Launch it with:  ! tin-can }"
  got="$(sh -c "set -- $args; printf '%s' \"\$1\"")"
  [[ "$got" == "$f" ]] || return 1
}

@test "malformed stdin, empty stdin and TIN_CAN_HOOKS=0 are silent" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  run "$HOOK_BASH" "$HOOK" post-write <<<'{not json'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run "$HOOK_BASH" "$HOOK" post-write </dev/null
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  input="$(mk_input Write "$f")"
  TIN_CAN_HOOKS=0 run "$HOOK_BASH" "$HOOK" post-write <<<"$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "unknown event is silent" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  input="$(mk_input Write "$f")"
  run "$HOOK_BASH" "$HOOK" bogus <<<"$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "jq absent is silent" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  input="$(mk_input Write "$f")"
  mkdir -p "$TEST_ROOT/nojq"
  for c in cat dirname readlink mktemp mv rm mkdir printf; do
    p="$(command -v "$c")" || continue
    ln -s "$p" "$TEST_ROOT/nojq/$c"
  done
  PATH="$TEST_ROOT/nojq" run "$HOOK_BASH" "$HOOK" post-write <<<"$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "hostile session_id: message printed, no state outside the state root" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  long="$(printf 'a%.0s' $(seq 1 65))"
  for sid in '../../evil' "$long"; do
    run_hook Write "$f" "$sid"
    [ "$status" -eq 0 ]
    [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$f'"* ]] || return 1
  done
  [ ! -e "$TEST_ROOT/evil" ]
  [ -z "$(find "$TEST_ROOT" -name '*evil*')" ]
  [ ! -e "$CLAUDE_PLUGIN_DATA/tin-can-hook/$long" ]
}

@test "symlinked state dir: message printed, nothing written through it" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  mkdir -p "$TEST_ROOT/elsewhere" "$CLAUDE_PLUGIN_DATA/tin-can-hook"
  ln -s "$TEST_ROOT/elsewhere" "$CLAUDE_PLUGIN_DATA/tin-can-hook/sess1"
  run_hook Write "$f"
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$f'"* ]] || return 1
  [ -z "$(ls -A "$TEST_ROOT/elsewhere")" ]
}

@test "symlinked tin-can-hook dir: message printed, nothing written through it" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  mkdir -p "$TEST_ROOT/elsewhere"
  ln -s "$TEST_ROOT/elsewhere" "$CLAUDE_PLUGIN_DATA/tin-can-hook"
  run_hook Write "$f"
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$f'"* ]] || return 1
  [ -z "$(ls -A "$TEST_ROOT/elsewhere")" ]
}

@test "state dir is private (mode 700)" {
  f="$TIN_CAN_DIR/x.md"
  echo hi >"$f"
  run_hook Write "$f"
  [ "$status" -eq 0 ]
  [ -n "$(find "$CLAUDE_PLUGIN_DATA/tin-can-hook/sess1" -maxdepth 0 -perm 700)" ]
}

@test "a symlinked handoff dir is recognized and the path is canonical" {
  echo hi >"$TIN_CAN_DIR/x.md"
  ln -s "$TIN_CAN_DIR" "$TEST_ROOT/link"
  for p in "$TEST_ROOT/resume/x.md" "$TEST_ROOT/link/x.md"; do
    TIN_CAN_DIR="$TEST_ROOT/link" run_hook Write "$p"
    [ "$status" -eq 0 ]
    [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$TEST_ROOT/resume/x.md'" ]] || return 1
  done
}

@test "a symlink .md pointing outside the handoff dir is ignored" {
  echo secret >"$TEST_ROOT/secret.md"
  ln -s "$TEST_ROOT/secret.md" "$TIN_CAN_DIR/link.md"
  run_hook Write "$TIN_CAN_DIR/link.md"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "a .. path into the handoff dir yields the canonical path" {
  echo hi >"$TIN_CAN_DIR/ok.md"
  run_hook Write "$TIN_CAN_DIR/../resume/ok.md"
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$TIN_CAN_DIR/ok.md'" ]] || return 1
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.additionalContext)" == *"written to $TIN_CAN_DIR/ok.md. "* ]] || return 1
  [[ "$(cat "$CLAUDE_PLUGIN_DATA/tin-can-hook/sess1/handoff")" == "$TIN_CAN_DIR/ok.md" ]] || return 1
}

@test "a hook cwd with a control character does not drop the message" {
  echo hi >"$TIN_CAN_DIR/ok.md"
  mkdir "$TEST_ROOT/tab"$'\t'"dir"
  cd "$TEST_ROOT/tab"$'\t'"dir"
  run_hook Write "$TIN_CAN_DIR/ok.md"
  [ "$status" -eq 0 ]
  [[ "$(echo "$output" | jq -r .systemMessage)" == *"! tin-can '$TIN_CAN_DIR/ok.md'" ]] || return 1
}

@test "HOME and TIN_CAN_DIR unset: silent, exit 0, empty stderr" {
  input="$(mk_input Write "$TEST_ROOT/x.md")"
  env -u HOME -u TIN_CAN_DIR "$HOOK_BASH" "$HOOK" post-write <<<"$input" >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"
  rc=$?
  [ "$rc" -eq 0 ]
  [ ! -s "$TEST_ROOT/out" ]
  [ ! -s "$TEST_ROOT/err" ]
}
