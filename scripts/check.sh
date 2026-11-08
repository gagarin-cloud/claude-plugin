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

# What follows is Anthropic's directory review, run here so a finding it cleared
# cannot come back unnoticed. Its checks are not public; these are the ones it
# raised on our first submission.

# Anything Claude is told to run must be a file that shipped with the plugin, not
# one fetched and piped into a shell: what runs then is not what was reviewed.
# The README may say it, for humans; commands, agents and the skill may not.
MD="commands agents skills"
if hits=$(grep -rnE '\|[[:space:]]*(sh|bash|zsh|iex)([[:space:]]|`|$)' --include='*.md' $MD); then
  fail "download piped into a shell; run the bundled installer instead:
$hits"
fi
ok "no download-and-run"

# allowed-tools runs what it names without asking the user, and the directory
# refuses anything beyond these from an organization it has not Verified.
for f in commands/*.md agents/*.md skills/*/SKILL.md; do
  line=$(awk '/^---$/{n++; next} n==1' "$f" | grep -E '^allowed-tools:' || true)
  [ -n "$line" ] || continue
  tools=${line#allowed-tools:}
  [ -n "${tools// /}" ] || fail "$f: allowed-tools as a YAML list is not checked here; write it on one line"
  # One entry is a tool name with an optional (rule), which may hold spaces.
  while read -r t; do
    case "$t" in
      Read|Grep|Glob|LS) ;;
      *) fail "$f: allowed-tools pre-approves '$t'; only Read, Grep, Glob and LS are allowed" ;;
    esac
  done < <(echo "$tools" | grep -oE '[A-Za-z_]+(\([^)]*\))?')
done
ok "allowed-tools is read-only"

# A !`…` span runs before Claude sees the file, and aborts the command outside
# auto mode unless allowed-tools pre-approves it, which the check above forbids.
if hits=$(grep -rnE '(^|[[:space:]])!`|^```!' --include='*.md' commands skills); then
  fail "inline shell span; tell Claude to run the command instead:
$hits"
fi
ok "no inline shell spans"

# The listing icon: a square PNG, 512 to 2048 px a side, under 2 MB.
icon=$(jq -r '.icon // empty' "$PLUGIN")
[ -n "$icon" ] || fail "plugin.json has no icon"
[ -f "$icon" ] || fail "icon $icon does not exist"
[ "$(od -An -tx1 -N8 "$icon" | tr -d ' \n')" = "89504e470d0a1a0a" ] || fail "icon $icon is not a PNG"
# Width and height are the IHDR's first two big-endian words, bytes 16 to 23.
read -r w h <<< "$(od -An -tu1 -j16 -N8 "$icon" | tr -s ' \n' ' ' \
  | awk '{print $1*16777216+$2*65536+$3*256+$4, $5*16777216+$6*65536+$7*256+$8}')"
[ "$w" = "$h" ] || fail "icon is ${w}x${h}, not square"
[ "$w" -ge 512 ] && [ "$w" -le 2048 ] || fail "icon is ${w} px a side, not 512 to 2048"
[ "$(wc -c < "$icon")" -lt 2097152 ] || fail "icon is 2 MB or more"
ok "icon ${w}x${h}"

for k in privacyPolicyUrl termsOfServiceUrl; do
  jq -e --arg k "$k" '.[$k] | type == "string" and startswith("https://")' "$PLUGIN" >/dev/null \
    || fail "plugin.json $k must be an https:// URL"
done
ok "privacy and terms links"

echo "All checks passed."
