#!/usr/bin/env bash
# Check that every gg command the skill names is a command gg actually has.
#
# This replaces the property the skill used to get from living inside the gg
# binary: "it ships with the CLI, so it cannot disagree with it." Co-location
# only ever guaranteed the two shipped together — never that they agreed. This
# checks the thing that was actually wanted, and catches a renamed command or
# flag, which co-location never did.
#
# Needs `gg` on the PATH. CI installs the latest release.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 scripts/check_skill_against_gg.py "$@"
