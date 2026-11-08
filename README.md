# gagarin-cloud/claude-plugin

The [Gagarin](https://gagarin.cloud) plugin for Claude Code, and the marketplace
that serves it. The plugin itself is in [`plugin/`](plugin/), and its
[README](plugin/README.md) is the one for users: what it gives you, how to
install `gg`, privacy.

```
/plugin marketplace add gagarin-cloud/claude-plugin
/plugin install gagarin@gagarin-cloud
```

## Layout

Anthropic's plugin directory accepts only Markdown, text, JSON, YAML and images
from an organization it has not Verified, and nothing that starts with `#!`. So
the plugin folder holds exactly that, and everything else about this repository
lives beside it:

- `plugin/` — the plugin: manifest, icon, `.mcp.json`, skill, commands, agents,
  README and license. This is what the directory reads and what people install.
- `.claude-plugin/marketplace.json` — the marketplace, with `plugin/` as its one
  entry.
- `scripts/` — the checks below and `bump-version.sh`.
- `.github/workflows/ci.yml` — runs them.
- `skills.sh.json` — tells `npx skills add` where the skill moved to.

## The skill lives here

`plugin/skills/gagarin/SKILL.md` is the source of truth and is edited here. It
used to ship inside the `gg` binary, on the reasoning that co-location stopped
it describing a flag the CLI did not have. It did not really: shipping together
is not the same as agreeing. So `gg` no longer carries it, and CI checks the
thing that was actually wanted — `scripts/check-skill-against-gg.sh` installs
the latest released `gg`, reads its command tree, and fails if the skill names a
command, subcommand or flag that does not exist. It runs on every change and
once a day, because the skill can go stale without anyone touching this repo.

The consequence to keep in mind: **the skill can now be newer than someone's
`gg`.** It says which version it assumes, and tells an agent to check
`gg version` before concluding a command does not exist.

## Checks

`scripts/check.sh` is the repository's own invariants plus every finding the
directory review has raised, replayed so none of them comes back unnoticed: the
file types the plugin folder may hold, the frontmatter keys a component may
carry, no download-and-run in anything Claude is told to do, read-only
`allowed-tools`, the icon's shape, and the listing links. `claude plugin
validate .` covers the manifests, and `claude plugin validate ./plugin --strict`
is the run the directory portal mirrors.

`scripts/bump-version.sh [major|minor|patch]` moves the version in both
manifests, which is what makes Claude Code re-install for people who have it.

## License

MIT.
