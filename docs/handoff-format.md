# Handoff file format

A handoff file is a plain markdown file that one AI coding session writes so a
fresh session can pick the work up without the original conversation. `tin-can`
does not parse it: the launcher only passes the file's absolute path to the new
agent, and the new agent reads the file itself. The format below is a contract
between the writing agent and the reading agent.

## Required

A heading containing the word `KICKOFF` (conventionally `## KICKOFF`). Its body
is what the new session should do first, written as instructions to the
reader. The launcher's prompt is:

> Read the handoff file at `<path>` and follow its KICKOFF section.

so the KICKOFF section must make sense on its own and say which other sections
to read before acting.

## Recommended sections

| Section | Purpose |
|---|---|
| `## State` | What is done, what is in flight, current branch and uncommitted changes. Facts, not narrative. |
| `## Next steps` | Ordered, concrete actions, each small enough to finish and check. |
| `## Constraints` | Rules the next session must keep: do-not-touch files, policies, decisions already made and why. |
| `## Verification` | Commands that show the state is as described and how to tell the work is done. |

Keep it short enough to read in a minute. Link to files by path rather than
pasting their contents. Do not put secrets in a handoff file.

## Naming and location

With `--latest`, `tin-can` looks in `~/.claude/resume-prompts/` (override with
`--dir` or `$TIN_CAN_DIR`) and takes the newest `*.md`, skipping names that
start with `superseded-` or `_`, and preferring names that contain the
repository directory's name as a whole word (`-`, `_` and `.` are separators).
Auto-selection also refuses a group/world-writable directory and skips symlinks
and files you do not own. A convention that works with that:

```
~/.claude/resume-prompts/YYYY-MM-DD-<repo>-<slug>.md
```

Rename a stale handoff to `superseded-<name>.md` once a newer one replaces it.

## Example

```markdown
# Handoff: widget-service retry logic

## KICKOFF
You are continuing work on widget-service in a fresh session. Read State and
Constraints below, run the commands under Verification to confirm the tree
matches, then start at Next steps item 1. Ask before changing anything listed
under Constraints.

## State
- Branch: `feature/retry-backoff` (3 commits ahead of `main`, pushed)
- Done: exponential backoff in `src/client/retry.ts`; unit tests pass.
- In flight: jitter option, uncommitted in `src/client/retry.ts`.

## Next steps
1. Finish the jitter option and cover it in `src/client/retry.test.ts`.
2. Wire `retry.maxAttempts` through `src/config.ts`.
3. Update the README "Retries" paragraph.

## Constraints
- Do not change the public `Client` constructor signature.
- No new runtime dependencies.

## Verification
- `git status --short` shows only `src/client/retry.ts` modified.
- `npm test -- retry` passes before and after your changes.
```
