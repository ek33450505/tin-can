# AGENTS.md

tin-can hands a coding session to a fresh terminal tab. The old session's agent writes a handoff file; tin-can opens a tab that starts an agent CLI (`claude` or `codex`) with one prompt that points at that file. tin-can never writes or parses the handoff. This file is for agents working ON tin-can. For the user-facing snippet, see `docs/agents-snippet.md`.

## Rules

- Never run `tin-can` for real. Never open terminal tabs or touch terminal control sockets (cmux, tmux, Zellij, WezTerm, kitty). Use `--dry-run`, `--term print` or `--list` only. The user launches handoffs.
- Keep bash 3.2 compatibility. `TIN_CAN_TEST_BASH=/bin/bash bats tests/` is the real check: `/bin/bash -n` checks syntax only and does not catch bash 4+ features such as `declare -A`, `${x,,}` or `mapfile`.
- Run both bats modes before saying tests pass. Read the TAP counts (`1..N`, any `not ok`), not the exit status alone.
- Mutation-check every new test: break the code, confirm the test fails, restore.
- Bump `VERSION` and `.claude-plugin/plugin.json` together, and update the README's pinned `#vX.Y.Z` plugin tag on release.
- Do not put instructions for your own project's AGENTS.md here. That snippet is `docs/agents-snippet.md`.

## Layout

- `bin/tin-can`: the launcher. All logic is in one script. Agents are in `SUPPORTED_AGENTS`. A terminal backend is one branch where the launch command is built.
- `hooks/tin-can-hook`: Claude Code plugin hook. It must fail open. Do not add `set -e`.
- `hooks/hooks.json`, `.claude-plugin/`: plugin packaging.
- `install.sh`: symlinks only.
- `skills/tin-can/SKILL.md`, `docs/handoff-format.md`, `docs/agents-snippet.md`: agent-facing docs.
- `tests/`: bats suites and helpers. Tests use stub terminals and agents on PATH and a temp HOME.

## Commands

```
bats tests/                                   # bats itself must run on bash >= 4
TIN_CAN_TEST_BASH=/bin/bash bats tests/       # run the script under test on macOS bash 3.2
shellcheck --shell=bash bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash
shfmt -d -i 2 -ci bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash
for f in bin/tin-can hooks/tin-can-hook install.sh; do /bin/bash -n "$f"; done
claude plugin validate .
bin/tin-can --help | awk 'length > 80'        # must print nothing
```

## Style

- In `bin/tin-can`, `hooks/tin-can-hook` and `install.sh`: POSIX `[ ]` tests, not `[[ ]]`. In bats tests, assert with `[[ ... ]] || return 1`. 2-space indent. Quote every expansion.
- Never interpolate handoff contents into a shell command. Build commands with the existing single-quoting helper.
- Refuse paths with control, bidi or invisible characters. Keep that behavior when you touch path handling.
- Tests never open a real terminal, start a real agent, or touch the real HOME.
- `--help` lines stay at or under 80 columns.
- User-visible changes go in `CHANGELOG.md` under `## [Unreleased]`.
