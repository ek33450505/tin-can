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

# ---- prompt and stop events -------------------------------------------------

# run_prompt TEXT [SESSION_ID]
run_prompt() {
  local input
  input="$(jq -n --arg p "$1" --arg s "${2-sess1}" '{session_id: $s, hook_event_name: "UserPromptSubmit", prompt: $p}')"
  run "$HOOK_BASH" "$HOOK" prompt <<<"$input"
}

# run_stop CWD [SESSION_ID] [ACTIVE] [LAST_MESSAGE]
run_stop() {
  local input
  input="$(jq -n --arg c "$1" --arg s "${2-sess1}" --argjson a "${3:-false}" --arg m "${4-}" \
    '{session_id: $s, hook_event_name: "Stop", cwd: $c, stop_hook_active: $a, last_assistant_message: $m}')"
  run "$HOOK_BASH" "$HOOK" stop <<<"$input"
}

sdir() { printf '%s' "$CLAUDE_PLUGIN_DATA/tin-can-hook/${1-sess1}"; }

# git_t ARGS... -> git with a fixed identity
git_t() { git -c user.name=t -c user.email=t@example.com "$@"; }

# mk_repo NAME [dirty] -> $TEST_ROOT/NAME, one commit; "dirty" adds an untracked file
mk_repo() {
  local d="$TEST_ROOT/$1"
  mkdir -p "$d"
  git -C "$d" init -q
  echo a >"$d/a"
  git -C "$d" add a
  git_t -C "$d" commit -q -m init
  if [ "${2:-}" = dirty ]; then echo b >"$d/b"; fi
}

# mk_ahead_repo NAME -> clean repo with an upstream and one unpushed commit
mk_ahead_repo() {
  mk_repo "$1"
  git init -q --bare "$TEST_ROOT/$1.git"
  git -C "$TEST_ROOT/$1" remote add origin "$TEST_ROOT/$1.git"
  git -C "$TEST_ROOT/$1" push -q -u origin HEAD 2>/dev/null
  echo c >"$TEST_ROOT/$1/c"
  git -C "$TEST_ROOT/$1" add c
  git_t -C "$TEST_ROOT/$1" commit -q -m two
}

@test "prompt: a wrap-up phrase emits context and sets the wrapup flag" {
  run_prompt "ok let's wrap up for today"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null || return 1
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.hookEventName)" == UserPromptSubmit ]] || return 1
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.additionalContext)" == *"! tin-can '<absolute path>'"* ]] || return 1
  [ -e "$(sdir)/wrapup" ]
  rm -rf "$(sdir)"
  run_prompt "WRAP UP"
  [[ "$(echo "$output" | jq -r .hookSpecificOutput.hookEventName)" == UserPromptSubmit ]] || return 1
  [ -e "$(sdir)/wrapup" ]
}

@test "prompt: bare tin-can and identifiers like handoff_parser do not match" {
  for p in "let's work on tin-can" "refactor the handoff_parser" "rewrapup the thing" "update the handoffs list" \
    "wrap up this function" "close out the ticket" "hand off to the API" "refactor the handoff parser" "update the handoff template"; do
    run_prompt "$p"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || return 1
    [ ! -e "$(sdir)/wrapup" ] || return 1
  done
}

@test "stop: no wrapup flag and a dirty repo prints nothing" {
  mk_repo r dirty
  mkdir -p "$(sdir)"
  chmod 700 "$(sdir)"
  run_stop "$TEST_ROOT/r"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop: wrapup + dirty repo + no handoff blocks once, clears wrapup" {
  mk_repo r dirty
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e . >/dev/null || return 1
  [[ "$(echo "$output" | jq -r .decision)" == block ]] || return 1
  reason="$(echo "$output" | jq -r .reason)"
  [[ "$reason" == *"1 uncommitted file(s), 0 unpushed commit(s) in repo 'r')"* ]] || return 1
  [ -e "$(sdir)/blocked" ]
  [ ! -e "$(sdir)/wrapup" ]
}

@test "stop: a second wrap-up in the same session does not block again" {
  mk_repo r dirty
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [[ "$(echo "$output" | jq -r .decision)" == block ]] || return 1
  run_prompt "wrap up"
  [ -e "$(sdir)/wrapup" ]
  run_stop "$TEST_ROOT/r"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$(sdir)/wrapup" ]
}

@test "stop: wrapup + clean repo without upstream prints nothing" {
  mk_repo r
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop: wrapup + clean tree one commit ahead blocks" {
  mk_ahead_repo r
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [[ "$(echo "$output" | jq -r .decision)" == block ]] || return 1
  [[ "$(echo "$output" | jq -r .reason)" == *"0 uncommitted file(s), 1 unpushed commit(s)"* ]] || return 1
}

@test "stop: wrapup + handoff state prints nothing" {
  mk_repo r dirty
  echo hi >"$TIN_CAN_DIR/x-next.md"
  run_hook Write "$TIN_CAN_DIR/x-next.md"
  [ -e "$(sdir)/handoff" ]
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop: stop_hook_active prints nothing but still clears wrapup" {
  mk_repo r dirty
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r" sess1 true
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$(sdir)/wrapup" ]
  [ ! -e "$(sdir)/blocked" ]
}

@test "stop: a last message already carrying the command prints nothing" {
  mk_repo r dirty
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r" sess1 false "Done. ! tin-can '/x.md'"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop: a non-repo or nonexistent cwd prints nothing" {
  mkdir "$TEST_ROOT/plain"
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/plain"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/missing"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "prompt and stop: an invalid session_id prints nothing and writes no state" {
  mk_repo r dirty
  for sid in "../evil" "a/b" "" "$(printf 'a%.0s' $(seq 1 65))"; do
    run_prompt "wrap up" "$sid"
    [ "$status" -eq 0 ]
    run_stop "$TEST_ROOT/r" "$sid"
    [ "$status" -eq 0 ]
    [ -z "$output" ] || return 1
  done
  [ ! -e "$TEST_ROOT/data/evil" ]
  [ ! -e "$CLAUDE_PLUGIN_DATA/evil" ]
  [ -z "$(find "$CLAUDE_PLUGIN_DATA" -type f 2>/dev/null)" ]
}

@test "TIN_CAN_HOOKS=0 silences prompt and stop" {
  mk_repo r dirty
  export TIN_CAN_HOOKS=0
  run_prompt "wrap up"
  [ -z "$output" ]
  mkdir -p "$(sdir)"
  : >"$(sdir)/wrapup"
  run_stop "$TEST_ROOT/r"
  [ -z "$output" ]
}

@test "stop: without git on PATH prints nothing (and blocks with it)" {
  mk_repo r dirty
  shim="$TEST_ROOT/shim"
  mkdir "$shim"
  for t in cat jq rm mkdir dirname mktemp mv wc; do
    ln -s "$(command -v "$t")" "$shim/$t"
  done
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [[ "$(echo "$output" | jq -r .decision)" == block ]] || return 1
  rm -rf "$(sdir)"
  run_prompt "wrap up"
  input="$(jq -n --arg c "$TEST_ROOT/r" '{session_id: "sess1", cwd: $c, stop_hook_active: false}')"
  run env PATH="$shim" "$HOOK_BASH" "$HOOK" stop <<<"$input"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  [ ! -e "$(sdir)/blocked" ]
}

@test "prompt: clause-ending and high-precision wrap-up phrases match" {
  for p in "Let's wrap up" "wrap it up." "ok that's all for today" "call it a day" "done for tonight" "tin-can this" "let's close out for the day" "time to close out, thanks"; do
    rm -rf "$(sdir)"
    run_prompt "$p"
    [[ "$(echo "$output" | jq -r '.hookSpecificOutput.hookEventName')" == UserPromptSubmit ]] || return 1
    [ -e "$(sdir)/wrapup" ] || return 1
  done
}

@test "prompt: a non-matching prompt clears a stale wrapup flag" {
  mk_repo r dirty
  run_prompt "wrap up"
  [ -e "$(sdir)/wrapup" ]
  run_prompt "now fix the parser"
  [ -z "$output" ]
  [ ! -e "$(sdir)/wrapup" ]
  run_stop "$TEST_ROOT/r"
  [ -z "$output" ]
}

@test "stop: an unpushed branch in a repo with a remote blocks" {
  mk_ahead_repo r
  git -C "$TEST_ROOT/r" checkout -q -b feature
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [[ "$(echo "$output" | jq -r .decision)" == block ]] || return 1
  [[ "$(echo "$output" | jq -r .reason)" == *"1 unpushed commit(s)"* ]] || return 1
}

@test "stop: a local-only repo with commits and a clean tree does not block" {
  mk_repo r
  echo z >"$TEST_ROOT/r/z"
  git -C "$TEST_ROOT/r" add z
  git_t -C "$TEST_ROOT/r" commit -q -m more
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/r"
  [ -z "$output" ]
}

@test "stop: control characters in the cwd name are sanitised in the reason" {
  mk_repo $'bad\nname' dirty
  run_prompt "wrap up"
  run_stop "$TEST_ROOT/bad"$'\n'"name"
  reason="$(echo "$output" | jq -r .reason)"
  [[ "$reason" == *"in repo 'bad?name')"* ]] || return 1
}
