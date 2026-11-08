#!/usr/bin/env bash
# The repository's own invariants: the manifests agree with each other, and the
# skill has the frontmatter Claude Code needs to load it at all.
#
# Whether the skill agrees with gg is a separate question and a separate script,
# because it needs a gg binary; see check-skill-against-gg.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

# The repository root is the marketplace; ROOT is the plugin folder it lists,
# which is what the directory reads and what people install.
ROOT=plugin
PLUGIN=$ROOT/.claude-plugin/plugin.json
MARKET=.claude-plugin/marketplace.json
MCP=$ROOT/.mcp.json
SKILL=$ROOT/skills/gagarin/SKILL.md
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
src=$(jq -r '.plugins[] | select(.name=="gagarin") | .source' "$MARKET")
[ "$src" = "./$ROOT" ] || fail "marketplace.json source is '$src', not './$ROOT'"
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
# raised on our submissions.

# The directory accepts scripts and programs only from organizations it has
# Verified, and there is no way to ask to become one. So the plugin folder holds
# Markdown, text, JSON, YAML and images, nothing starting with "#!", and the
# repository's own tooling lives outside it (scripts/, .github/).
while IFS= read -r f; do
  case "$f" in
    *.md|*.txt|*.json|*.yml|*.yaml|*/LICENSE|*/NOTICE|*/CHANGELOG|*.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico) ;;
    *) fail "$f: the directory accepts only Markdown, text, JSON, YAML and images in the plugin folder" ;;
  esac
  case "$f" in
    *.png|*.jpg|*.jpeg|*.gif|*.webp|*.ico) continue ;;
  esac
  [ "$(head -c 2 "$f")" != "#!" ] || fail "$f: starts with #!; the directory refuses scripts"
  iconv -f UTF-8 -t UTF-8 "$f" >/dev/null 2>&1 || fail "$f: not UTF-8"
  # A NUL cannot survive a shell variable, so count them instead of grepping.
  [ "$(LC_ALL=C tr -cd '\0' < "$f" | wc -c)" -eq 0 ] || fail "$f: holds a NUL byte"
done < <(git ls-files --cached --others --exclude-standard "$ROOT")
ok "plugin folder holds only text and images"

# The plugin folder ships its own copy of the license, so the directory and an
# installed plugin see one; keep it the same file as the repository's.
cmp -s LICENSE "$ROOT/LICENSE" || fail "$ROOT/LICENSE differs from LICENSE; copy it over"
ok "license copy agrees"

# Likewise, a frontmatter key the directory does not know is refused outright.
# Its list is not public; this is the Claude Code reference's set less what hands
# a component more power than text (hooks, mcpServers, permissionMode, skills…).
# Loosen it only when a re-validation has shown the key is accepted.
frontmatter_keys() { frontmatter "$1" | grep -oE '^[A-Za-z_][A-Za-z0-9_-]*:' | tr -d :; }
check_keys() {
  local kind=$1 allowed=$2 f k
  shift 2
  for f in "$@"; do
    for k in $(frontmatter_keys "$f"); do
      case " $allowed " in
        *" $k "*) ;;
        *) fail "$f: frontmatter key '$k' is not one the directory accepts in $kind frontmatter ($allowed)" ;;
      esac
    done
  done
}
check_keys command "description argument-hint allowed-tools model" $ROOT/commands/*.md
check_keys agent   "name description tools model color"            $ROOT/agents/*.md
check_keys skill   "name description allowed-tools"                $ROOT/skills/*/SKILL.md
ok "frontmatter keys"

# Anything Claude is told to run must be a tool the user already has, never
# something fetched and piped into a shell: what runs then is not what was
# reviewed. The README may say it, for humans; commands, agents and the skill
# may not.
MD="$ROOT/commands $ROOT/agents $ROOT/skills"
FETCH='(curl|wget|irm|iwr|Invoke-RestMethod|Invoke-WebRequest)'
RUN='(sudo[[:space:]]+)?(sh|bash|zsh|dash|iex|pwsh|powershell|python3?|node|perl|ruby)'
for pattern in \
  "\\|[[:space:]]*${RUN}([[:space:]]|\`|\$)" \
  "(<|\\$)\\([[:space:]]*${FETCH}[[:space:]]" \
  "iex[[:space:]]*\\([[:space:]]*${FETCH}[[:space:]]" \
  "${FETCH}[[:space:]][^\`]*(-[A-Za-z]*[oO]|--output|-OutFile)[[:space:]][^\`]*(&&|;)[[:space:]]*(${RUN}[[:space:]]|\\./|&)"; do
  hits=$(grep_md "$pattern" $MD)
  [ -z "$hits" ] || fail "downloaded code run straight away; use a package manager or hand the one-liner to the user:
$hits"
done
ok "no download-and-run"

# allowed-tools runs what it names without asking the user, and the directory
# refuses anything beyond these from an organization it has not Verified.
for f in $ROOT/commands/*.md $ROOT/agents/*.md $ROOT/skills/*/SKILL.md; do
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
# Claude Code only recognises one at the start of a line or after whitespace.
hits=$(grep_md '(^|[[:space:]])!`|^```!' $MD)
[ -z "$hits" ] || fail "inline shell span; tell Claude to run the command instead:
$hits"
ok "no inline shell spans"

# The listing icon: a square PNG, 512 to 2048 px a side, under 2 MB.
icon=$(jq -r '.icon // empty' "$PLUGIN")
[ -n "$icon" ] || fail "plugin.json has no icon"
icon=$ROOT/${icon#./}
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
