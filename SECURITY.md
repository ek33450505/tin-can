# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.2.x   | Full support |
| < 0.2   | Not supported. Upgrade to the latest release. |

## Reporting a Vulnerability

**Do NOT open a public GitHub issue for security vulnerabilities.**

Report privately through GitHub's security advisories:
https://github.com/ek33450505/tin-can/security/advisories/new

### What to Include

- tin-can version (`tin-can --version`)
- OS (`sw_vers` on macOS, `lsb_release -a` on Linux)
- Terminal and its version (cmux, tmux, Zellij, WezTerm or kitty)
- Agent CLI and its version (Claude Code or Codex)
- Which file is involved (`bin/tin-can`, `hooks/tin-can-hook` or `install.sh`)
- Steps to reproduce
- Impact

`--dry-run` output contains absolute paths. Redact your username if you like.

### Response Timeline

| Severity | Acknowledgement | Fix target |
|----------|-----------------|------------|
| Critical | 48 hours | 14 days |
| High | 48 hours | 30 days |
| Medium / Low | 5 business days | Next release |

tin-can is maintained by one person. These are targets, not guarantees.

## Security Design Notes

- **The user runs it.** An agent never needs access to a terminal's control socket. The bundled skill and the agents snippet tell an agent to ask the user to run the command. That is an instruction, not a technical control. An agent's shell inherits `CMUX_WORKSPACE_ID`, `TMUX`, `ZELLIJ`, `WEZTERM_PANE`, `KITTY_WINDOW_ID`, `WEZTERM_UNIX_SOCKET` or `KITTY_LISTEN_ON`, so sandboxing and permission settings are the real barrier against an agent launching sessions itself.
- **Fixed command shape.** The only text given to the new agent is `Read the handoff file at <absolute path> and follow its KICKOFF section.`, passed as a single argument. File contents are never interpolated into a shell command. The directory, agent name and prompt are each POSIX single-quoted. The command is `cd 'DIR' && exec 'AGENT' 'PROMPT'`, valid in sh, dash, bash and zsh. fish, csh and tcsh are unsupported as the receiving shell.
- **Refused characters.** Paths containing control characters (ASCII 0x01-0x1F and 0x7F, C1 U+0080-U+009F), line or paragraph separators, bidi embeddings, overrides, isolates or marks, Unicode tag characters, invisible characters (U+00AD, U+200B, U+2060, U+FEFF), or lookalike spaces are refused (exit 2) when given explicitly. They are skipped when they are only an auto-selection candidate. The list is not exhaustive: other non-ASCII characters are accepted, including some invisible ones such as the zero-width joiner and non-joiner (U+200D, U+200C, which emoji sequences and some scripts need), U+2061-U+2064, Hangul fillers and variation selectors. Displayed paths show them escaped.
- **The handoff directory steers the next session.** Whoever can write into the handoff directory controls what the next session reads. `--latest` picks the newest file, preferring names that contain the repo name, so a planted file can win. Auto-selection refuses a directory that is group- or world-writable or not owned by the user. It skips symlinks and files not owned by the user. An explicit file that is a symlink, not owned by the user, or in a group- or world-writable directory prints a warning. There is no interactive confirmation, because `! tin-can` has no terminal to ask on. Run `tin-can --latest --dry-run` and read the file before launching.
- **Escaped output.** Failed-launch error output is shown with every byte other than printable ASCII, newline and tab replaced by `?`. `--dry-run` shows paths escaped; its `command:` line stays raw so it can be pasted.
- **Optional plugin hooks.** The Claude Code plugin hooks (`hooks/tin-can-hook`) run automatically as the user on every prompt, every Write/Edit/MultiEdit and every turn end. They print a command, add context for the model, or block one turn end per session (the Stop hook) so the model gets another turn. To decide, they run `jq`, local `git` commands and `tin-can --dry-run`. They never start an agent session or open a terminal. They fail open: any problem gives exit 0 and no output. They need `jq`. `TIN_CAN_HOOKS=0` disables them. Per-session state lives under `${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}}/tin-can-hook/<session_id>/`. The hook creates these directories with mode 0700; an existing directory is accepted if it is a real directory (not a symlink) owned by the user. Session ids must match `[A-Za-z0-9_-]{1,64}`.
- **Install footprint.** `install.sh` only creates symlinks into `~/.local/bin` and `~/.claude/skills`, plus those directories if they are missing. It does not copy files and does not use sudo. The live binary and skill are the checkout's files, so anything that can write to the checkout changes what runs.
- **No network.** tin-can, the hook and `install.sh` make no network requests, and the hook's `git` commands do not fetch. They handle no credentials. The agent CLI that tin-can starts makes its own network requests.

## Out of Scope

- Vulnerabilities in the agent CLIs: Claude Code (https://www.anthropic.com/security) and Codex (OpenAI).
- Vulnerabilities in the terminals (cmux, tmux, Zellij, WezTerm, kitty), or in bash, jq or git.
- The contents of handoff files the user chooses to launch.
- An agent that ignores the "ask the user" instruction when its sandbox lets it reach a terminal socket.

## Trust Model

- **The user is trusted.** The user runs tin-can and decides what it launches.
- **The chosen handoff file is trusted.** tin-can does not inspect its contents; the new agent reads it and may act on it. Read it before launching.
- **tin-can does not stop an agent from launching sessions.** An agent that can reach a terminal's control socket can open tabs itself. Only the agent CLI's sandbox and permission settings prevent that.

### Known Limitations

- The directory check uses POSIX permission bits and ownership only. It does not check macOS ACLs.
- Processes running as the same user, including a compromised agent, can plant a file that the user owns. Ownership checks do not help against them.
- The "not owned by you" paths are not covered by tests, because creating such files needs root.
