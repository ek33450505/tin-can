---
name: tin-can
description: Write a handoff file for the current work and tell the user how to launch a fresh session on it with tin-can.
---

# tin-can: hand off to a fresh session

Use this when the user asks to hand off, continue in a new session, or "tin-can" the current work.

## Step 1: write the handoff file

Write a markdown file with these sections:

- `## KICKOFF` (required): what the fresh session should do first, written as instructions to the reader. It must make sense on its own and name which other sections to read before acting. The launcher's prompt is only "Read the handoff file at <path> and follow its KICKOFF section."
- `## State`: branch, what is done, what is in flight, uncommitted changes. Facts, not narrative.
- `## Next steps`: ordered, concrete actions.
- `## Constraints`: decisions already made (with reasons) and do-not-touch rules.
- `## Verification`: commands that confirm the state is as described and show when the work is done.

Example:

```markdown
# Handoff: widget-service retry logic

## KICKOFF
Continue widget-service in a fresh session. Read State and Constraints, run the
Verification commands, then start at Next steps item 1.

## State
- Branch `feature/retry-backoff`, 3 commits ahead of `main`; jitter option uncommitted in `src/client/retry.ts`.

## Next steps
1. Finish jitter and cover it in `src/client/retry.test.ts`.

## Constraints
- Do not change the public `Client` constructor signature.

## Verification
- `git status --short` shows only `src/client/retry.ts` modified; `npm test -- retry` passes.
```

Reference files by path instead of pasting their contents. Never include secrets. Save it to `~/.claude/resume-prompts/YYYY-MM-DD-<repo>-<slug>.md` (today's date, the repository directory name, a short slug), or to the path the user names. Use the absolute path in your reply. If an older handoff for the same work exists in that directory, offer to rename it to `superseded-<name>.md`.

## Step 2: tell the user how to launch it

Do not run tin-can yourself, and do not try to open terminal tabs or reach any terminal control socket. The user starts the new session. Tell them to review the handoff file first, then run, in this session or any shell:

```
! tin-can <absolute path to the handoff file>
```

If the tin-can plugin hooks are installed, they also surface the launch line when the handoff is written; end your reply with it anyway.

Tell them to run it from the repository the handoff is for, or add `--cwd <repo>`; the new session starts in that directory.

Mention the options that may matter:

- `--agent codex` to start a different agent (default `claude`).
- `--where window` to open a new window/workspace instead of a tab.
- `--list` to see which handoffs `--latest` would consider.
- `--dry-run` to preview the command without launching anything.

If tin-can is not installed, say so and point to `install.sh` in the tin-can repository rather than working around it.
