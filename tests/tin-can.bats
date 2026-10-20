#!/usr/bin/env bats

load helpers

# --- terminal auto-detection -------------------------------------------------

@test "auto: CMUX_WORKSPACE_ID + cmux on PATH selects cmux" {
  export CMUX_WORKSPACE_ID=ws-1
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count cmux)" -eq 1 ]
  [ "$(call_count tmux)" -eq 0 ]
  load_call cmux
  [ "${ARGS[0]}" = "new-surface" ]
}

@test "auto: TMUX set + tmux on PATH selects tmux" {
  export TMUX=/tmp/tmux-1/default,1,0
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count tmux)" -eq 1 ]
  [ "$(call_count cmux)" -eq 0 ]
  load_call tmux
  [ "${ARGS[0]}" = "new-window" ]
}

@test "auto: no cmux/tmux environment falls back to print" {
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"paste this into a new terminal tab"* ]]
  [[ "$output" == *"exec 'claude'"* ]]
}

@test "auto: cmux wins when both CMUX_WORKSPACE_ID and TMUX are set" {
  export CMUX_WORKSPACE_ID=ws-1 TMUX=/tmp/tmux-1/default,1,0
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count cmux)" -eq 1 ]
  [ "$(call_count tmux)" -eq 0 ]
}

@test "auto: CMUX_WORKSPACE_ID set but cmux not on PATH falls through to tmux" {
  export CMUX_WORKSPACE_ID=ws-1 TMUX=/tmp/tmux-1/default,1,0
  rm "$STUBS/cmux"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count tmux)" -eq 1 ]
}

@test "auto: CMUX_WORKSPACE_ID set but cmux not on PATH and no TMUX prints" {
  export CMUX_WORKSPACE_ID=ws-1
  rm "$STUBS/cmux"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"exec 'claude'"* ]]
}

@test "auto: TMUX set but tmux not on PATH prints" {
  export TMUX=/tmp/tmux-1/default,1,0
  rm "$STUBS/tmux"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"exec 'claude'"* ]]
}

@test "term: TIN_CAN_TERM env overrides auto-detection" {
  export CMUX_WORKSPACE_ID=ws-1 TIN_CAN_TERM=print
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
}

@test "term: explicit --term tmux beats cmux environment" {
  export CMUX_WORKSPACE_ID=ws-1
  run_tc --term tmux --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count tmux)" -eq 1 ]
  [ "$(call_count cmux)" -eq 0 ]
}

@test "term: explicit --term print launches nothing" {
  export CMUX_WORKSPACE_ID=ws-1
  run_tc --term print --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
}

@test "term: unknown terminal exits 2" {
  run_tc --term screen --cwd "$WORK" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown terminal"* ]]
}

@test "where: invalid value exits 2" {
  run_tc --where pane --cwd "$WORK" "$HF"
  [ "$status" -eq 2 ]
}

@test "where: --where with --term print warns that it is ignored" {
  run_tc --term print --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--where is ignored with --term print"* ]]
}

# --- terminal adapter argv ---------------------------------------------------

@test "cmux tab: new-surface --type terminal --command CMD --focus true" {
  run_tc --term cmux --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call cmux
  [ "${#ARGS[@]}" -eq 7 ]
  [ "${ARGS[0]}" = "new-surface" ]
  [ "${ARGS[1]}" = "--type" ]
  [ "${ARGS[2]}" = "terminal" ]
  [ "${ARGS[3]}" = "--command" ]
  [ "${ARGS[4]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [ "${ARGS[5]}" = "--focus" ]
  [ "${ARGS[6]}" = "true" ]
}

@test "cmux window: new-workspace --name 'REPO (tin-can)' --cwd --command --focus true" {
  run_tc --term cmux --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call cmux
  [ "${#ARGS[@]}" -eq 9 ]
  [ "${ARGS[0]}" = "new-workspace" ]
  [ "${ARGS[1]}" = "--name" ]
  [ "${ARGS[2]}" = "myrepo (tin-can)" ]
  [ "${ARGS[3]}" = "--cwd" ]
  [ "${ARGS[4]}" = "$WORK" ]
  [ "${ARGS[5]}" = "--command" ]
  [ "${ARGS[6]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [ "${ARGS[7]}" = "--focus" ]
  [ "${ARGS[8]}" = "true" ]
}

@test "tmux tab: new-window CMD (no -c; the command cds itself)" {
  run_tc --term tmux --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call tmux
  [ "${#ARGS[@]}" -eq 2 ]
  [ "${ARGS[0]}" = "new-window" ]
  [ "${ARGS[1]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [[ "${ARGS[1]}" == "cd '$WORK' && exec "* ]]
}

@test "tmux window: detached new-session with a name, and attach hint" {
  run_tc --term tmux --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call tmux
  [ "${#ARGS[@]}" -eq 5 ]
  [ "${ARGS[0]}" = "new-session" ]
  [ "${ARGS[1]}" = "-d" ]
  [ "${ARGS[2]}" = "-s" ]
  [[ "${ARGS[3]}" == tin-can-* ]]
  [ "${ARGS[4]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [[ "$output" == *"launched claude in a new DETACHED tmux session; attach with: tmux attach -t ${ARGS[3]}"* ]]
  [[ "$output" != *"new tmux window"* ]]
}

@test "tmux tab: success message says a tmux window (tab), not a detached session" {
  run_tc --term tmux --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"launched claude in a new tmux window (tab)"* ]]
  [[ "$output" != *"DETACHED"* ]]
}

# --- agents ------------------------------------------------------------------

@test "agent: default is claude" {
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "agent: --agent codex" {
  run_tc --agent codex --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec 'codex' "* ]]
  [[ "$output" != *"exec 'claude'"* ]]
}

@test "agent: TIN_CAN_AGENT env selects codex" {
  export TIN_CAN_AGENT=codex
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec 'codex' "* ]]
}

@test "agent: --agent beats TIN_CAN_AGENT" {
  export TIN_CAN_AGENT=codex
  run_tc --agent claude --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "agent: unknown agent exits 2 and lists supported agents" {
  run_tc --agent gemini --cwd "$WORK" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown agent gemini"* ]]
  [[ "$output" == *"claude"* ]]
  [[ "$output" == *"codex"* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "agent: generated command starts the claude stub with the prompt" {
  CMD="$(tc_cmd --cwd "$WORK" "$HF")"
  run env "PATH=$TC_PATH" "$TC_BASH" -c "$CMD"
  [ "$status" -eq 0 ]
  load_call claude
  [ "${#ARGS[@]}" -eq 1 ]
  [ "${ARGS[0]}" = "Read the handoff file at $HF and follow its KICKOFF section." ]
  [ "$CALL_PWD" = "$WORK" ]
}

@test "agent: generated command starts the codex stub with the prompt" {
  CMD="$(tc_cmd --agent codex --cwd "$WORK" "$HF")"
  run env "PATH=$TC_PATH" "$TC_BASH" -c "$CMD"
  [ "$status" -eq 0 ]
  load_call codex
  [ "${#ARGS[@]}" -eq 1 ]
  [ "${ARGS[0]}" = "Read the handoff file at $HF and follow its KICKOFF section." ]
  [ "$(call_count claude)" -eq 0 ]
}

@test "help: lists the supported agents and terminals from one source" {
  run_tc --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: tin-can"* ]]
  [[ "$output" == *"claude | codex"* ]]
  [[ "$output" == *"--latest"* ]]
  [[ "$output" == *"cmux | tmux | zellij | wezterm | kitty | print | auto"* ]]
}

@test "latest: no file and no --latest exits 2, names --latest, launches nothing" {
  printf 'newer\n' >"$RESUME/newer.md"
  export CMUX_WORKSPACE_ID=x
  run_tc --cwd "$WORK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--latest"* ]]
  [[ "$output" != *"Read the handoff file"* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "latest: no file and no --latest with --term print prints no command" {
  printf 'newer\n' >"$RESUME/newer.md"
  run_tc --term print --cwd "$WORK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--latest"* ]]
  [[ "$output" != *"cd "* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "latest: --latest with an explicit file is rejected in either order" {
  run_tc --term print --cwd "$WORK" --latest "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
  [ "$(total_calls)" -eq 0 ]
  run_tc --term print --cwd "$WORK" "$HF" --latest
  [ "$status" -eq 2 ]
  [[ "$output" == *"mutually exclusive"* ]]
  [ "$(total_calls)" -eq 0 ]
}

# --- option parsing -------------------------------------------------------------

@test "options: a value starting with - is rejected for every value option" {
  local opt
  for opt in --dir --cwd --agent --term --where; do
    run_tc "$opt" --dry-run
    [ "$status" -eq 2 ]
    [[ "$output" == *"requires a value"* ]]
  done
}

@test "options: an empty value is rejected" {
  local opt
  for opt in --dir --cwd --agent --term --where; do
    run_tc "$opt" ""
    [ "$status" -eq 2 ]
    [[ "$output" == *"non-empty value"* ]]
  done
}

@test "options: a missing value at the end is rejected" {
  local opt
  for opt in --dir --cwd --agent --term --where; do
    run_tc "$opt"
    [ "$status" -eq 2 ]
    [[ "$output" == *"requires a value"* ]]
  done
}

@test "options: unknown option exits 2" {
  run_tc --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "options: -- ends option parsing so a dash-leading file name is a file" {
  mkdir -p "$TEST_ROOT/dd"
  printf 'x\n' >"$TEST_ROOT/dd/--weird-name.md"
  cd "$TEST_ROOT/dd"
  run_tc --cwd "$WORK" --term print -- --weird-name.md
  [ "$status" -eq 0 ]
  [[ "$output" == *"$TEST_ROOT/dd/--weird-name.md"* ]]
}

@test "options: without -- the same dash-leading name is an unknown option" {
  mkdir -p "$TEST_ROOT/dd"
  printf 'x\n' >"$TEST_ROOT/dd/--weird-name.md"
  cd "$TEST_ROOT/dd"
  run_tc --cwd "$WORK" --term print --weird-name.md
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "options: a second file argument names the unexpected argument" {
  run_tc --cwd "$WORK" --term print "$HF" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected extra argument"* ]]
}

@test "options: a second file argument after -- is also rejected" {
  run_tc --cwd "$WORK" --term print -- "$HF" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"unexpected extra argument"* ]]
}

# --- handoff resolution ------------------------------------------------------

@test "handoff: relative explicit file is canonicalised to an absolute path" {
  mkdir -p "$TEST_ROOT/rel"
  printf 'x\n' >"$TEST_ROOT/rel/h.md"
  cd "$TEST_ROOT/rel"
  CMD="$(env "PATH=$TC_PATH" "$TC_BASH" "$TC" --term print --cwd "$WORK" h.md 2>/dev/null)"
  run env "PATH=$TC_PATH" "$TC_BASH" -c "$CMD"
  [ "$status" -eq 0 ]
  load_call claude
  [ "${ARGS[0]}" = "Read the handoff file at $TEST_ROOT/rel/h.md and follow its KICKOFF section." ]
}

@test "handoff: relative path with .. segments is canonicalised" {
  mkdir -p "$TEST_ROOT/a/b"
  printf 'x\n' >"$TEST_ROOT/a/h.md"
  cd "$TEST_ROOT/a/b"
  CMD="$(env "PATH=$TC_PATH" "$TC_BASH" "$TC" --term print --cwd "$WORK" ../h.md 2>/dev/null)"
  run env "PATH=$TC_PATH" "$TC_BASH" -c "$CMD"
  [ "$status" -eq 0 ]
  load_call claude
  [ "${ARGS[0]}" = "Read the handoff file at $TEST_ROOT/a/h.md and follow its KICKOFF section." ]
}

@test "handoff: newest *.md in the search dir is used and reported on stderr" {
  printf 'old\n' >"$RESUME/old.md"
  printf 'new\n' >"$RESUME/new.md"
  set_mtime "$RESUME/old.md" 202601010000
  set_mtime "$RESUME/new.md" 202601020000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/new.md"* ]]
  [[ "$output" == *"Read the handoff file at $RESUME/new.md"* ]]
}

@test "handoff: superseded-* and _* names are excluded even when newest" {
  printf 'ok\n' >"$RESUME/real.md"
  printf 's\n' >"$RESUME/superseded-2026-newest.md"
  printf 't\n' >"$RESUME/_TEMPLATE.md"
  set_mtime "$RESUME/real.md" 202601010000
  set_mtime "$RESUME/superseded-2026-newest.md" 202601030000
  set_mtime "$RESUME/_TEMPLATE.md" 202601040000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/real.md"* ]]
}

@test "handoff: *-auto.md is excluded even when newest and repo-named" {
  printf 'n\n' >"$RESUME/2026-01-01-myrepo-next.md"
  printf 'a\n' >"$RESUME/2026-01-02-myrepo-auto.md"
  set_mtime "$RESUME/2026-01-01-myrepo-next.md" 202601010000
  set_mtime "$RESUME/2026-01-02-myrepo-auto.md" 202601020000
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/2026-01-01-myrepo-next.md"* ]]
}

@test "handoff: only *-auto.md files present exits 2" {
  printf 'a\n' >"$RESUME/2026-01-02-myrepo-auto.md"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"no handoff file found"* ]]
}

@test "handoff: near-miss auto names stay eligible" {
  local n
  for n in autopilot.md my-auto-notes.md auto.md; do
    rm -f "$RESUME"/*.md
    printf 'o\n' >"$RESUME/old.md"
    printf 'n\n' >"$RESUME/$n"
    set_mtime "$RESUME/old.md" 202601010000
    set_mtime "$RESUME/$n" 202601020000
    run_tc --latest --cwd "$TEST_ROOT" --term print
    [ "$status" -eq 0 ] || return 1
    [[ "$output" == *"tin-can: using $RESUME/$n"* ]] || return 1
  done
}

@test "handoff: explicit x-auto.md file is still accepted" {
  printf 'a\n' >"$RESUME/x-auto.md"
  run_tc "$RESUME/x-auto.md" --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
}

@test "handoff: only excluded files present exits 2" {
  printf 's\n' >"$RESUME/superseded-x.md"
  printf 't\n' >"$RESUME/_TEMPLATE.md"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"no handoff file found"* ]]
}

@test "handoff: non-markdown files are ignored" {
  printf 'x\n' >"$RESUME/notes.txt"
  printf 'y\n' >"$RESUME/real.md"
  set_mtime "$RESUME/real.md" 202601010000
  set_mtime "$RESUME/notes.txt" 202601050000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/real.md"* ]]
}

@test "handoff: a directory named x.md and a dangling symlink are skipped" {
  printf 'real\n' >"$RESUME/real.md"
  mkdir "$RESUME/newest.md"
  ln -s "$TEST_ROOT/does-not-exist" "$RESUME/dangling.md"
  set_mtime "$RESUME/real.md" 202601010000
  set_mtime "$RESUME/newest.md" 202601050000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/real.md"* ]]
}

@test "handoff: only a directory named x.md present exits 2" {
  mkdir "$RESUME/only.md"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"no handoff file found"* ]]
}

@test "handoff: file name containing the --cwd repo name is preferred over a newer file" {
  printf 'a\n' >"$RESUME/2026-10-01-myrepo-feature.md"
  printf 'b\n' >"$RESUME/2026-10-02-otherrepo-thing.md"
  set_mtime "$RESUME/2026-10-01-myrepo-feature.md" 202610010000
  set_mtime "$RESUME/2026-10-02-otherrepo-thing.md" 202610020000
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/2026-10-01-myrepo-feature.md"* ]]
}

@test "handoff: repo name matches whole words only (cast must not pick broadcast-plan)" {
  mkdir -p "$TEST_ROOT/work/cast"
  printf 'a\n' >"$RESUME/broadcast-plan.md"
  printf 'b\n' >"$RESUME/notes.md"
  set_mtime "$RESUME/broadcast-plan.md" 202610010000
  set_mtime "$RESUME/notes.md" 202610020000
  run_tc --latest --cwd "$TEST_ROOT/work/cast" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/notes.md"* ]]
}

@test "handoff: a whole-word repo match is still preferred (cast-next over newer notes)" {
  mkdir -p "$TEST_ROOT/work/cast"
  printf 'a\n' >"$RESUME/2026-10-12-cast-next.md"
  printf 'b\n' >"$RESUME/notes.md"
  set_mtime "$RESUME/2026-10-12-cast-next.md" 202610010000
  set_mtime "$RESUME/notes.md" 202610020000
  run_tc --latest --cwd "$TEST_ROOT/work/cast" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/2026-10-12-cast-next.md"* ]]
}

@test "handoff: underscore and dot count as word separators for the repo match" {
  mkdir -p "$TEST_ROOT/work/my.repo"
  printf 'a\n' >"$RESUME/x_my-repo_y.md"
  printf 'b\n' >"$RESUME/notes.md"
  set_mtime "$RESUME/x_my-repo_y.md" 202610010000
  set_mtime "$RESUME/notes.md" 202610020000
  run_tc --latest --cwd "$TEST_ROOT/work/my.repo" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/x_my-repo_y.md"* ]]
}

@test "handoff: no repo-name match falls back to newest overall" {
  printf 'a\n' >"$RESUME/2026-10-01-alpha.md"
  printf 'b\n' >"$RESUME/2026-10-02-beta.md"
  set_mtime "$RESUME/2026-10-01-alpha.md" 202610010000
  set_mtime "$RESUME/2026-10-02-beta.md" 202610020000
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/2026-10-02-beta.md"* ]]
}

@test "handoff: among several repo-name matches the newest wins" {
  printf 'a\n' >"$RESUME/myrepo-old.md"
  printf 'b\n' >"$RESUME/myrepo-new.md"
  set_mtime "$RESUME/myrepo-old.md" 202610010000
  set_mtime "$RESUME/myrepo-new.md" 202610020000
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/myrepo-new.md"* ]]
}

@test "handoff: empty search dir exits 2" {
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"no handoff file found"* ]]
}

@test "handoff: missing search dir exits 2" {
  run_tc --latest --cwd "$WORK" --term print --dir "$TEST_ROOT/nope"
  [ "$status" -eq 2 ]
  [[ "$output" == *"handoff search dir not found"* ]]
}

@test "handoff: --dir and TIN_CAN_DIR choose the search directory" {
  mkdir -p "$TEST_ROOT/other1" "$TEST_ROOT/other2"
  chmod 755 "$TEST_ROOT/other1" "$TEST_ROOT/other2"
  printf 'x\n' >"$TEST_ROOT/other1/one.md"
  printf 'x\n' >"$TEST_ROOT/other2/two.md"
  export TIN_CAN_DIR="$TEST_ROOT/other1"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $TEST_ROOT/other1/one.md"* ]]
  run_tc --latest --cwd "$TEST_ROOT" --term print --dir "$TEST_ROOT/other2"
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $TEST_ROOT/other2/two.md"* ]]
}

@test "handoff: missing explicit file exits 2" {
  run_tc --cwd "$WORK" --term print "$TEST_ROOT/does-not-exist.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not an existing regular file"* ]]
}

@test "handoff: a directory given as the handoff exits 2" {
  run_tc --cwd "$WORK" --term print "$TEST_ROOT"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not an existing regular file"* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "handoff: empty-string handoff exits 2" {
  run_tc --cwd "$WORK" --term print ""
  [ "$status" -eq 2 ]
  [[ "$output" == *"not an existing regular file"* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "handoff: unreadable file exits 2" {
  if [ "$(id -u)" -eq 0 ]; then skip "root can read anything"; fi
  printf 'x\n' >"$TEST_ROOT/secret.md"
  chmod 000 "$TEST_ROOT/secret.md"
  run_tc --cwd "$WORK" --term print "$TEST_ROOT/secret.md"
  chmod 600 "$TEST_ROOT/secret.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not readable"* ]]
}

@test "handoff: file contents never appear in the generated command" {
  printf 'SECRET-MARKER-12345 $(touch /tmp/pwned) `id`\n' >"$TEST_ROOT/c.md"
  CMD="$(tc_cmd --cwd "$WORK" "$TEST_ROOT/c.md")"
  [[ "$CMD" != *"SECRET-MARKER"* ]]
}

# --- handoff trust (auto-selection) ------------------------------------------------

@test "trust: a world-writable search dir (777) is refused for auto-selection" {
  printf 'x\n' >"$RESUME/real.md"
  chmod 777 "$RESUME"
  run_tc --latest --cwd "$WORK" --term print
  chmod 755 "$RESUME"
  [ "$status" -eq 2 ]
  [[ "$output" == *"group- or world-writable"* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "trust: a group-writable search dir (775) is refused for auto-selection" {
  printf 'x\n' >"$RESUME/real.md"
  chmod 775 "$RESUME"
  run_tc --latest --cwd "$WORK" --term print
  chmod 755 "$RESUME"
  [ "$status" -eq 2 ]
  [[ "$output" == *"group- or world-writable"* ]]
}

@test "trust: an explicit file inside a world-writable dir is still allowed" {
  printf 'x\n' >"$RESUME/real.md"
  chmod 777 "$RESUME"
  run_tc --cwd "$WORK" --term print "$RESUME/real.md"
  chmod 755 "$RESUME"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: handoff file is in a group- or world-writable directory"* ]]
}

@test "trust: an explicit file in a private directory gets no writable-dir warning" {
  run_tc --cwd "$WORK" --term print "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" != *"writable"* ]]
}

@test "trust: equal modification times resolve in file-name order" {
  printf 'a\n' >"$RESUME/a.md"
  printf 'b\n' >"$RESUME/b.md"
  set_mtime "$RESUME/a.md" 202610010000
  set_mtime "$RESUME/b.md" 202610010000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/a.md"* ]]
}

@test "trust: a symlink candidate is skipped even when newest" {
  printf 'real\n' >"$RESUME/real.md"
  printf 'target\n' >"$TEST_ROOT/elsewhere.md"
  ln -s "$TEST_ROOT/elsewhere.md" "$RESUME/link.md"
  set_mtime "$RESUME/real.md" 202601010000
  set_mtime "$TEST_ROOT/elsewhere.md" 202601050000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/real.md"* ]]
}

@test "trust: when only a symlink candidate exists the error says why" {
  printf 'target\n' >"$TEST_ROOT/elsewhere.md"
  ln -s "$TEST_ROOT/elsewhere.md" "$RESUME/link.md"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"1 candidate(s) skipped: symlink, not owned by you"* ]]
}

@test "trust: a candidate whose name has a control character is skipped" {
  printf 'x\n' >"$RESUME/$(printf 'ta\tb').md"
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"candidate(s) skipped"* ]]
}

@test "trust: a candidate whose name has an RLM mark is skipped even when newest" {
  printf 'old\n' >"$RESUME/older.md"
  printf 'x\n' >"$RESUME/$(printf 'new\342\200\217x').md"
  set_mtime "$RESUME/older.md" 202601010000
  set_mtime "$RESUME/$(printf 'new\342\200\217x').md" 202601050000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/older.md"* ]]
}

@test "trust: a candidate whose name has a no-break space is skipped even when newest" {
  printf 'old\n' >"$RESUME/older.md"
  printf 'x\n' >"$RESUME/$(printf 'new\302\240x').md"
  set_mtime "$RESUME/older.md" 202601010000
  set_mtime "$RESUME/$(printf 'new\302\240x').md" 202601050000
  run_tc --latest --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/older.md"* ]]
}

@test "trust: candidates whose names contain soft hyphen, ZWSP, word joiner or BOM are skipped even when newest" {
  local oct name
  for oct in '\302\255' '\342\200\213' '\342\201\240' '\357\273\277'; do
    rm -f "$RESUME"/*.md
    # shellcheck disable=SC2059
    name="new$(printf "$oct")x.md"
    printf 'old\n' >"$RESUME/older.md"
    printf 'x\n' >"$RESUME/$name"
    set_mtime "$RESUME/older.md" 202601010000
    set_mtime "$RESUME/$name" 202601050000
    run_tc --latest --cwd "$TEST_ROOT" --term print
    [ "$status" -eq 0 ]
    [[ "$output" == *"tin-can: using $RESUME/older.md"* ]] || return 1
  done
}

@test "invisible characters: an explicit handoff file containing one is refused" {
  local oct name
  for oct in '\302\255' '\342\200\213' '\342\201\240' '\357\273\277'; do
    # shellcheck disable=SC2059
    name="a$(printf "$oct")b.md"
    printf 'x\n' >"$TEST_ROOT/$name"
    run_tc --term print --cwd "$WORK" "$TEST_ROOT/$name"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]] || return 1
    [ "$(total_calls)" -eq 0 ] || return 1
  done
}

@test "lookalike spaces and tag characters are refused as 'control' errors" {
  local n
  for n in "$(printf 'x\342\200\201y')" "$(printf 'x\343\200\200y')" \
    "$(printf 'x\363\240\201\224y')"; do
    run_tc --term print --cwd "$TEST_ROOT/no-such/$n" "$HF"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
  done
}

@test "trust: an explicit symlink handoff is allowed but warns" {
  ln -s "$HF" "$TEST_ROOT/link.md"
  run_tc --cwd "$WORK" --term print "$TEST_ROOT/link.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING: handoff file is a symlink"* ]]
}

@test "trust: an explicit regular file does not warn" {
  printf 'a\n' >"$RESUME/myrepo-trust.md"
  run_tc --cwd "$WORK" --term print "$RESUME/myrepo-trust.md"
  [ "$status" -eq 0 ]
  [[ "$output" != *"WARNING"* ]]
}

# NOT TESTED: the "not owned by you" paths (search dir / candidate / explicit
# file) need a file owned by another uid, which requires root to create.

# --- cwd ----------------------------------------------------------------------------

@test "cwd: nonexistent --cwd exits 2" {
  run_tc --cwd "$TEST_ROOT/nope" --term print "$HF"
  [ "$status" -eq 2 ]
}

@test "cwd: defaults to the current directory" {
  cd "$WORK"
  CMD="$(env "PATH=$TC_PATH" "$TC_BASH" "$TC" --term print "$HF" 2>/dev/null)"
  run env "PATH=$TC_PATH" "$TC_BASH" -c "$CMD"
  [ "$status" -eq 0 ]
  load_call claude
  [ "$CALL_PWD" = "$WORK" ]
}

@test "cwd: symlinked --cwd is canonicalised" {
  ln -s "$WORK" "$TEST_ROOT/link-to-work"
  CMD="$(tc_cmd --cwd "$TEST_ROOT/link-to-work" "$HF")"
  [[ "$CMD" == *"$WORK"* ]]
  [[ "$CMD" != *"link-to-work"* ]]
}

# --- dry run ---------------------------------------------------------------------------

@test "dry-run: cmux launches nothing and shows the new-surface command" {
  export CMUX_WORKSPACE_ID=ws-1
  run_tc --dry-run --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"new-surface"* ]]
  [[ "$output" == *"exec 'claude'"* ]]
  [[ "$output" == *"nothing launched"* ]]
}

@test "dry-run: tmux window shows new-session and launches nothing" {
  run_tc --dry-run --term tmux --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"new-session"* ]]
}

@test "dry-run: print mode launches nothing" {
  run_tc --dry-run --term print --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
}

@test "dry-run: still validates the handoff" {
  run_tc --dry-run --cwd "$WORK" "$TEST_ROOT/nope.md"
  [ "$status" -eq 2 ]
}

# --- quoting round-trip (the security-relevant part) ---------------------------------

# roundtrip DIRNAME FILENAME [AGENT] [SHELL] [LC_ALL]: put the handoff at
# DIR/FILE with cwd DIR, generate the command, run it in a real shell against
# the stub agent, and require exactly one argv element equal to the expected
# prompt, started in the expected cwd.
roundtrip() {
  local dname="$1" fname="$2" agent="${3:-claude}" shell="${4:-$TC_BASH}" lc="${5:-}"
  local d="$TEST_ROOT/rt/$dname" cdir cmd before after
  local -a envargs
  envargs=("PATH=$TC_PATH")
  if [ -n "$lc" ]; then envargs+=("LC_ALL=$lc"); fi
  mkdir -p "$d"
  printf '# h\n\n## KICKOFF\nGo.\n' >"$d/$fname"
  cdir="$(cd -P "$d" && pwd -P)"
  cmd="$(env "${envargs[@]}" "$TC_BASH" "$TC" --term print --agent "$agent" --cwd "$d" "$d/$fname" 2>/dev/null)"
  before="$(total_calls)"
  env "${envargs[@]}" "$shell" -c "$cmd"
  after="$(total_calls)"
  [ "$after" -eq $((before + 1)) ]
  load_call "$agent"
  [ "${#ARGS[@]}" -eq 1 ]
  [ "${ARGS[0]}" = "Read the handoff file at $cdir/$fname and follow its KICKOFF section." ]
  [ "$CALL_PWD" = "$cdir" ]
}

# The special-character corpus, run under SHELL (and optionally LC_ALL).
roundtrip_corpus() {
  local shell="$1" lc="${2:-}" agent="${3:-claude}"
  roundtrip "dir with spaces" "hand off.md" "$agent" "$shell" "$lc"
  roundtrip "it's a dir" "it's.md" "$agent" "$shell" "$lc"
  roundtrip 'say "hi"' 'say "hi".md' "$agent" "$shell" "$lc"
  roundtrip 'cost $HOME $(whoami)' 'a $HOME ${PATH}.md' "$agent" "$shell" "$lc"
  roundtrip 'tick `id` dir' 'back`id`tick.md' "$agent" "$shell" "$lc"
  roundtrip 'semi;colon&amp|pipe' 'x;y&z|w.md' "$agent" "$shell" "$lc"
  roundtrip 'glob *?[abc]' 'g *?[x].md' "$agent" "$shell" "$lc"
  roundtrip 'bang! ~tilde #hash' 'b!ang ~t #h.md' "$agent" "$shell" "$lc"
  roundtrip '-dash dir' '-dash-file.md' "$agent" "$shell" "$lc"
  roundtrip 'back\slash (paren) <lt> >gt' 'p(a)\r.md' "$agent" "$shell" "$lc"
  roundtrip "caf$(printf '\303\251') $(printf '\346\227\245\346\234\254')" "r$(printf '\303\251')sum$(printf '\303\251') $(printf '\346\227\245\346\234\254').md" "$agent" "$shell" "$lc"
}

# Find a POSIX sh that is NOT bash, preferring dash.
find_dash() {
  local d
  d="$(command -v dash || true)"
  if [ -z "$d" ] && [ -x /bin/sh ]; then d=/bin/sh; fi
  printf '%s' "$d"
}

@test "roundtrip: special-character corpus under bash" {
  roundtrip_corpus "$TC_BASH"
}

@test "roundtrip: special-character corpus under zsh (cmux's usual user shell)" {
  local z
  z="$(command -v zsh)" || skip "zsh not installed"
  roundtrip_corpus "$z"
}

@test "roundtrip: special-character corpus under dash / POSIX sh" {
  local s
  s="$(find_dash)"
  [ -n "$s" ] || skip "neither dash nor /bin/sh available"
  roundtrip_corpus "$s"
}

@test "roundtrip: codex agent with the corpus under bash" {
  roundtrip_corpus "$TC_BASH" "" codex
}

@test "roundtrip: non-ASCII names under LC_ALL=C in bash" {
  roundtrip "caf$(printf '\303\251') $(printf '\346\227\245\346\234\254')" "$(printf 'r\303\251sum\303\251 \346\227\245\346\234\254').md" claude "$TC_BASH" C
}

@test "roundtrip: non-ASCII names under LC_ALL=C in dash / POSIX sh" {
  local s
  s="$(find_dash)"
  [ -n "$s" ] || skip "neither dash nor /bin/sh available"
  roundtrip "caf$(printf '\303\251') $(printf '\346\227\245\346\234\254')" "$(printf 'r\303\251sum\303\251 \346\227\245\346\234\254').md" claude "$s" C
}

@test "roundtrip: non-ASCII names under LC_ALL=C in zsh" {
  local z
  z="$(command -v zsh)" || skip "zsh not installed"
  roundtrip "caf$(printf '\303\251') $(printf '\346\227\245\346\234\254')" "$(printf 'r\303\251sum\303\251 \346\227\245\346\234\254').md" claude "$z" C
}

@test "roundtrip: no command injection side effect from a hostile name" {
  # Names cannot contain "/", so the injected touch uses a relative marker;
  # it would land in the test's cwd (before cd) or in the target dir (after).
  mkdir -p "$TEST_ROOT/start"
  cd "$TEST_ROOT/start"
  roundtrip 'x$(touch PWNED)' 'y`touch PWNED`.md'
  [ ! -e "$TEST_ROOT/start/PWNED" ]
  [ ! -e "$TEST_ROOT/rt/"'x$(touch PWNED)'"/PWNED" ]
}

# --- control characters are refused (exit 2) ---------------------------------------

@test "control chars: tab, newline, CR, ESC, DEL, trailing newline in --cwd are refused" {
  local n
  for n in $'a\tb' $'a\nb' $'a\rb' $'a\033b' $'a\177b' $'trail\n'; do
    mkdir -p "$TEST_ROOT/ctl/$n"
    run_tc --term print --cwd "$TEST_ROOT/ctl/$n" "$HF"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
    [[ "$output" != *$'\033'* ]]
    [ "$(total_calls)" -eq 0 ]
  done
}

@test "control chars: tab, newline, CR, ESC, DEL, trailing newline in the handoff file name are refused" {
  local n
  mkdir -p "$TEST_ROOT/ctl"
  for n in $'a\tb.md' $'a\nb.md' $'a\rb.md' $'a\033b.md' $'a\177b.md' $'trail.md\n'; do
    printf 'x\n' >"$TEST_ROOT/ctl/$n"
    run_tc --term print --cwd "$WORK" "$TEST_ROOT/ctl/$n"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
    [[ "$output" != *$'\033'* ]]
  done
}

@test "control chars: a control character in the handoff directory is refused" {
  local n
  for n in $'d\tir' $'d\nir' $'d\033ir'; do
    mkdir -p "$TEST_ROOT/ctlh/$n"
    printf 'x\n' >"$TEST_ROOT/ctlh/$n/h.md"
    run_tc --term print --cwd "$WORK" "$TEST_ROOT/ctlh/$n/h.md"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
  done
}

@test "control chars: a control character in --dir is refused" {
  mkdir -p "$TEST_ROOT/ctld/$(printf 'a\tb')"
  run_tc --term print --cwd "$WORK" --dir "$TEST_ROOT/ctld/$(printf 'a\tb')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"control character"* ]]
}

@test "control chars: an LRM mark in --dir is refused" {
  mkdir -p "$TEST_ROOT/ctld/$(printf 'a\342\200\216b')"
  run_tc --term print --latest --cwd "$WORK" --dir "$TEST_ROOT/ctld/$(printf 'a\342\200\216b')"
  [ "$status" -eq 2 ]
  [[ "$output" == *"control character"* ]]
}

@test "control chars: a symlinked --cwd whose real path has a control character is refused" {
  mkdir -p "$TEST_ROOT/real$(printf '\t')dir"
  ln -s "$TEST_ROOT/real$(printf '\t')dir" "$TEST_ROOT/clean-link"
  run_tc --term print --cwd "$TEST_ROOT/clean-link" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"control character"* ]]
}

# --- adapter failure ---------------------------------------------------------------------

@test "failure: cmux non-zero exits 1 with error and paste fallback" {
  export STUB_EXIT_CMUX=3
  run_tc --term cmux --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cmux failed (exit 3)"* ]]
  [[ "$output" == *"stub cmux failing on request"* ]]
  [[ "$output" == *"paste this into a new terminal tab"* ]]
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "failure: tmux non-zero exits 1 with fallback" {
  export STUB_EXIT_TMUX=1
  run_tc --term tmux --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"tmux failed (exit 1)"* ]]
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "failure: explicit --term cmux with cmux missing exits 1 with fallback" {
  rm "$STUBS/cmux"
  run_tc --term cmux --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"exec 'claude' "* ]]
}

# --- version / symlink ------------------------------------------------------------------------

@test "version: --version prints the VERSION file contents" {
  run_tc --version
  [ "$status" -eq 0 ]
  [ "$output" = "tin-can $(cat "$BATS_TEST_DIRNAME/../VERSION")" ]
}

@test "version: found through absolute and relative symlinks and a symlink chain" {
  mkdir -p "$TEST_ROOT/fake/bin" "$TEST_ROOT/links/one" "$TEST_ROOT/links/two"
  cp "$TC" "$TEST_ROOT/fake/bin/tin-can"
  printf '9.9.9\n' >"$TEST_ROOT/fake/VERSION"
  # absolute link
  ln -s "$TEST_ROOT/fake/bin/tin-can" "$TEST_ROOT/links/one/tin-can"
  # relative link
  ln -s "../../fake/bin/tin-can" "$TEST_ROOT/links/two/tin-can"
  # chain: link -> link -> real
  ln -s "$TEST_ROOT/links/two/tin-can" "$TEST_ROOT/links/chain"
  local p
  for p in "$TEST_ROOT/links/one/tin-can" "$TEST_ROOT/links/two/tin-can" "$TEST_ROOT/links/chain"; do
    run env "PATH=$TC_PATH" "$TC_BASH" "$p" --version
    [ "$status" -eq 0 ]
    [ "$output" = "tin-can 9.9.9" ]
  done
}

@test "version: missing VERSION file reports unknown rather than failing" {
  mkdir -p "$TEST_ROOT/novers/bin"
  cp "$TC" "$TEST_ROOT/novers/bin/tin-can"
  run env "PATH=$TC_PATH" "$TC_BASH" "$TEST_ROOT/novers/bin/tin-can" --version
  [ "$status" -eq 0 ]
  [ "$output" = "tin-can unknown" ]
}

# --- CDPATH must not corrupt directory resolution ---------------------------------

@test "CDPATH: a relative --cwd resolves to the directory, not a CDPATH decoy" {
  mkdir -p "$TEST_ROOT/start/myrepo" "$TEST_ROOT/cdp/myrepo"
  cd "$TEST_ROOT/start"
  run env "PATH=$TC_PATH" "CDPATH=$TEST_ROOT/cdp" "$TC_BASH" "$TC" --term print --cwd myrepo "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cd '$TEST_ROOT/start/myrepo' && exec 'claude'"* ]]
}

@test "CDPATH: --version still finds VERSION when invoked by a relative path" {
  mkdir -p "$TEST_ROOT/fakeroot/bin" "$TEST_ROOT/cdp/bin"
  cp "$TC" "$TEST_ROOT/fakeroot/bin/tin-can"
  printf '7.7.7\n' >"$TEST_ROOT/fakeroot/VERSION"
  cd "$TEST_ROOT/fakeroot"
  run env "PATH=$TC_PATH" "CDPATH=$TEST_ROOT/cdp" "$TC_BASH" bin/tin-can --version
  [ "$status" -eq 0 ]
  [ "$output" = "tin-can 7.7.7" ]
}

# --- C1 / bidi / line-separator characters are refused ---------------------------------

@test "unicode controls: C1, bidi and line-separator characters in --cwd are refused" {
  local n
  for n in "$(printf 'a\302\233b')" "$(printf 'a\302\200b')" "$(printf 'a\302\237b')" \
    "$(printf 'a\342\200\256b')" "$(printf 'a\342\200\252b')" "$(printf 'a\342\200\250b')" \
    "$(printf 'a\342\200\251b')" "$(printf 'a\342\201\246b')" "$(printf 'a\342\201\251b')" \
    "$(printf 'a\342\200\216b')" "$(printf 'a\342\200\217b')" "$(printf 'a\330\234b')"; do
    mkdir -p "$TEST_ROOT/uc/$n"
    run_tc --term print --cwd "$TEST_ROOT/uc/$n" "$HF"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
    [ "$(total_calls)" -eq 0 ]
  done
}

@test "unicode controls: C1, bidi and mark characters in the handoff path are refused" {
  local n
  mkdir -p "$TEST_ROOT/uch"
  for n in "$(printf 'a\302\233b.md')" "$(printf 'a\342\200\256b.md')" \
    "$(printf 'a\342\200\216b.md')" "$(printf 'a\330\234b.md')"; do
    printf 'x\n' >"$TEST_ROOT/uch/$n"
    run_tc --term print --cwd "$WORK" "$TEST_ROOT/uch/$n"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
  done
}

@test "unicode controls: ordinary non-ASCII near the refused ranges is accepted" {
  # U+00A1 (C2 A1), U+00C1 (C3 81), U+2030 (E2 80 B0), U+2064 (E2 81 A4),
  # U+2061 (E2 81 A1), U+206A (E2 81 AA), ZWJ U+200D (E2 80 8D), emoji
  # (F0 9F 98 80)
  roundtrip "$(printf 'nb\302\241sp')" "$(printf 'c\303\201.md')"
  roundtrip "$(printf 'nn\342\200\260sp')" "$(printf 'u\342\201\244.md')"
  roundtrip "$(printf 'fa\342\201\241sp')" "$(printf 'z\342\200\215w.md')"
  roundtrip "$(printf 'e\342\201\252x')" "$(printf 'smile \360\237\230\200.md')"
}

@test "unicode controls: boundary characters just outside the refused ranges are not 'control' errors" {
  # Non-existent --cwd, so no file name has to be creatable (APFS rejects
  # some unassigned code points). The error must be the "not a directory" one.
  # Each input is paired with its octal rendering: the error must name THIS
  # input, escaped (UTF-8 locale, so bash 3.2's locale path is exercised).
  local oct raw
  for oct in '\342\200\247' '\342\201\245' '\342\201\252' \
    '\302\241' '\303\201' '\342\200\215' '\342\200\220' '\330\233' '\330\235' \
    '\341\277\277' '\342\200\214' '\342\200\260' '\342\201\236' '\342\201\241' \
    '\342\277\277' '\343\200\201' '\363\237\277\277' '\363\240\202\200' \
    '\302\254' '\302\256' '\357\273\276' '\357\274\200'; do
    # shellcheck disable=SC2059
    raw="$(printf "$oct")"
    run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --cwd "$TEST_ROOT/no-such/a${raw}b" "$HF"
    # '|| return 1': bash 3.2 does not fail a test on a non-final [[ ]].
    [ "$status" -eq 2 ]
    [[ "$output" == *"--cwd is not a directory: "* ]] || return 1
    [[ "$output" == *"$oct"* ]] || return 1
    [[ "$output" != *"$raw"* ]] || return 1
    [[ "$output" != *"control character"* ]] || return 1
  done
}

@test "unicode controls: first and last refused characters of each range are 'control' errors" {
  local n
  for n in "$(printf '\302\200')" "$(printf '\302\237')" \
    "$(printf '\342\200\250')" "$(printf '\342\200\256')" \
    "$(printf '\342\201\246')" "$(printf '\342\201\251')" \
    "$(printf '\342\200\216')" "$(printf '\342\200\217')" "$(printf '\330\234')" \
    "$(printf '\302\240')" "$(printf '\342\200\200')" "$(printf '\342\200\212')" \
    "$(printf '\342\200\257')" "$(printf '\342\201\237')" "$(printf '\343\200\200')" \
    "$(printf '\302\255')" "$(printf '\342\200\213')" "$(printf '\342\201\240')" \
    "$(printf '\357\273\277')" \
    "$(printf '\363\240\200\200')" "$(printf '\363\240\201\277')"; do
    run_tc --term print --cwd "$TEST_ROOT/no-such/a${n}b" "$HF"
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]]
  done
}

@test "unicode controls: error messages show C1/bidi bytes escaped, never raw (UTF-8 locale)" {
  local oct raw
  for oct in '\302\233' '\342\200\256' '\342\200\216' '\330\234'; do
    # shellcheck disable=SC2059
    raw="$(printf "$oct")"
    run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --cwd "$TEST_ROOT/no-such/a${raw}b" "$HF"
    # '|| return 1': bash 3.2 does not fail a test on a non-final [[ ]].
    [ "$status" -eq 2 ]
    [[ "$output" == *"control character"* ]] || return 1
    [[ "$output" == *"$oct"* ]] || return 1
    [[ "$output" != *"$raw"* ]] || return 1
  done
}

# ZWJ (U+200D) is not refused by has_ctrl, so it reaches the path error and
# warning messages, which must show it escaped via shown(), never raw.
@test "path in error: --cwd not a directory shows ZWJ escaped (UTF-8 locale)" {
  local z; z="$(printf '\342\200\215')"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --cwd "$TEST_ROOT/no-such/a${z}b" "$HF"
  [ "$status" -eq 2 ]
  [[ "$output" == *"--cwd is not a directory"* ]]
  [[ "$output" != *"$z"* ]]
  [[ "$output" == *'\342\200\215'* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "path in error: handoff not a regular file shows ZWJ escaped (UTF-8 locale)" {
  local z; z="$(printf '\342\200\215')"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print "$TEST_ROOT/no-such/h${z}.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"handoff is not an existing regular file"* ]]
  [[ "$output" != *"$z"* ]]
  [[ "$output" == *'\342\200\215'* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "path in error: --dir not found shows ZWJ escaped (UTF-8 locale)" {
  local z; z="$(printf '\342\200\215')"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --latest --dir "$TEST_ROOT/no-such/d${z}"
  [ "$status" -eq 2 ]
  [[ "$output" == *"handoff search dir not found"* ]]
  [[ "$output" != *"$z"* ]]
  [[ "$output" == *'\342\200\215'* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "path in warning: symlink handoff warning shows ZWJ escaped (UTF-8 locale)" {
  local z line found=0; z="$(printf '\342\200\215')"
  mkdir -p "$TEST_ROOT/zw"
  chmod 700 "$TEST_ROOT/zw"
  ln -s "$HF" "$TEST_ROOT/zw/s${z}.md"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print "$TEST_ROOT/zw/s${z}.md"
  [ "$status" -eq 0 ]
  [[ "$output" == *"handoff file is a symlink"* ]]
  while IFS= read -r line; do
    if [[ "$line" == *"handoff file is a symlink:"* ]]; then
      found=1
      [[ "$line" != *"$z"* ]]
      [[ "$line" == *'\342\200\215'* ]]
    fi
  done <<< "$output"
  [ "$found" -eq 1 ]
}

@test "path in warning: world-writable handoff dir warning shows ZWJ escaped (UTF-8 locale)" {
  local z line found=0; z="$(printf '\342\200\215')"
  mkdir -p "$TEST_ROOT/ww${z}d"
  printf 'x\n' >"$TEST_ROOT/ww${z}d/ok.md"
  chmod 777 "$TEST_ROOT/ww${z}d"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print "$TEST_ROOT/ww${z}d/ok.md"
  [ "$status" -eq 0 ]
  while IFS= read -r line; do
    if [[ "$line" == *"group- or world-writable directory"* ]]; then
      found=1
      [[ "$line" != *"$z"* ]]
      [[ "$line" == *'\342\200\215'* ]]
    fi
  done <<< "$output"
  [ "$found" -eq 1 ]
}

@test "path in error: no handoff file found shows ZWJ escaped (UTF-8 locale)" {
  local z; z="$(printf '\342\200\215')"
  mkdir -p "$TEST_ROOT/e${z}d"
  chmod 755 "$TEST_ROOT/e${z}d"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --latest --dir "$TEST_ROOT/e${z}d"
  [ "$status" -eq 2 ]
  [[ "$output" == *"no handoff file found in"* ]]
  [[ "$output" != *"$z"* ]]
  [[ "$output" == *'\342\200\215'* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "path in error: unreadable handoff shows ZWJ escaped (UTF-8 locale)" {
  if [ "$(id -u)" -eq 0 ]; then skip "root can read anything"; fi
  local z; z="$(printf '\342\200\215')"
  printf 'x\n' >"$TEST_ROOT/h${z}.md"
  chmod 000 "$TEST_ROOT/h${z}.md"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print "$TEST_ROOT/h${z}.md"
  [ "$status" -eq 2 ]
  [[ "$output" == *"not readable"* ]]
  [[ "$output" != *"$z"* ]]
  [[ "$output" == *'\342\200\215'* ]]
  [ "$(total_calls)" -eq 0 ]
}

@test "path in report: auto-select 'using' line shows ZWJ escaped (UTF-8 locale)" {
  local z line found=0; z="$(printf '\342\200\215')"
  printf 'x\n' >"$RESUME/n${z}.md"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term print --latest
  [ "$status" -eq 0 ]
  while IFS= read -r line; do
    if [[ "$line" == "tin-can: using "* ]]; then
      found=1
      [[ "$line" != *"$z"* ]]
      [[ "$line" == *'\342\200\215'* ]]
    fi
  done <<< "$output"
  [ "$found" -eq 1 ]
}

# raw_path_sites FILE: lines where die 2 / warn / FIND_ERR= still print a path
# variable raw. $(shown "...") wrappers are stripped first, so a line that
# escapes one path cannot hide a second, raw one.
raw_path_sites() {
  sed -E 's/\$\(shown "[^"]*"\)//g' "$1" |
    grep -nE '(die 2|warn|FIND_ERR=).*\$(cwd|dir|cdir|hd|handoff|handoff_arg)\b'
}

@test "static guard: no die 2 / warn / FIND_ERR line interpolates a path variable raw" {
  [ -r "$TC" ]
  run raw_path_sites "$TC"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  run grep -c 'using %s.*"\$(shown "\$handoff")"' "$TC"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# A failed launcher's stderr is untrusted: non-printable bytes become '?'.
@test "failure: launcher stderr with ESC, C1 and RLO is sanitized (UTF-8 locale)" {
  printf '%s\n' '#!/bin/sh' \
    "printf 'plain-text \\033[31m \\302\\233 \\342\\200\\256 end\\n' >&2" \
    "printf 'tin-can: launched claude in a new cmux tab\\n' >&2" \
    'exit 3' >"$STUBS/cmux"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --term cmux --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cmux failed (exit 3)"* ]] || return 1
  [[ "$output" == *"plain-text"* ]] || return 1
  [[ "$output" == *"  tin-can: launched claude in a new cmux tab"* ]] || return 1
  local l
  for l in "${lines[@]}"; do
    [[ "$l" != "tin-can: launched"* ]] || return 1
  done
  [[ "$output" == *"?[31m"* ]] || return 1
  [[ "$output" != *$'\033'* ]] || return 1
  [[ "$output" != *$'\xc2\x9b'* ]] || return 1
  [[ "$output" != *$'\xe2\x80\xae'* ]] || return 1
  [[ "$output" == *"paste this into a new terminal tab"* ]] || return 1
  [[ "$output" == *"exec 'claude' "* ]] || return 1
}

@test "dry-run: non-ASCII cwd is escaped, command stays raw, note on stderr (UTF-8 locale)" {
  local z; z="$(printf '\342\200\215')"
  mkdir -p "$TEST_ROOT/work/a${z}b"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "CMUX_WORKSPACE_ID=ws-1" "$TC_BASH" "$TC" --term cmux --where window --dry-run --cwd "$TEST_ROOT/work/a${z}b" "$HF"
  [ "$status" -eq 0 ]
  local cwdline launchline cmdline
  cwdline="$(printf '%s\n' "$output" | grep '^  cwd:')"
  launchline="$(printf '%s\n' "$output" | grep '^  launch:')"
  cmdline="$(printf '%s\n' "$output" | grep '^  command:')"
  [[ "$cwdline" == *'\342\200\215'* ]] || return 1
  [[ "$cwdline" != *"$z"* ]] || return 1
  [[ "$launchline" == *"--cwd"* ]] || return 1
  [[ "$launchline" != *"$z"* ]] || return 1
  [[ "$cmdline" == *"$z"* ]] || return 1
  [[ "$output" == *"note: the command contains non-ASCII characters"* ]] || return 1
}

@test "print: non-ASCII cwd notes on stderr, stdout is exactly the command" {
  local z out err; z="$(printf '\342\200\215')"
  mkdir -p "$TEST_ROOT/work/a${z}b"
  out="$(env "PATH=$TC_PATH" "$TC_BASH" "$TC" --term print --cwd "$TEST_ROOT/work/a${z}b" "$HF" 2>"$TEST_ROOT/err")"
  err="$(cat "$TEST_ROOT/err")"
  [[ "$err" == *"note: the command contains non-ASCII characters"* ]] || return 1
  [[ "$out" == "cd "* || "$out" == *"exec 'claude' "* ]] || return 1
  [[ "$out" != *"note:"* ]] || return 1
  [ "$out" = "$(tc_cmd --cwd "$TEST_ROOT/work/a${z}b" "$HF")" ]
}

@test "dry-run: ASCII-only paths print no non-ASCII note" {
  run_tc --term print --dry-run --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [[ "$output" != *"non-ASCII"* ]] || return 1
  run_tc --term print --cwd "$WORK" "$HF"
  [[ "$output" != *"non-ASCII"* ]] || return 1
}

@test "wrong folder: explicit handoff not named for the cwd warns, still launches" {
  printf 'a\n' >"$RESUME/2026-01-01-other-next.md"
  run_tc "$RESUME/2026-01-01-other-next.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not look like it belongs to"* ]]
}

@test "wrong folder: handoff named for the cwd repo does not warn" {
  printf 'a\n' >"$RESUME/2026-01-01-myrepo-next.md"
  run_tc "$RESUME/2026-01-01-myrepo-next.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not look like it belongs to"* ]]
}

@test "wrong folder: handoff inside the cwd does not warn" {
  mkdir -p "$WORK/docs"
  printf 'a\n' >"$WORK/docs/NEXT-SESSION.md"
  run_tc "$WORK/docs/NEXT-SESSION.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not look like it belongs to"* ]]
}

@test "wrong folder: repo name must be a whole word in the handoff name" {
  printf 'a\n' >"$RESUME/myrepository-next.md"
  printf 'b\n' >"$RESUME/x_myrepo.md"
  run_tc "$RESUME/myrepository-next.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not look like it belongs to"* ]] || return 1
  run_tc "$RESUME/x_myrepo.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not look like it belongs to"* ]]
}

@test "wrong folder: --latest falling back to an unrelated file warns" {
  printf 'a\n' >"$RESUME/other-notes.md"
  run_tc --latest --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"tin-can: using $RESUME/other-notes.md"* ]] || return 1
  [[ "$output" == *"does not look like it belongs to"* ]]
}

@test "wrong folder: --dry-run still warns and launches nothing" {
  printf 'a\n' >"$RESUME/2026-01-01-other-next.md"
  run_tc "$RESUME/2026-01-01-other-next.md" --cwd "$WORK" --term tmux --dry-run
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"does not look like it belongs to"* ]]
}

@test "wrong folder: --cwd / has no repo name, so no warning" {
  printf 'a\n' >"$RESUME/2026-01-01-other-next.md"
  run_tc "$RESUME/2026-01-01-other-next.md" --cwd / --term print
  [ "$status" -eq 0 ]
  [[ "$output" != *"does not look like it belongs to"* ]]
}

@test "wrong folder: a sibling directory sharing the cwd prefix is not inside it" {
  mkdir -p "$TEST_ROOT/work/myrepo2"
  printf 'a\n' >"$TEST_ROOT/work/myrepo2/notes.md"
  run_tc "$TEST_ROOT/work/myrepo2/notes.md" --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"does not look like it belongs to"* ]]
}

# --- --list --------------------------------------------------------------------

@test "list: newest first, * on the --latest pick, + on repo-named files" {
  printf 'a\n' >"$RESUME/2026-01-03-other.md"
  printf 'b\n' >"$RESUME/2026-01-02-myrepo-next.md"
  printf 'c\n' >"$RESUME/2026-01-01-zeta.md"
  set_mtime "$RESUME/2026-01-03-other.md" 202601030000
  set_mtime "$RESUME/2026-01-02-myrepo-next.md" 202601020000
  set_mtime "$RESUME/2026-01-01-zeta.md" 202601010000
  run_tc --list --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == *"newest first (* = --latest would pick it, + = named for myrepo)" ]] || return 1
  [ "${lines[1]}" = "    2026-01-03-other.md" ]
  [ "${lines[2]}" = "* + 2026-01-02-myrepo-next.md" ]
  [ "${lines[3]}" = "    2026-01-01-zeta.md" ]
  [ "${#lines[@]}" -eq 4 ]
  [ "$(total_calls)" -eq 0 ]
}

@test "list: the * mark names the file --latest picks (repo match and none)" {
  local cwd
  printf 'a\n' >"$RESUME/new-other.md"
  printf 'b\n' >"$RESUME/old-myrepo.md"
  set_mtime "$RESUME/new-other.md" 202601030000
  set_mtime "$RESUME/old-myrepo.md" 202601010000
  for cwd in "$WORK" "$TEST_ROOT"; do
    run_tc --list --cwd "$cwd" --term print
    [ "$status" -eq 0 ]
    local star="" l stars=0
    for l in "${lines[@]}"; do
      if [[ "$l" == "* "* ]]; then
        star="${l:4}"
        stars=$((stars + 1))
      fi
    done
    [ "$stars" -eq 1 ]
    run_tc --latest --dry-run --cwd "$cwd" --term print
    [ "$status" -eq 0 ]
    [[ "$output" == *"tin-can: using $RESUME/$star"* ]] || return 1
  done
}

@test "list: shows at most 10 files then '... and N more'" {
  local i
  for i in 01 02 03 04 05 06 07 08 09 10 11 12; do
    printf 'x\n' >"$RESUME/f$i.md"
    set_mtime "$RESUME/f$i.md" "2026010100$i"
  done
  run_tc --list --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 12 ]
  [ "${lines[11]}" = "  ... and 2 more" ]
  [[ "${lines[1]}" == "* "*f12.md ]]
}

@test "list: skipped counts separate by-name from unsafe" {
  printf 'x\n' >"$RESUME/real.md"
  printf 'x\n' >"$RESUME/superseded-a.md"
  printf 'x\n' >"$RESUME/_b.md"
  printf 'x\n' >"$RESUME/c-auto.md"
  printf 'x\n' >"$TEST_ROOT/target.md"
  ln -s "$TEST_ROOT/target.md" "$RESUME/link.md"
  run_tc --list --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipped: 3 by name (superseded-*, _*, *-auto.md); 1 unsafe (symlink, not owned by you, or unsafe name)"* ]] || return 1
  [[ "$output" != *"c-auto.md"* ]] || return 1
  [[ "$output" != *"link.md"* ]] || return 1
}

@test "list: equal modification times are listed in file-name order" {
  printf 'a\n' >"$RESUME/a.md"
  printf 'b\n' >"$RESUME/b.md"
  set_mtime "$RESUME/a.md" 202610010000
  set_mtime "$RESUME/b.md" 202610010000
  run_tc --list --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "*   a.md" ]
  [ "${lines[2]}" = "    b.md" ]
}

@test "list: no candidates prints (no candidates) and exits 0" {
  run_tc --list --cwd "$TEST_ROOT" --term print
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "(no candidates)" ]
  [ "${#lines[@]}" -eq 2 ]
}

@test "list: a world-writable search dir is refused like --latest" {
  printf 'x\n' >"$RESUME/real.md"
  chmod 777 "$RESUME"
  run_tc --list --cwd "$WORK" --term print
  chmod 755 "$RESUME"
  [ "$status" -eq 2 ]
  [[ "$output" == *"group- or world-writable"* ]]
}

@test "list: combining --list with a file or --latest exits 2" {
  printf 'x\n' >"$RESUME/real.md"
  run_tc --list "$RESUME/real.md" --cwd "$WORK" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"--list cannot be combined"* ]] || return 1
  run_tc --list --latest --cwd "$WORK" --term print
  [ "$status" -eq 2 ]
  [[ "$output" == *"--list cannot be combined"* ]] || return 1
  [ "$(total_calls)" -eq 0 ]
}

@test "list: a file name with ZWJ is shown escaped, never raw" {
  local z
  z="$(printf '\342\200\215')"
  printf 'x\n' >"$RESUME/a${z}b.md"
  run env "PATH=$TC_PATH" "LANG=en_US.UTF-8" "LC_ALL=" "$TC_BASH" "$TC" --list --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  [[ "$output" == *'\342\200\215'* ]] || return 1
  [[ "$output" != *"$z"* ]]
}

@test "list: the --latest pick is shown once even when older than the newest 10" {
  local i
  for i in 01 02 03 04 05 06 07 08 09 10 11; do
    printf 'x\n' >"$RESUME/f$i.md"
    set_mtime "$RESUME/f$i.md" "2026010100$i"
  done
  printf 'x\n' >"$RESUME/oldest-myrepo.md"
  set_mtime "$RESUME/oldest-myrepo.md" 202501010000
  run_tc --list --cwd "$WORK" --term print
  [ "$status" -eq 0 ]
  local l stars=0
  for l in "${lines[@]}"; do
    if [[ "$l" == "* "* ]]; then stars=$((stars + 1)); fi
  done
  [ "$stars" -eq 1 ]
  [ "${lines[1]}" = "    f11.md" ]
  [ "${lines[10]}" = "    f02.md" ]
  [ "${lines[11]}" = "* + oldest-myrepo.md" ]
  [ "${lines[12]}" = "  ... and 1 more" ]
  [ "${#lines[@]}" -eq 13 ]
}

# --- wezterm and kitty ---------------------------------------------------------

@test "auto: WEZTERM_PANE + wezterm on PATH selects wezterm" {
  export WEZTERM_PANE=3
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count wezterm)" -eq 1 ]
  [ "$(total_calls)" -eq 1 ]
}

@test "auto: KITTY_WINDOW_ID + kitten on PATH selects kitty" {
  export KITTY_WINDOW_ID=4
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count kitten)" -eq 1 ]
  [ "$(total_calls)" -eq 1 ]
}

@test "auto: tmux wins over WEZTERM_PANE" {
  export TMUX=/tmp/tmux-1/default,1,0 WEZTERM_PANE=3
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count tmux)" -eq 1 ]
  [ "$(call_count wezterm)" -eq 0 ]
}

@test "auto: wezterm wins over kitty" {
  export WEZTERM_PANE=3 KITTY_WINDOW_ID=4
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count wezterm)" -eq 1 ]
  [ "$(call_count kitten)" -eq 0 ]
}

@test "auto: WEZTERM_PANE set but wezterm not on PATH prints" {
  export WEZTERM_PANE=3
  rm "$STUBS/wezterm"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"exec 'claude'"* ]]
}

@test "auto: KITTY_WINDOW_ID set but kitten not on PATH prints" {
  export KITTY_WINDOW_ID=4
  rm "$STUBS/kitten"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"exec 'claude'"* ]]
}

@test "wezterm tab: cli spawn -- sh -c CMD" {
  run_tc --term wezterm --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call wezterm
  [ "${#ARGS[@]}" -eq 6 ]
  [ "${ARGS[0]}" = "cli" ]
  [ "${ARGS[1]}" = "spawn" ]
  [ "${ARGS[2]}" = "--" ]
  [ "${ARGS[3]}" = "sh" ]
  [ "${ARGS[4]}" = "-c" ]
  [ "${ARGS[5]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
}

@test "wezterm window: cli spawn --new-window -- sh -c CMD" {
  run_tc --term wezterm --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call wezterm
  [ "${#ARGS[@]}" -eq 7 ]
  [ "${ARGS[0]}" = "cli" ]
  [ "${ARGS[1]}" = "spawn" ]
  [ "${ARGS[2]}" = "--new-window" ]
  [ "${ARGS[3]}" = "--" ]
  [ "${ARGS[4]}" = "sh" ]
  [ "${ARGS[5]}" = "-c" ]
  [ "${ARGS[6]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
}

@test "kitty tab: @ launch --type=tab sh -c CMD" {
  run_tc --term kitty --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call kitten
  [ "${#ARGS[@]}" -eq 6 ]
  [ "${ARGS[0]}" = "@" ]
  [ "${ARGS[1]}" = "launch" ]
  [ "${ARGS[2]}" = "--type=tab" ]
  [ "${ARGS[3]}" = "sh" ]
  [ "${ARGS[4]}" = "-c" ]
  [ "${ARGS[5]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
}

@test "kitty window: @ launch --type=os-window sh -c CMD" {
  run_tc --term kitty --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call kitten
  [ "${#ARGS[@]}" -eq 6 ]
  [ "${ARGS[2]}" = "--type=os-window" ]
  [ "${ARGS[3]}" = "sh" ]
  [ "${ARGS[4]}" = "-c" ]
  [ "${ARGS[5]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
}

@test "failure: wezterm non-zero exits 1 with fallback" {
  export STUB_EXIT_WEZTERM=1
  run_tc --term wezterm --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"wezterm failed (exit 1)"* ]] || return 1
  [[ "$output" == *"paste this into a new terminal tab"* ]] || return 1
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "failure: kitty non-zero exits 1 with fallback" {
  export STUB_EXIT_KITTEN=1
  run_tc --term kitty --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"kitty failed (exit 1)"* ]] || return 1
  [[ "$output" == *"paste this into a new terminal tab"* ]] || return 1
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "dry-run: kitty launches nothing and shows kitten @ launch" {
  run_tc --dry-run --term kitty --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"kitten @ launch"* ]]
}

@test "roundtrip: wezterm and kitty sh -c CMD survives a hostile directory name" {
  local d="$TEST_ROOT/rt/it's \$(id) dir" cdir t
  mkdir -p "$d"
  printf '# h\n\n## KICKOFF\nGo.\n' >"$d/h.md"
  cdir="$(cd -P "$d" && pwd -P)"
  for t in wezterm kitten; do
    run_tc --term "${t/kitten/kitty}" --cwd "$d" "$d/h.md"
    [ "$status" -eq 0 ]
    load_call "$t"
    env "PATH=$TC_PATH" /bin/sh -c "${ARGS[$((${#ARGS[@]} - 1))]}"
    load_call claude
    [ "$CALL_PWD" = "$cdir" ]
    [ "${#ARGS[@]}" -eq 1 ]
  done
}

# --- zellij --------------------------------------------------------------------

@test "auto: ZELLIJ=0 + zellij on PATH selects zellij (0 counts as set)" {
  export ZELLIJ=0
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count zellij)" -eq 1 ]
  [ "$(total_calls)" -eq 1 ]
}

@test "auto: tmux wins over ZELLIJ" {
  export TMUX=/tmp/tmux-1/default,1,0 ZELLIJ=0
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count tmux)" -eq 1 ]
  [ "$(call_count zellij)" -eq 0 ]
}

@test "auto: zellij wins over WEZTERM_PANE" {
  export ZELLIJ=0 WEZTERM_PANE=3
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count zellij)" -eq 1 ]
  [ "$(call_count wezterm)" -eq 0 ]
}

@test "auto: ZELLIJ set but zellij not on PATH falls through" {
  export ZELLIJ=0 WEZTERM_PANE=3
  rm "$STUBS/zellij"
  run_tc --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(call_count wezterm)" -eq 1 ]
  [ "$(total_calls)" -eq 1 ]
}

@test "zellij tab: action new-tab --name 'REPO (tin-can)' -- sh -c CMD" {
  run_tc --term zellij --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call zellij
  [ "${#ARGS[@]}" -eq 8 ]
  [ "${ARGS[0]}" = "action" ]
  [ "${ARGS[1]}" = "new-tab" ]
  [ "${ARGS[2]}" = "--name" ]
  [ "${ARGS[3]}" = "myrepo (tin-can)" ]
  [ "${ARGS[4]}" = "--" ]
  [ "${ARGS[5]}" = "sh" ]
  [ "${ARGS[6]}" = "-c" ]
  [ "${ARGS[7]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [[ "$output" == *"launched claude in a new zellij tab"* ]]
}

@test "zellij window: attach --create-background NAME -- sh -c CMD, and attach hint" {
  run_tc --term zellij --where window --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  load_call zellij
  [ "${#ARGS[@]}" -eq 7 ]
  [ "${ARGS[0]}" = "attach" ]
  [ "${ARGS[1]}" = "--create-background" ]
  [[ "${ARGS[2]}" =~ ^tin-can-[0-9]+-[0-9]+$ ]] || return 1
  [ "${ARGS[3]}" = "--" ]
  [ "${ARGS[4]}" = "sh" ]
  [ "${ARGS[5]}" = "-c" ]
  [ "${ARGS[6]}" = "$(tc_cmd --cwd "$WORK" "$HF")" ]
  [[ "$output" == *"launched claude in a new DETACHED zellij session; attach with: zellij attach ${ARGS[2]}"* ]]
}

@test "failure: zellij non-zero exits 1 with fallback" {
  export STUB_EXIT_ZELLIJ=1
  run_tc --term zellij --cwd "$WORK" "$HF"
  [ "$status" -eq 1 ]
  [[ "$output" == *"zellij failed (exit 1)"* ]] || return 1
  [[ "$output" == *"paste this into a new terminal tab"* ]] || return 1
  [[ "$output" == *"exec 'claude' "* ]]
}

@test "dry-run: zellij launches nothing and shows zellij action new-tab" {
  run_tc --dry-run --term zellij --cwd "$WORK" "$HF"
  [ "$status" -eq 0 ]
  [ "$(total_calls)" -eq 0 ]
  [[ "$output" == *"zellij action new-tab"* ]]
}

@test "roundtrip: zellij sh -c CMD survives a hostile directory name" {
  local d="$TEST_ROOT/rt/it's \$(id) dir" cdir
  mkdir -p "$d"
  printf '# h\n\n## KICKOFF\nGo.\n' >"$d/h.md"
  cdir="$(cd -P "$d" && pwd -P)"
  run_tc --term zellij --cwd "$d" "$d/h.md"
  [ "$status" -eq 0 ]
  load_call zellij
  env "PATH=$TC_PATH" /bin/sh -c "${ARGS[$((${#ARGS[@]} - 1))]}"
  load_call claude
  [ "$CALL_PWD" = "$cdir" ]
  [ "${#ARGS[@]}" -eq 1 ]
}

@test "help: every line is at most 80 columns" {
  local l
  run_tc --help
  [ "$status" -eq 0 ]
  for l in "${lines[@]}"; do
    [ "${#l}" -le 80 ] || return 1
  done
}
