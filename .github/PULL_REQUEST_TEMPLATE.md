## Description

## Checklist

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
