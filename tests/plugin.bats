#!/usr/bin/env bats

load require_bash4

setup() {
  require_bash4 || return 1
  command -v jq >/dev/null 2>&1 || skip "jq not installed"
  REPO="$(cd -P "$BATS_TEST_DIRNAME/.." && pwd -P)"
}

@test "plugin: manifests and hooks.json are valid JSON" {
  jq -e . "$REPO/.claude-plugin/plugin.json" >/dev/null
  jq -e . "$REPO/.claude-plugin/marketplace.json" >/dev/null
  jq -e . "$REPO/hooks/hooks.json" >/dev/null
}

@test "plugin: plugin.json name is tin-can and version matches VERSION" {
  [ "$(jq -r .name "$REPO/.claude-plugin/plugin.json")" = "tin-can" ]
  [ "$(jq -r .version "$REPO/.claude-plugin/plugin.json")" = "$(tr -d '[:space:]' <"$REPO/VERSION")" ]
}

@test "plugin: marketplace lists tin-can sourced from the repo root" {
  [ "$(jq -r '.plugins[0].source' "$REPO/.claude-plugin/marketplace.json")" = "./" ]
  [ "$(jq -r '.plugins[0].name' "$REPO/.claude-plugin/marketplace.json")" = "tin-can" ]
}

@test "plugin: hooks.json has exactly the three events and the write matcher" {
  [ "$(jq -r '.hooks | keys | join(",")' "$REPO/hooks/hooks.json")" = "PostToolUse,Stop,UserPromptSubmit" ]
  [ "$(jq -r '.hooks.PostToolUse[0].matcher' "$REPO/hooks/hooks.json")" = 'Write|Edit|MultiEdit' ]
}

@test "plugin: every hook command targets the plugin root and a handled event" {
  local cmds cmd ev n=0
  cmds="$(jq -r '.hooks[][].hooks[].command' "$REPO/hooks/hooks.json")"
  while IFS= read -r cmd; do
    n=$((n + 1))
    # shellcheck disable=SC2016
    [[ "$cmd" == *'${CLAUDE_PLUGIN_ROOT}'*'/hooks/tin-can-hook '* ]] || return 1
    ev="${cmd##* }"
    grep -qE "^[[:space:]]*${ev}\)" "$REPO/hooks/tin-can-hook" || return 1
  done <<<"$cmds"
  [ "$n" -eq 3 ]
}

@test "plugin: hook script and binary are executable" {
  [ -x "$REPO/hooks/tin-can-hook" ]
  [ -x "$REPO/bin/tin-can" ]
  [ -x "$REPO/install.sh" ]
}
