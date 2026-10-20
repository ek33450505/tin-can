---
name: Feature request
about: Suggest a change or addition
labels: enhancement
---

## What you want

## Why

## Proposed surface

Flags, terminal backend, agent, or hook behavior. New terminal backends and new agents are welcome: each is one branch in the script, plus one name. Say which ones you can test live.

## Constraints to honor

- You trigger the launch. tin-can never launches on its own; agents only print the command.
- bash 3.2 compatible.
- No new runtime dependencies for `bin/tin-can`. `jq` is needed only for the optional hooks.
- Terminal- and agent-agnostic.
- Never parse or interpolate handoff contents.
