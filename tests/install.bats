#!/usr/bin/env bats

setup() {
  TEST_ROOT="$(mktemp -d "${BATS_TMPDIR:-/tmp}/tin-can-inst.XXXXXX")"
  TEST_ROOT="$(cd -P "$TEST_ROOT" && pwd -P)"
  export HOME="$TEST_ROOT/home"
  mkdir -p "$HOME"
  export TIN_CAN_BIN_DIR="$TEST_ROOT/bin"
  export CLAUDE_SKILLS_DIR="$TEST_ROOT/skills"
  REPO="$(cd -P "$BATS_TEST_DIRNAME/.." && pwd -P)"
}

teardown() {
  case "${TEST_ROOT:-}" in
    */tin-can-inst.*) rm -rf "$TEST_ROOT" ;;
    *) echo "teardown: refusing to rm: ${TEST_ROOT:-}" >&2 ;;
  esac
}

@test "install: links the binary and the skill" {
  run bash "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [ "$(readlink "$TIN_CAN_BIN_DIR/tin-can")" = "$REPO/bin/tin-can" ]
  [ "$(readlink "$CLAUDE_SKILLS_DIR/tin-can")" = "$REPO/skills/tin-can" ]
}

@test "install: is idempotent" {
  bash "$REPO/install.sh" >/dev/null
  run bash "$REPO/install.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already links"* ]]
  [[ "$output" != *"linked:  "* ]]
}

@test "install: refuses to overwrite a regular file" {
  mkdir -p "$TIN_CAN_BIN_DIR"
  printf 'precious\n' >"$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to overwrite"* ]]
  [ "$(cat "$TIN_CAN_BIN_DIR/tin-can")" = "precious" ]
}

@test "install: refuses to overwrite a directory" {
  mkdir -p "$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to overwrite"* ]]
  [ -d "$TIN_CAN_BIN_DIR/tin-can" ]
  [ ! -L "$TIN_CAN_BIN_DIR/tin-can" ]
}

@test "install: refuses a symlink pointing elsewhere, shows its target, leaves it" {
  mkdir -p "$TIN_CAN_BIN_DIR"
  ln -s /nonexistent/elsewhere "$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"/nonexistent/elsewhere"* ]]
  [[ "$output" == *"--force"* ]]
  [ "$(readlink "$TIN_CAN_BIN_DIR/tin-can")" = "/nonexistent/elsewhere" ]
}

@test "install: --force repoints a symlink that pointed elsewhere" {
  mkdir -p "$TIN_CAN_BIN_DIR"
  ln -s /nonexistent/elsewhere "$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh" --force
  [ "$status" -eq 0 ]
  [ "$(readlink "$TIN_CAN_BIN_DIR/tin-can")" = "$REPO/bin/tin-can" ]
}

@test "install: --force still refuses a regular file" {
  mkdir -p "$TIN_CAN_BIN_DIR"
  printf 'precious\n' >"$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh" --force
  [ "$status" -eq 1 ]
  [ "$(cat "$TIN_CAN_BIN_DIR/tin-can")" = "precious" ]
}

@test "install: an unwritable destination fails with status 1 and never reports linked" {
  printf 'i am a file\n' >"$TEST_ROOT/blocker"
  export TIN_CAN_BIN_DIR="$TEST_ROOT/blocker/bin"
  export CLAUDE_SKILLS_DIR="$TEST_ROOT/blocker/skills"
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error:"* ]]
  [[ "$output" != *"linked:"* ]]
  [ ! -L "$TEST_ROOT/blocker/bin/tin-can" ]
}

@test "install: a read-only destination dir fails with status 1 and never reports linked" {
  if [ "$(id -u)" -eq 0 ]; then skip "root ignores directory permissions"; fi
  mkdir -p "$TIN_CAN_BIN_DIR" "$CLAUDE_SKILLS_DIR"
  chmod 555 "$TIN_CAN_BIN_DIR" "$CLAUDE_SKILLS_DIR"
  run bash "$REPO/install.sh"
  chmod 755 "$TIN_CAN_BIN_DIR" "$CLAUDE_SKILLS_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" == *"error:"* ]]
  [[ "$output" != *"linked:"* ]]
  [ ! -L "$TIN_CAN_BIN_DIR/tin-can" ]
}

@test "install: one failing destination does not hide a successful one" {
  printf 'i am a file\n' >"$TEST_ROOT/blocker"
  export TIN_CAN_BIN_DIR="$TEST_ROOT/blocker/bin"
  run bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"linked:  $CLAUDE_SKILLS_DIR/tin-can"* ]]
  [[ "$output" != *"linked:  $TIN_CAN_BIN_DIR"* ]]
}

@test "install: unknown argument exits 2" {
  run bash "$REPO/install.sh" --bogus
  [ "$status" -eq 2 ]
}

@test "uninstall: removes our links and leaves foreign files alone" {
  bash "$REPO/install.sh" >/dev/null
  run bash "$REPO/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ ! -e "$TIN_CAN_BIN_DIR/tin-can" ]
  [ ! -L "$TIN_CAN_BIN_DIR/tin-can" ]
  [ ! -L "$CLAUDE_SKILLS_DIR/tin-can" ]

  printf 'mine\n' >"$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ "$(cat "$TIN_CAN_BIN_DIR/tin-can")" = "mine" ]
}

@test "uninstall: leaves a symlink that points elsewhere alone" {
  mkdir -p "$TIN_CAN_BIN_DIR"
  ln -s /nonexistent/elsewhere "$TIN_CAN_BIN_DIR/tin-can"
  run bash "$REPO/install.sh" --uninstall
  [ "$status" -eq 0 ]
  [ "$(readlink "$TIN_CAN_BIN_DIR/tin-can")" = "/nonexistent/elsewhere" ]
}

@test "installed symlink runs and reports the repo VERSION" {
  bash "$REPO/install.sh" >/dev/null
  run "$TIN_CAN_BIN_DIR/tin-can" --version
  [ "$status" -eq 0 ]
  [ "$output" = "tin-can $(cat "$REPO/VERSION")" ]
}

@test "install: fails closed when ln reports success but creates nothing (post-link verify)" {
  mkdir -p "$TEST_ROOT/shim"
  printf '%s\n' '#!/bin/sh' 'exit 0' >"$TEST_ROOT/shim/ln"
  chmod +x "$TEST_ROOT/shim/ln"
  run env "PATH=$TEST_ROOT/shim:$PATH" bash "$REPO/install.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"was not linked"* ]]
  [[ "$output" != *"linked:  "* ]]
  [ ! -L "$TIN_CAN_BIN_DIR/tin-can" ]
}

@test "install: works when CDPATH is set and the script is run by a relative path" {
  mkdir -p "$TEST_ROOT/inst" "$TEST_ROOT/cdp/inst"
  cp -R "$REPO/bin" "$REPO/skills" "$REPO/install.sh" "$REPO/VERSION" "$TEST_ROOT/inst/"
  cd "$TEST_ROOT"
  run env "CDPATH=$TEST_ROOT/cdp" bash inst/install.sh
  [ "$status" -eq 0 ]
  [ "$(readlink "$TIN_CAN_BIN_DIR/tin-can")" = "$TEST_ROOT/inst/bin/tin-can" ]
}
