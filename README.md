# tin-can

Hand an AI coding session off to a fresh session in a new terminal tab, without copy-paste.

`tin-can` opens a new terminal tab (cmux and tmux: a tab, a new workspace, or a detached tmux session), starts your agent CLI there, and gives it a single prompt: read this handoff file and follow its KICKOFF section. The name is the tin-can telephone: a message passed down a string.

It is a small bash script. It works with more than one agent and more than one terminal, and you trigger it yourself.

## Why

Long sessions fill their context. The usual fix is to summarise the work, open a new tab, start the agent, and paste the summary in. `tin-can` makes that one command: the old session writes a handoff file, you run `tin-can`, and the fresh session starts already pointed at it.

## Install

From a clone of this repository (symlinks only, no copying, no sudo):

```bash
./install.sh              # links bin/tin-can into ~/.local/bin and the skill into ~/.claude/skills
./install.sh --uninstall  # removes links that point exactly at this checkout's files
./install.sh --force      # repoint an existing symlink that points somewhere else
```

Override locations with `TIN_CAN_BIN_DIR` and `CLAUDE_SKILLS_DIR`. The installer will not overwrite a regular file or directory, and refuses a symlink that points elsewhere unless you pass `--force`. Make sure `~/.local/bin` is on your `PATH`. Requires bash 3.2 or newer (the macOS system bash works).

Because these are symlinks, the live `tin-can` binary and the auto-loaded `SKILL.md` are the files in your checkout: anything that can write to that directory (a `git pull`, another tool, an agent) changes what runs and what Claude Code is told. Treat the checkout like any other code you execute.

## Usage

```bash
tin-can                         # newest handoff in ~/.claude/resume-prompts, preferring this repo's
tin-can path/to/handoff.md      # a specific file
tin-can --agent codex           # start Codex instead of Claude Code
tin-can --where window          # new window/workspace (cmux) or detached session (tmux) instead of a tab
tin-can --term print            # just print the command to paste into a tab yourself
tin-can --dry-run               # show which file and what command, launch nothing
```

Inside Claude Code, run it with the `!` prefix so it runs in your shell: `! tin-can`.

Options: `--agent`, `--term`, `--where`, `--cwd`, `--dir`, `--dry-run`, `--version`, `--help`. Option values must be non-empty and not start with `-`. Use `--` before a file name that starts with `-`. Environment defaults: `TIN_CAN_AGENT`, `TIN_CAN_TERM`, `TIN_CAN_DIR`.

With no file argument, `tin-can` takes the newest `*.md` in the search directory, skips names starting with `superseded-` or `_`, and prefers files whose name contains the working directory's name as a whole word (`-`, `_` and `.` count as separators, so `cast` matches `2026-10-12-cast-next.md` but not `broadcast-plan.md`). It reports the choice on stderr. Exit codes: `0` ok, `1` launch failure (the paste-able command is printed as a fallback), `2` usage or handoff error. A path containing any of the following is refused with exit 2 when it is given explicitly (`--cwd`, `--dir`, an explicit `HANDOFF_FILE`), and the file is silently skipped when it is only an auto-selection candidate (the error says how many were skipped if nothing else qualifies): ASCII control characters (0x01-0x1F, including tab, newline, CR and ESC, and DEL 0x7F); C1 controls (U+0080-U+009F); Unicode line and paragraph separators (U+2028, U+2029); bidirectional embeddings and overrides (U+202A-U+202E); or bidirectional isolates (U+2066-U+2069). Ordinary non-ASCII text (accents, CJK, emoji) is accepted. Files with equal modification times are taken in file-name order.

The handoff file is an ordinary markdown file with a `## KICKOFF` section; see [docs/handoff-format.md](docs/handoff-format.md). The bundled Claude Code skill (`skills/tin-can`) and the [AGENTS.md](AGENTS.md) snippet teach an agent to write one and tell you the command to run.

## Supported terminals and agents

| | Status |
|---|---|
| Terminal: cmux (tab = new surface, window = new workspace) | Pending live verification (stub-tested) |
| Terminal: tmux (tab = new window; window = a new detached session, `tmux attach -t NAME` printed) | Tested with stubs only |
| Terminal: print (any terminal; copy the command) | Tested; no terminal involved |
| Agent: Claude Code (`claude`) | Pending live verification (stub-tested) |
| Agent: Codex (`codex`) | Tested with stubs only |

Adding an agent is one name in `SUPPORTED_AGENTS` (plus a `case` branch in `agent_binary` if its binary name differs); adding a terminal is one branch where the launch command is built. `--term auto` picks cmux when `$CMUX_WORKSPACE_ID` is set and `cmux` is on `PATH`, then tmux when `$TMUX` is set and `tmux` is on `PATH`, else print.

The command run in the new terminal is `cd 'DIR' && exec 'AGENT' 'PROMPT'`, built with POSIX single-quoting, so it is valid in the POSIX sh family (sh, dash, bash) and in zsh. fish and csh/tcsh are not supported as the shell that receives the command.

## Trust model

- You run it. An agent never needs access to a terminal's control socket. The bundled skill and `AGENTS.md` tell an agent to ask you to run the command; that is an instruction, not a technical control. An agent's shell inherits `CMUX_WORKSPACE_ID` or `TMUX`, so sandboxing and permission settings are the real barrier against an agent launching sessions itself.
- The only text given to the new agent is `Read the handoff file at <absolute path> and follow its KICKOFF section.` as a single argument.
- File contents are never interpolated into a shell command. The directory, agent name and prompt are each single-quoted, and paths with control characters are refused outright. The test suite round-trips paths containing spaces, quotes, `$`, backticks, glob and shell metacharacters, a leading `-`, and non-ASCII text (including under `LC_ALL=C`) through bash, zsh and dash.
- **Whoever can write into the handoff directory steers the next session.** The new agent will read the chosen file and may act on it. Auto-selection picks the newest file, or the newest whose name contains the repository name, so a file dropped into that directory can win. Mitigations in the tool: auto-selection refuses a directory that is group- or world-writable or not owned by you, and skips symlinks and files not owned by you; an explicit file that is a symlink, not yours, or inside a group- or world-writable directory prints a warning. There is no interactive confirmation, because `! tin-can` has no terminal to ask on.
- Read the handoff before launching it, especially one written by an agent: run `tin-can --dry-run` to see which file would be used, then open it.

## Known limitations

- The directory check uses POSIX permission bits and ownership only. It does not see macOS ACLs (an `ls -ld` entry ending in `+`) or other extended access controls.
- Newest means newest modification time; files with equal times are taken in file-name order.
- Processes running as your own user, including a compromised agent, can still plant a file you own in the handoff directory. Ownership checks do not help there: review the file with `--dry-run` before launching.
- The "not owned by you" paths are not covered by tests (see Development).

## Development

```bash
bats tests/              # needs bats-core; uses stub cmux/tmux/claude/codex and a temp HOME
shellcheck bin/tin-can install.sh tests/helpers.bash
TIN_CAN_TEST_BASH=/bin/bash bats tests/   # run the suite under macOS bash 3.2
shfmt -d -i 2 -ci bin/tin-can install.sh tests/helpers.bash   # style: 2-space indent, indented case
```

The "not owned by you" checks need a file owned by another user, which needs root to create, so those paths are not covered by tests.

## Related projects

Other tools approach the same problem, mostly aimed at Claude Code and tmux:

- [392fyc/claude-handoff](https://github.com/392fyc/claude-handoff)
- [rinman24/claude-skills](https://github.com/rinman24/claude-skills) (`handoff`)
- [fuzzyfox/skills](https://github.com/fuzzyfox/skills) (`spawn`)

`tin-can` aims to be agent- and terminal-agnostic, at the cost of doing less: it does not write the handoff for you and it does not parse it.

## License

MIT. See [LICENSE](LICENSE).
