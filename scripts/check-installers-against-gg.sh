#!/usr/bin/env bash
# The installers in skills/gagarin/scripts are copies of gg's, shipped so that
# setup runs a file that was reviewed with the plugin instead of piping one from
# the internet into a shell. A copy is only as good as its last sync: this checks
# that they are byte for byte what gg's latest release serves, which is also what
# https://gagarin.cloud/install.sh redirects to.
set -euo pipefail
cd "$(dirname "$0")/.."

RELEASE=${GAGARIN_RELEASES:-https://github.com/gagarin-cloud/gg/releases}/latest/download
DIR=skills/gagarin/scripts

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

status=0
for f in install.sh install.ps1; do
  curl -fsSL "$RELEASE/$f" -o "$tmp/$f"
  if cmp -s "$tmp/$f" "$DIR/$f"; then
    echo "  ok  $DIR/$f matches gg's latest release"
  else
    echo "FAIL: $DIR/$f differs from $RELEASE/$f; copy the release's in" >&2
    diff -u "$DIR/$f" "$tmp/$f" >&2 || true
    status=1
  fi
done
exit $status
