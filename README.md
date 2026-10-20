# tin-can

Hand an AI coding session off to a fresh session in a new terminal tab, without copy-paste.

[![CI](https://github.com/ek33450505/tin-can/actions/workflows/ci.yml/badge.svg)](https://github.com/ek33450505/tin-can/actions/workflows/ci.yml) [![Release](https://img.shields.io/github/v/release/ek33450505/tin-can)](https://github.com/ek33450505/tin-can/releases) [![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

`tin-can` opens a new terminal tab (in cmux, tmux, Zellij, WezTerm or kitty; or prints the command for any other terminal), starts your agent CLI there, and gives it a single prompt: read this handoff file and follow its KICKOFF section. The name is the tin-can telephone: a message passed down a string.

It is a small bash script. It works with more than one agent and more than one terminal, and you trigger it yourself.

## Quick start

1. Install with Homebrew, `brew install ek33450505/tin-can/tin-can`, or clone the repository and run the installer:

   ```bash
   git clone https://github.com/ek33450505/tin-can
   cd tin-can
   ./install.sh
   ```

   If you will install the Claude Code plugin, use `./install.sh --no-skill` (see [Claude Code plugin](#claude-code-plugin-optional)).
2. In your agent session, ask it to write a handoff. In Claude Code, the bundled `tin-can` skill does this. For other agents, add [docs/agents-snippet.md](docs/agents-snippet.md) to your AGENTS.md. tin-can does not write the handoff; the agent does.
3. The agent gives you the command to run: `! tin-can '<path>'` in Claude Code, `tin-can '<path>'` in your shell elsewhere. Run it, or run `tin-can --latest` from the repository.
4. A new tab opens. The agent in it reads the handoff and follows its KICKOFF section.

## Example

This example runs `tin-can` inside `~/src/widget-service`. `~/.claude/resume-prompts` holds three handoffs, one auto-generated `-auto.md` scaffold and one `superseded-` file. The output below comes from tin-can 0.2.0, run in a temporary HOME; only the home prefix was replaced with `/Users/you`. The terminal shows as `print` because the demo ran outside any supported terminal, so `--term auto` fell back to printing the command.

```text
$ tin-can --list
tin-can: handoffs in /Users/you/.claude/resume-prompts, newest first (* = --latest would pick it, + = named for widget-service)
    2026-10-20-docs-site-nav.md
* + 2026-10-19-widget-service-retry.md
    2026-10-18-billing-api-invoices.md
skipped: 2 by name (superseded-*, _*, *-auto.md)

$ tin-can --latest --dry-run
tin-can: using /Users/you/.claude/resume-prompts/2026-10-19-widget-service-retry.md
tin-can dry-run (nothing launched)
  agent:   claude
  term:    print (tab)
  cwd:     /Users/you/src/widget-service
  handoff: /Users/you/.claude/resume-prompts/2026-10-19-widget-service-retry.md
  launch:  (print only)
  command: cd '/Users/you/src/widget-service' && exec 'claude' 'Read the handoff file at /Users/you/.claude/resume-prompts/2026-10-19-widget-service-retry.md and follow its KICKOFF section.'
```

`--latest` picks `2026-10-19-widget-service-retry.md` even though `2026-10-20-docs-site-nav.md` is newer, because the file is named for the repository. The `-auto.md` scaffold and the `superseded-` file are skipped by name, which is why the listing reports two skipped files.

## Why

Long sessions fill their context. The usual fix is to summarise the work, open a new tab, start the agent, and paste the summary in. `tin-can` makes that one command: the old session writes a handoff file, you run `tin-can`, and the fresh session starts already pointed at it.

## How it works

1. The old session's agent writes a markdown handoff with a `## KICKOFF` section. The format is in [docs/handoff-format.md](docs/handoff-format.md).
2. You run `tin-can <file>` or `tin-can --latest`. Inside Claude Code, run it as `! tin-can <file>` so it runs in your shell.
3. tin-can resolves and checks the path, picks the terminal (the `--term auto` order is in [Supported terminals and agents](#supported-terminals-and-agents)), and runs `cd 'DIR' && exec 'AGENT' 'PROMPT'` in a new tab (or a new window with `--where window`). With `--term print` it prints that command instead.
4. The new agent's only prompt is `Read the handoff file at <absolute path> and follow its KICKOFF section.` The agent reads the file itself. tin-can never parses the handoff.

## Install

With Homebrew:

```bash
brew install ek33450505/tin-can/tin-can
```

This installs the `tin-can` command. For the Claude Code skill and hooks, add the [plugin](#claude-code-plugin-optional); `brew info tin-can` shows how to link the skill without it. The tap is [ek33450505/homebrew-tin-can](https://github.com/ek33450505/homebrew-tin-can).

From a clone of this repository (symlinks only, no copying, no sudo):

```bash
./install.sh              # links bin/tin-can into ~/.local/bin and the skill into ~/.claude/skills
./install.sh --no-skill   # link only the binary (the Claude Code plugin provides the skill)
./install.sh --uninstall  # removes links that point exactly at this checkout's files
./install.sh --force      # repoint an existing symlink that points somewhere else
```

Override locations with `TIN_CAN_BIN_DIR` and `CLAUDE_SKILLS_DIR`. The installer will not overwrite a regular file or directory, and refuses a symlink that points elsewhere unless you pass `--force`. Make sure `~/.local/bin` is on your `PATH`. Requires bash 3.2 or newer (the macOS system bash works).

Because these are symlinks, the live `tin-can` binary and the auto-loaded `SKILL.md` are the files in your checkout: anything that can write to that directory (a `git pull`, another tool, an agent) changes what runs and what Claude Code is told. Treat the checkout like any other code you execute.

## Claude Code plugin (optional)

The plugin adds the skill plus three hooks that make handoffs harder to forget:

- After a handoff is written to the handoff dir, it surfaces `! tin-can '<path>'`: as a message to you, and as a line the model is asked to end its reply with.
- On a wrap-up phrase ("let's wrap up", "call it a day", "done for today"...), it asks the model to write a handoff if work is unfinished.
- At the end of such a turn, if git shows uncommitted or unpushed work and no handoff was written, it asks once per session.

Installing the plugin means Claude Code runs `hooks/tin-can-hook` automatically, as you, on every prompt, every Write/Edit/MultiEdit and every turn end. Read the script before you install it. The hooks only print a command or advise the model; they never launch anything.

Install the binary first, with Homebrew or with `./install.sh --no-skill` (see Install above; the `! tin-can` line the hooks print needs `tin-can` on your shell's `PATH`). Then add the plugin, pinned to a release tag (recommended):

```
/plugin marketplace add ek33450505/tin-can#v0.2.1
/plugin install tin-can@tin-can
```

An unpinned `/plugin marketplace add ek33450505/tin-can` follows the default branch. Updates reach you only when the plugin's version changes, through `/plugin marketplace update tin-can` or auto-update if you enable it.

Use `--no-skill` because the plugin provides the skill, and you don't want two copies.

Requires `jq` (without it the hooks silently do nothing). `TIN_CAN_HOOKS=0` disables the hooks.

Limits:

- A hard `/exit` or closing the tab gives the model no turn, so no hook can force a handoff.
- The git check only sees the session's working directory.
- Wrap-up detection is a phrase list: it misses other wordings, and "wrap it up, then ..." can match.
- It nudges at most once per session.
- Claude Code's docs don't confirm that a PostToolUse hook's `systemMessage` is displayed. The same command is also given to the model so it ends its reply with it.

## Usage

```bash
tin-can path/to/handoff.md                # a specific file
tin-can --latest                          # newest handoff in ~/.claude/resume-prompts, preferring this repo's
tin-can --list                            # see which handoffs `--latest` would consider
tin-can --agent codex handoff.md          # start Codex instead of Claude Code
tin-can --where window handoff.md         # new window (cmux workspace, WezTerm/kitty window) or detached session (tmux, Zellij)
tin-can --term print handoff.md           # just print the command to paste into a tab yourself
tin-can --dry-run handoff.md              # show which file and what command, launch nothing
```

Inside Claude Code, run it with the `!` prefix so it runs in your shell: `! tin-can <file>`.

The new session starts in the current directory (`--cwd` sets another). `tin-can` warns on stderr, and still launches, when the handoff is neither inside that directory nor named for it. This catches mistakes; it is not a security check, since a file can simply be named after the repository.

Options: `--agent`, `--term`, `--where`, `--cwd`, `--dir`, `--latest`, `--list`, `--dry-run`, `--version`, `--help`. Option values must be non-empty and not start with `-`. Use `--` before a file name that starts with `-`. Environment defaults: `TIN_CAN_AGENT`, `TIN_CAN_TERM`, `TIN_CAN_DIR`.

The handoff file is an ordinary markdown file with a `## KICKOFF` section; see [docs/handoff-format.md](docs/handoff-format.md). The bundled Claude Code skill (`skills/tin-can`) and the [agents snippet](docs/agents-snippet.md) teach an agent to write one and tell you the command to run.

### Choosing a handoff with --latest

With `--latest` instead of a file, `tin-can` takes the newest `*.md` in the search directory, skips names starting with `superseded-` or `_` and names ending in `-auto.md` (auto-generated resume scaffolds), and prefers files whose name contains the working directory's name as a whole word (`-`, `_` and `.` count as separators, so `cast` matches `2026-10-12-cast-next.md` but not `broadcast-plan.md`). Files with equal modification times are taken in file-name order. It reports the choice on stderr. With neither a file nor `--latest` it exits 2 rather than guess; giving both is also an error.

### Exit codes

- `0`: ok.
- `1`: launch failure. The paste-able command is printed as a fallback.
- `2`: usage or handoff error.

### Refused paths

A path containing any of the following is refused with exit 2 when it is given explicitly (`--cwd`, `--dir`, an explicit `HANDOFF_FILE`). When it is only an auto-selection candidate, the file is silently skipped; the error says how many were skipped if nothing else qualifies.

- ASCII control characters (0x01-0x1F, including tab, newline, CR and ESC, and DEL 0x7F)
- C1 controls (U+0080-U+009F)
- Unicode line and paragraph separators (U+2028, U+2029)
- bidirectional embeddings and overrides (U+202A-U+202E)
- bidirectional isolates (U+2066-U+2069)
- the left-to-right, right-to-left and Arabic letter marks (U+200E, U+200F, U+061C)
- Unicode tag characters (U+E0000-U+E007F)
- invisible characters: soft hyphen (U+00AD), zero-width space (U+200B), word joiner (U+2060), zero-width no-break space (U+FEFF), Hangul fillers (U+115F, U+1160, U+3164, U+FFA0), Mongolian vowel separator (U+180E) and the variation selectors supplement (U+E0100-U+E01FF)
- lookalike spaces (U+00A0, U+2000-U+200A, U+202F, U+205F, U+3000)

Other non-ASCII text (letters with accents, CJK ideographs, emoji) is accepted, including the zero-width joiner and non-joiner (U+200D, U+200C) and the variation selectors U+FE00-U+FE0F, which emoji sequences and some scripts need.

## Supported terminals and agents

| | Status |
|---|---|
| Terminal: cmux (tab = new surface, window = new workspace) | Tab verified live (cmux 0.65.0, 2026-10-13); window stub-tested |
| Terminal: tmux (tab = new window; window = a new detached session, `tmux attach -t NAME` printed) | Tested with stubs only |
| Terminal: Zellij (tab = `zellij action new-tab`; window = a new detached session, `zellij attach NAME` printed) | Tested with stubs only; the argv matches zellij's CLI definitions (`new-tab` and `attach` take a trailing command after `--`); behavior on older zellij versions is unknown |
| Terminal: WezTerm (tab = `wezterm cli spawn`; window = `--new-window`) | Tested with stubs only |
| Terminal: kitty (tab = `kitten @ launch --type=tab`; window = `--type=os-window`; needs kitty remote control, see below) | Tested with stubs only |
| Terminal: print (any terminal; copy the command) | Tested; no terminal involved |
| Agent: Claude Code (`claude`) | Verified live (Claude Code 2.1.296, 2026-10-13) |
| Agent: Codex (`codex`) | Tested with stubs only |

Adding an agent is one name in `SUPPORTED_AGENTS` (plus a `case` branch in `agent_binary` if its binary name differs); adding a terminal is one branch where the launch command is built. `--term auto` picks cmux when `$CMUX_WORKSPACE_ID` is set and `cmux` is on `PATH`, then tmux when `$TMUX` is set and `tmux` is on `PATH`, then Zellij when `$ZELLIJ` is set (any value, including `0`) and `zellij` is on `PATH`, then WezTerm when `$WEZTERM_PANE` is set and `wezterm` is on `PATH`, then kitty when `$KITTY_WINDOW_ID` is set and `kitten` is on `PATH`, else print. kitty needs remote control enabled. Prefer `allow_remote_control socket-only` plus `listen_on unix:/tmp/kitty` in kitty.conf: kitty then sets `KITTY_LISTEN_ON` for its child shells, which `kitten @` uses. `allow_remote_control yes` also works but is broader: any process in any kitty window, including escape sequences printed by `cat`-ing a hostile file, can then drive kitty. Without remote control the launch fails and tin-can prints the paste-able command. See https://sw.kovidgoyal.net/kitty/remote-control/.

The command run in the new terminal is `cd 'DIR' && exec 'AGENT' 'PROMPT'`, built with POSIX single-quoting, so it is valid in the POSIX sh family (sh, dash, bash) and in zsh. fish and csh/tcsh are not supported as the shell that receives the command.

## Trust model

- You run it. An agent never needs access to a terminal's control socket. The bundled skill and the agents snippet (`docs/agents-snippet.md`) tell an agent to ask you to run the command; that is an instruction, not a technical control. An agent's shell inherits `CMUX_WORKSPACE_ID`, `TMUX`, `ZELLIJ`, `WEZTERM_PANE`, `KITTY_WINDOW_ID`, `WEZTERM_UNIX_SOCKET` or `KITTY_LISTEN_ON`, so sandboxing and permission settings are the real barrier against an agent launching sessions itself.
- The only text given to the new agent is `Read the handoff file at <absolute path> and follow its KICKOFF section.` as a single argument.
- File contents are never interpolated into a shell command. The directory, agent name and prompt are each single-quoted, and paths with control characters are refused outright. The test suite round-trips paths containing spaces, quotes, `$`, backticks, glob and shell metacharacters, a leading `-`, and non-ASCII text (including under `LC_ALL=C`) through bash, zsh and dash.
- **Whoever can write into the handoff directory steers the next session.** The new agent will read the chosen file and may act on it. `--latest` picks the newest file, or the newest whose name contains the repository name, so a file dropped into that directory can win. Mitigations in the tool: auto-selection refuses a directory that is group- or world-writable or not owned by you, and skips symlinks and files not owned by you; an explicit file that is a symlink, not yours, or inside a group- or world-writable directory prints a warning. There is no interactive confirmation, because `! tin-can` has no terminal to ask on.
- `--dry-run` shows the directory, handoff and launch arguments escaped, and the `command:` line raw so it can be pasted. When that command, or the one printed by `--term print` or after a failed launch, contains non-ASCII characters, a note on stderr says so. A failed launch's error output is indented and shown with every byte other than printable ASCII, newline and tab replaced by `?`.
- The optional plugin hooks run automatically, but they only print a command or ask the model to write a handoff. They never launch a session, and `TIN_CAN_HOOKS=0` turns them off.
- Read the handoff before launching it, especially one written by an agent: with `--latest`, run `tin-can --latest --dry-run` first to see which file would be used, then open it.

To report a vulnerability, see [SECURITY.md](SECURITY.md).

## Known limitations

- The directory check uses POSIX permission bits and ownership only. It does not see macOS ACLs (an `ls -ld` entry ending in `+`) or other extended access controls.
- Newest means newest modification time; files with equal times are taken in file-name order.
- Some blank-looking characters are still accepted in paths, for example U+2800 (Braille pattern blank), U+1680 (Ogham space mark) and U+206A-U+206F. They cannot inject terminal or shell text, and displayed paths show them escaped, but two names can look alike: check the escaped path in `--dry-run` or `--list` output.
- Processes running as your own user, including a compromised agent, can still plant a file you own in the handoff directory. Ownership checks do not help there: review the file with `--latest --dry-run` before launching.
- The "not owned by you" paths are not covered by tests (see Development).

## FAQ

**Does tin-can write the handoff?**
No. Your agent writes it, guided by the bundled skill or the [agents snippet](docs/agents-snippet.md). tin-can only launches the new session.

**Why doesn't the agent launch the new session itself?**
That is a trust decision: you trigger the launch. An agent's sandbox and permission settings are the real barrier, and `! tin-can` runs in your shell. See [Trust model](#trust-model).

**My terminal isn't supported. What now?**
Use `--term print`. It prints a command you can paste into a tab yourself. tin-can also prints that command after a failed launch.

**Does it work with Codex?**
Codex can be started with `--agent codex` or `TIN_CAN_AGENT=codex`. Codex support is tested with stubs only.

**Why did `--latest` pick an older file?**
`--latest` prefers names that contain the working directory's name as a whole word, so an older file named for this repository can win over a newer one. Run `tin-can --list` to see what it would consider and which file it would pick.

**Do I need the Claude Code plugin?**
No. The plugin adds the skill and three hooks that make handoffs harder to forget. `install.sh` links the `tin-can` binary either way.

**What if I just `/exit`?**
No hook can force a handoff then, because the model gets no turn. Ask for the handoff before you exit.

**Which shells can receive the command?**
sh, dash, bash and zsh. fish and csh/tcsh are not supported.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md).

```bash
bats tests/              # needs bats-core; uses stub cmux/tmux/zellij/wezterm/kitten/claude/codex and a temp HOME
shellcheck --shell=bash bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash
TIN_CAN_TEST_BASH=/bin/bash bats tests/   # run the script under test on macOS bash 3.2 (bats itself stays on bash >= 4)
shfmt -d -i 2 -ci bin/tin-can install.sh hooks/tin-can-hook tests/helpers.bash tests/require_bash4.bash   # style: 2-space indent, indented case
```

bats itself must run on bash >= 4: under bash 3.2 every test fails in setup with an explanation, because bash 3.2 would make assertions vacuous. `TIN_CAN_TEST_BASH=/bin/bash` still covers the script under 3.2. The "not owned by you" checks need a file owned by another user, which needs root to create, so those paths are not covered by tests.

## Related projects

Other tools approach the same problem, mostly aimed at Claude Code and tmux:

- [392fyc/claude-handoff](https://github.com/392fyc/claude-handoff)
- [rinman24/claude-skills](https://github.com/rinman24/claude-skills) (`handoff`)
- [fuzzyfox/skills](https://github.com/fuzzyfox/skills) (`spawn`)

`tin-can` aims to be agent- and terminal-agnostic, at the cost of doing less: it does not write the handoff for you and it does not parse it.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT. See [LICENSE](LICENSE).
