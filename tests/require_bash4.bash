# shellcheck shell=bash
# Guard for the bats suite: refuse to run when bats itself is on bash < 4.
# bash 3.2 ignores a failing non-final [[ ]] under set -e, so assertions
# written without `|| return 1` would pass vacuously.

require_bash4() {
  if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    {
      echo "tin-can tests: bats is running on bash $BASH_VERSION."
      echo "bash 3.2 ignores a failing non-final [[ ]], so assertions would be vacuous."
      echo "Run bats under bash >= 4 (put it first on PATH)."
      echo "TIN_CAN_TEST_BASH=/bin/bash still tests the script under 3.2."
    } >&2
    return 1
  fi
}
