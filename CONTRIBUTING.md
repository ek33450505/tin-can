# Contributing to tin-can

Thanks for helping. tin-can is one bash script, a Claude Code plugin hook, and a set of bats tests. Small, focused pull requests merge fastest.

## Prerequisites

- bash 3.2 or later for the script. The script must run on the bash that ships with macOS.
- [bats-core](https://github.com/bats-core/bats-core) on bash 4 or later: `brew install bats-core bash` or `apt-get install bats`.
- [shellcheck](https://www.shellcheck.net) and [shfmt](https://github.com/mvdan/sh).
- `jq` for the hook tests.
- `zsh` and `dash`, optional. The quoting round-trip tests use them; a missing shell skips that test.

## Quick Start

```
git clone https://github.com/ek33450505/tin-can.git
cd tin-can
./install.sh               # links bin/tin-can into ~/.local/bin and the skill into ~/.claude/skills
bin/tin-can --help
bin/tin-can --list
```

Run the tests:

```
bats tests/
TIN_CAN_TEST_BASH=/bin/bash bats tests/
```

Read the TAP output: the plan line (`1..N`) and any `not ok` line. The exit status alone is not enough.

## How to Modify

- **`bin/tin-can`**: the launcher. All logic is here. To add an agent, add its name to `SUPPORTED_AGENTS`, and add a `case` branch in `agent_binary` if its binary name differs. To add a terminal backend, add its name to `SUPPORTED_TERMS`, add a branch where the launch command is built, add its check to `detect_term` (an environment variable plus the binary it runs, which can differ from the name: kitty runs `kitten`), and update the `--help` text. For tests, add the stub to the `make_stubs` list in `tests/helpers.bash`, and add the terminal's environment variable and its `STUB_EXIT_*` variable to the `unset` lines there. Update the README's terminal table and `--term auto` order.
- **`hooks/tin-can-hook`**: the Claude Code plugin hook for the `post-write`, `prompt` and `stop` events. It must fail open: any problem exits 0 with no output. It deliberately has no `set -e`. `TIN_CAN_HOOKS=0` disables it.
- **`hooks/hooks.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`**: plugin packaging. The `version` in `plugin.json` must equal `VERSION`. Bump both together.
- **`install.sh`**: symlinks only. Keep it that way.
- **`skills/tin-can/SKILL.md`** and **`docs/handoff-format.md`**: the handoff contract. If you change the format, change both.
- **`docs/agents-snippet.md`**: the snippet users paste into their own `AGENTS.md`.
- **`tests/`**: add tests next to the behavior they cover. Tests use stub `cmux`, `tmux`, `zellij`, `wezterm`, `kitten`, `claude` and `codex` on `PATH`, and a temp HOME. They must never open a real terminal, start a real agent, or touch the real HOME.
- **`CHANGELOG.md`**: add user-visible changes under `## [Unreleased]`.

## PR Checklist

CI runs shellcheck and the bats suite on Ubuntu. A macOS job runs the suite under the system `/bin/bash` 3.2, but not on every event (see `.github/workflows/ci.yml`), so run `TIN_CAN_TEST_BASH=/bin/bash bats tests/` and the other checks locally before you open a pull request.

- [ ] `bats tests/` passes on bash 4 or later, with the TAP counts read.
- [ ] `TIN_CAN_TEST_BASH=/bin/bash bats tests/` passes.
- [ ] `shellcheck --shell=bash bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash` is clean.
- [ ] `shfmt -d -i 2 -ci bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash` is clean.
- [ ] `for f in bin/tin-can hooks/tin-can-hook install.sh; do /bin/bash -n "$f"; done` is clean.
- [ ] `claude plugin validate .` passes.
- [ ] `bin/tin-can --help | awk 'length > 80'` prints nothing.
- [ ] Each new test fails when the code it covers is broken (mutation check).
- [ ] `VERSION` and `.claude-plugin/plugin.json` are bumped together, and the README's pinned tag (`/plugin marketplace add ek33450505/tin-can#vX.Y.Z`) is updated, if this is a release.
- [ ] `CHANGELOG.md` has an entry under `## [Unreleased]`, if the change is user-visible.

## Code Style

- Bash 3.2 compatible. No `mapfile`, `readarray`, `${x,,}`, `${x^^}`, `declare -A`, `;&`, `;;&` or any other bash 4+ feature. `/bin/bash -n` checks syntax only; the `TIN_CAN_TEST_BASH=/bin/bash` bats run is the real check.
- In `bin/tin-can`, `hooks/tin-can-hook` and `install.sh`: POSIX `[ ]` tests, not `[[ ]]`. In bats tests, assert with `[[ ... ]] || return 1`. 2-space indent. Quote every expansion.
- Never interpolate handoff contents into a shell command. Build commands with the existing single-quoting helper.
- Paths with control, bidi or invisible characters are refused. Keep that behavior when you touch path handling.
- Keep the change small. Do not add dependencies to `bin/tin-can`. `jq` is needed only for the optional hooks.

## Reporting issues

Use the bug or feature template in `.github/ISSUE_TEMPLATE/`. For a bug, include the output of `bin/tin-can --dry-run` with a minimal handoff that reproduces the problem. Do not paste a real handoff file: handoffs can hold private details.

For security issues, follow [SECURITY.md](SECURITY.md). Do not open a public issue.

Participation is covered by the [Code of Conduct](CODE_OF_CONDUCT.md).
