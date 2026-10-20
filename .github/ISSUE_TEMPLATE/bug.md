---
name: Bug report
about: Something tin-can did wrong
labels: bug
---

## What happened

## What you expected

## To reproduce

Use a minimal handoff file that reproduces the problem. Do not paste a real handoff: handoffs can hold private details.

```bash
tin-can --dry-run /path/to/minimal-handoff.md
```

## Environment

```bash
tin-can --version
sw_vers            # macOS; or: lsb_release -a  (Linux)
bash --version | head -1
jq --version       # only if the plugin hook is installed
claude --version   # or: codex --version
```

- Terminal and version (cmux / tmux / Zellij / WezTerm / kitty / other):
- Claude Code plugin installed? (y/n):

## Output

```
paste the output of tin-can --dry-run here (redact your username if you like)
```
