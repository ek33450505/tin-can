# Snippet for your AGENTS.md (tin-can)

Add this to your `AGENTS.md` (Codex and other agents that read it) so the agent can prepare a handoff for a fresh session.

When the user asks to hand off, continue in a new session, or "tin-can" the work:

1. **Write a handoff file** as markdown with these sections:
   - `## KICKOFF` (required): what the fresh session should do first, as instructions to the reader; name which other sections to read before acting. The launcher's prompt is only "Read the handoff file at <path> and follow its KICKOFF section."
   - `## State` (branch, done, in flight), `## Next steps` (ordered, concrete), `## Constraints` (decisions and do-not-touch rules, with reasons), `## Verification` (commands that confirm the state and the finish line).

   Example:

   ```markdown
   # Handoff: widget-service retry logic

   ## KICKOFF
   Continue widget-service. Read State and Constraints, run Verification, then start at Next steps item 1.

   ## State
   - Branch `feature/retry-backoff`; jitter option uncommitted in `src/client/retry.ts`.

   ## Next steps
   1. Finish jitter and add a test in `src/client/retry.test.ts`.

   ## Constraints
   - Do not change the public `Client` constructor signature.

   ## Verification
   - `npm test -- retry` passes.
   ```

   Reference files by path, never paste secrets. Save it as `~/.claude/resume-prompts/YYYY-MM-DD-<repo>-<slug>.md`, or at a path the user names.
2. **Tell the user to launch it.** Reply with the absolute path, ask them to read the file first, then run `tin-can <path>` themselves (add `--agent codex` to start Codex, `--where window` for a new window, `--dry-run` to preview). The new session starts in the directory they run it from, so tell them to run it from the repository the handoff is for, or to add `--cwd <repo>`.

Do not run `tin-can` yourself and do not try to open terminal tabs or access terminal control sockets. The user triggers the launch.
