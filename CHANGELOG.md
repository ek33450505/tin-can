# Changelog

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) loosely. Versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html); in 0.x, minor bumps may change behavior.

## [Unreleased]

## [0.2.1] — 2026-10-20

### Changed
- **Behavior change:** paths containing the soft hyphen (U+00AD), zero-width space (U+200B), word joiner (U+2060) or zero-width no-break space (U+FEFF), which were accepted before, are now refused like the other disguising characters: exit 2 when given explicitly, skipped when they are only an auto-selection candidate. The zero-width joiner and non-joiner (U+200D, U+200C) are still accepted, because emoji sequences and some scripts need them.
- README reorganised: quick start, example output, how it works, FAQ. The release history moved here from the README.
- `AGENTS.md` at the repository root now holds instructions for contributors. If you copied or linked the snippet for your own `AGENTS.md`, it is now `docs/agents-snippet.md`.

### Added
- CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, issue and pull request templates, and contributor instructions in AGENTS.md, imported by `.claude/CLAUDE.md` (the snippet for your own AGENTS.md moved to docs/agents-snippet.md).

### Fixed
- The plugin hook checks session ids byte by byte. Under macOS's bash 3.2 in a UTF-8 locale it accepted ids containing non-ASCII letters such as `é` and created state directories with those names.

## [0.2.0] — 2026-10-20

### Changed
- **Behavior change:** tin-can now warns on stderr, and still launches, when the handoff is neither inside the directory the session will start in nor named for the repository (for example a `--latest` pick from `~/.claude/resume-prompts` that is named for another repo).
- `--list` shows the newest 10 handoffs that `--latest` would consider, marks the one it would pick (`*`, shown even when older) and those named for the repository (`+`), and counts files skipped by name or as unsafe. It exits 0 for a listing, including an empty one, and 2 when the search directory is missing or unsafe.
- `--term auto` checks cmux, tmux, Zellij, WezTerm, kitty, then print, each by its environment variable and a binary on `PATH`. Inside Zellij, WezTerm or kitty it now opens a tab where it used to print the command.
- `install.sh --no-skill` links only the binary, and `install.sh` is now executable.
- `--help` lists the new terminals and `--list`, and says that `--dry-run` shows paths escaped.

### Added
- New terminal backends, tested with stubs only: Zellij (a tab, or a detached session for `--where window`), WezTerm, and kitty (which needs remote control enabled).
- An optional Claude Code plugin bundles the skill with three hooks that run in every session, on every prompt, Write/Edit/MultiEdit and turn end (they need `jq`; `TIN_CAN_HOOKS=0` turns them off; the `tin-can` binary still comes from `install.sh`):
  - When a handoff is written directly into the handoff directory, they surface `! tin-can '<path>'` to you and to the model.
  - On a wrap-up phrase, they ask for a handoff if work is unfinished.
  - At the end of that turn, if git shows uncommitted or unpushed work and the reply has no `! tin-can` line and no handoff was written, they ask once more, at most once per session.

## [0.1.2] — 2026-10-20

### Changed
- **Behavior changes:** some paths that used to work are now refused, and `--dry-run` prints paths in a different form (details in the bullets below).
- `--latest` skips names ending in `-auto.md` (auto-generated resume scaffolds). An explicit `HANDOFF_FILE` with that ending is still accepted.
- Paths containing Unicode tag characters (U+E0000-U+E007F) or lookalike spaces (U+00A0, U+2000-U+200A, U+202F, U+205F, U+3000), which were accepted before, are now refused like the other disguising characters.
- A failed launch's error output is indented and shown with every byte other than printable ASCII, newline and tab replaced by `?`.
- `--dry-run` shows the directory, handoff and launch arguments escaped, so an ordinary path with a space now appears as `my\ project`. The `command:` line stays raw so it can be pasted, and a stderr note flags a command containing non-ASCII characters (also with `--term print` and after a failed launch).
- If bats itself runs on bash 3.2, every test now fails in setup with an explanation.

## [0.1.1] — 2026-10-14

### Changed
- **Breaking:** auto-selecting the newest handoff now needs `--latest`. A bare `tin-can`, or `tin-can --dry-run` without a file, exits 2 instead of guessing, and giving both a file and `--latest` also exits 2.
- The left-to-right, right-to-left and Arabic letter marks (U+200E, U+200F, U+061C) are refused in paths like the other bidi controls.
- Paths in tin-can's own error and warning messages, and in the `using` line, are shown shell-escaped (`printf %q`).

## [0.1.0] — 2026-10-12

### Added
- Launch a fresh agent session (Claude Code or Codex) in a new cmux or tmux tab, or print the command, pointed at a handoff file.

[Unreleased]: https://github.com/ek33450505/tin-can/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/ek33450505/tin-can/releases/tag/v0.2.1
[0.2.0]: https://github.com/ek33450505/tin-can/releases/tag/v0.2.0
[0.1.2]: https://github.com/ek33450505/tin-can/releases/tag/v0.1.2
[0.1.1]: https://github.com/ek33450505/tin-can/releases/tag/v0.1.1
[0.1.0]: https://github.com/ek33450505/tin-can/tree/e112fa4
