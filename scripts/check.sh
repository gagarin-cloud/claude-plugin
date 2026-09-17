#!/usr/bin/env bash
# The repository's own invariants: the manifests agree with each other, and the
# skill has the frontmatter Claude Code needs to load it at all.
#
# Whether the skill agrees with gg is a separate question and a separate script,
# because it needs a gg binary; see check-skill-against-gg.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

PLUGIN=.claude-plugin/plugin.json
MARKET=.claude-plugin/marketplace.json
MCP=.mcp.json
SKILL=skills/gagarin/SKILL.md
ENDPOINT="https://mcp.gagarin.cloud/mcp"

fail() { echo "FAIL: $*" >&2; exit 1; }
ok()   { echo "  ok  $*"; }

for f in "$PLUGIN" "$MARKET" "$MCP"; do
  jq empty "$f" 2>/dev/null || fail "invalid JSON: $f"
done
ok "JSON parses"

pv=$(jq -r .version "$PLUGIN")
mv=$(jq -r '.plugins[] | select(.name=="gagarin") | .version' "$MARKET")

# Strict semver, no prerelease or build metadata: Claude Code only re-installs
# when this changes, and anything exotic is a bet on how it compares two of them.
echo "$pv" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$' \
  || fail "plugin.json version '$pv' is not strict semver"
ok "version $pv is strict semver"

# A marketplace entry disagreeing with the plugin advertises a version nobody gets.
[ "$pv" = "$mv" ] || fail "version mismatch: plugin.json=$pv marketplace.json=$mv"
ok "marketplace.json agrees"

# The endpoint is the one thing a user cannot override; assert it verbatim.
jq -e --arg u "$ENDPOINT" '.mcpServers.gagarin.url == $u' "$MCP" >/dev/null \
  || fail ".mcp.json does not point at $ENDPOINT"
ok "mcp endpoint"

# The skill's name must match its directory or clients skip it silently.
awk '/^---$/{n++; next} n==1' "$SKILL" > /tmp/fm.$$
trap 'rm -f /tmp/fm.$$' EXIT
grep -qx 'name: gagarin' /tmp/fm.$$ || fail "SKILL.md frontmatter name must be 'gagarin'"
grep -qE '^description: .{40,}' /tmp/fm.$$ || fail "SKILL.md needs a description of real length"
ok "skill frontmatter"

echo "All checks passed."
