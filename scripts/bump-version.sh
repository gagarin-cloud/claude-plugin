#!/usr/bin/env bash
# The plugin's version rules, in the one place that applies them.
#
# Scheme: <gg-major>.<gg-minor>.<plugin-counter>. The major and minor track the
# gg release whose skill is vendored, so "0.33.x" reads as "the skill from gg
# 0.33"; the patch is ours to move when the plugin changes and gg has not.
#
# Mirroring gg exactly does not work: gg cuts patch releases, so a plugin-only
# change would have no version to move to, and Claude Code only re-installs when
# the version changes. The exact gg tag is never inferred from this number —
# skills/gagarin/SOURCE.json is authoritative for that.
set -euo pipefail

cd "$(dirname "$0")/.."

PLUGIN=.claude-plugin/plugin.json
MARKET=.claude-plugin/marketplace.json
SOURCE=skills/gagarin/SOURCE.json

gg_ref=""
while [ $# -gt 0 ]; do
  case "$1" in
    --gg) gg_ref="$2"; shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# Default to whatever the pin says, so a plugin-only bump needs no arguments.
[ -n "$gg_ref" ] || gg_ref=$(jq -r .ref "$SOURCE")
gg_version=${gg_ref#v}

gg_major_minor=${gg_version%.*}
current=$(jq -r .version "$PLUGIN")
current_major_minor=${current%.*}
current_patch=${current##*.}

if [ "$gg_major_minor" = "$current_major_minor" ]; then
  # Same gg minor: this is a plugin-only change, or a gg patch. Either way the
  # counter moves so installed copies pick it up.
  new="$gg_major_minor.$((current_patch + 1))"
else
  # gg moved to a new minor or major: reset the counter.
  new="$gg_major_minor.0"
fi

# Claude Code re-installs on a version *change*, and a decrease is at best
# ambiguous to anything comparing them as semver. gg only moves forward, so a
# lower number here means a force-moved tag or a mistyped --gg, and neither
# should quietly ship a downgrade to everyone who has this installed.
lowest=$(printf '%s\n%s\n' "$current" "$new" | sort -t. -k1,1n -k2,2n -k3,3n | head -1)
if [ "$new" != "$current" ] && [ "$lowest" = "$new" ]; then
  echo "refusing to move the version backwards: $current -> $new (gg $gg_ref)" >&2
  echo "the pin is ahead of the tag you asked for; vendor a newer gg, or set the" >&2
  echo "version by hand if you really mean to roll back." >&2
  exit 1
fi

for f in "$PLUGIN" "$MARKET"; do
  tmp=$(mktemp)
  if [ "$f" = "$MARKET" ]; then
    jq --arg v "$new" '(.plugins[] | select(.name=="gagarin") | .version) = $v' "$f" > "$tmp"
  else
    jq --arg v "$new" '.version = $v' "$f" > "$tmp"
  fi
  mv "$tmp" "$f"
done

echo "$current -> $new (gg $gg_ref)"
