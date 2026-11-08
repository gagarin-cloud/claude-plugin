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

frontmatter() { awk '/^---$/{n++; next} n==1' "$1"; }

# grep -rnE over the Markdown in the given directories. Exit 1 is "nothing
# found"; anything above is an error, which must not read as a clean scan. BSD
# grep exits 1 for a missing path too, so check the directories first.
grep_md() {
  local pattern=$1 rc=0 out d
  shift
  for d in "$@"; do [ -d "$d" ] || fail "no $d/ to scan"; done
  out=$(grep -rnE "$pattern" --include='*.md' "$@") || rc=$?
  [ "$rc" -le 1 ] || fail "grep could not scan $*"
  printf '%s' "$out"
}

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
fm=$(frontmatter "$SKILL")
grep -qx 'name: gagarin' <<< "$fm" || fail "SKILL.md frontmatter name must be 'gagarin'"
grep -qE '^description: .{40,}' <<< "$fm" || fail "SKILL.md needs a description of real length"
ok "skill frontmatter"

# What follows is Anthropic's directory review, run here so a finding it cleared
# cannot come back unnoticed. Its checks are not public; these are the ones it
# raised on our first submission.

# Anything Claude is told to run must be a file that shipped with the plugin, not
# one fetched and piped into a shell: what runs then is not what was reviewed.
# The README may say it, for humans; commands, agents and the skill may not.
MD="commands agents skills"
FETCH='(curl|wget|irm|iwr|Invoke-RestMethod|Invoke-WebRequest)'
RUN='(sudo[[:space:]]+)?(sh|bash|zsh|dash|iex|pwsh|powershell|python3?|node|perl|ruby)'
for pattern in \
  "\\|[[:space:]]*${RUN}([[:space:]]|\`|\$)" \
  "(<|\\$)\\([[:space:]]*${FETCH}[[:space:]]" \
  "iex[[:space:]]*\\([[:space:]]*${FETCH}[[:space:]]" \
  "${FETCH}[[:space:]][^\`]*(-[A-Za-z]*[oO]|--output|-OutFile)[[:space:]][^\`]*(&&|;)[[:space:]]*(${RUN}[[:space:]]|\\./|&)"; do
  hits=$(grep_md "$pattern" $MD)
  [ -z "$hits" ] || fail "downloaded code run straight away; run the bundled installer instead:
$hits"
done
ok "no download-and-run"

# allowed-tools runs what it names without asking the user, and the directory
# refuses anything beyond these from an organization it has not Verified.
for f in commands/*.md agents/*.md skills/*/SKILL.md; do
  line=$(frontmatter "$f" | grep -E '^allowed-tools:' || true)
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
# Claude Code only runs one at the start of a line or after whitespace, but the
# directory refuses a !` anywhere, inline code such as `!` included: v1.17.0
# and v1.18.0 were refused for "the `!` line" in prose. Write **!** instead.
hits=$(grep_md '!`|^```!' $MD)
[ -z "$hits" ] || fail "inline shell span, as the directory reads it; tell Claude to run the command instead, or write **!**:
$hits"
ok "no inline shell spans"

# The directory holds a plugin whose files read a credential from the user's
# environment or files in code, because its MCP server could be where it goes,
# and says so of examples too. A connection URL is a credential (it holds the
# password), and so is anything a $(…) reads out of `gg resource secrets` or
# mints with `gg creds create`: pipe it instead.
# Describe these in prose instead.
CRED='(TOKEN|API_KEY|SECRET|PASSWORD|_URL)'
hits=$(grep_md "os\\.environ|process\\.env\\.|os\\.Getenv|\\$\\{\\{[[:space:]]*secrets\\.|\\\$\\{?[A-Z_]*${CRED}|\\\$\\([^)]*(resource secrets|creds create)|credentials\\.json" $MD)
[ -z "$hits" ] || fail "reads a credential from the environment or a file in code; describe it in prose:
$hits"
ok "no credential read from the environment"

# Nor a word the shell fills in, in a skill or an agent: the directory cannot
# tell where a command built from one sends data, and holds it when a
# credential is named anywhere near. Workflows and other examples that need
# ${{ … }} or $(…) live in files of their own, such as skills/gagarin/examples.
hits=$(grep_md '\$[({A-Za-z_]' skills agents)
[ -z "$hits" ] || fail "a word the shell fills in; describe it in prose or move it to an example file:
$hits"
ok "no shell-filled words in the skill or agents"

# The skill has to name credential variables (DB_PASSWORD, <NAME>_API_KEY): they
# are what a resource injects. The directory holds "a credential-named
# environment variable beside a remote url" unless the url is the vendor's own,
# so the skill links nowhere but Gagarin. In-cluster names and loopback are not
# remote. Other links belong in the README or /gagarin:setup.
hits=$(grep -rnoE --include='*.md' 'https?://[A-Za-z0-9.-]+' skills \
  | grep -vE '://(([A-Za-z0-9-]+\.)*gagarin\.cloud|127\.0\.0\.1|[A-Za-z0-9-]+)$' || true)
[ -z "$hits" ] || fail "the skill links a host that is not Gagarin's; move it to the README or /gagarin:setup:
$hits"
ok "the skill links only Gagarin"

# The listing icon is uploaded in the developer portal, not shipped: in the
# plugin, every route to one drew a finding. Naming it in plugin.json was held
# ("an image the plugin's code could run"), a generator's C2PA chunk read as
# "curl", and even bare deflate bytes spelled "iRM" and "iWr".
for f in .claude-plugin/icon.png .claude-plugin/icon.svg assets/icon.png assets/icon.svg; do
  [ ! -e "$f" ] || fail "$f ships an icon; upload it in the developer portal instead"
done
jq -e 'has("icon") | not' "$PLUGIN" >/dev/null || fail "plugin.json names an icon; upload it in the developer portal instead"
ok "no icon shipped"

# The listing needs a privacy policy, and a README line with "privacy" and a
# link is enough. The plugin.json fields for it draw an "unrecognized field"
# warning from the directory, so keep them out.
for k in privacyPolicyUrl termsOfServiceUrl; do
  jq -e --arg k "$k" 'has($k) | not' "$PLUGIN" >/dev/null \
    || fail "plugin.json sets $k; link it from the README instead"
done
grep -iE 'privacy' README.md | grep -qE '\]\(https://' \
  || fail "README.md needs a line that says privacy and links the policy"
ok "privacy policy linked from the README"

echo "All checks passed."
