# The gagarin plugin for Claude Code

[gagarin](https://gagarin.cloud) runs your containers on managed infrastructure.
There are no manifest files and no config files: the API is the only way state
changes, which is why neither you nor your agent can ever be out of sync with
what is actually running.

This repository is the install path. It is both a Claude Code **marketplace**
and the **plugin** in it.

```
/plugin marketplace add gagarin-cloud/claude-plugin
/plugin install gagarin@gagarin-cloud
```

That gives you four things:

- **The skill** — the whole product, written for an agent: the model, every
  command, every error code, and the mistakes worth not making. It is the same
  file that ships inside the `gg` binary, so it cannot disagree with the CLI.
- **The MCP server** at `https://mcp.gagarin.cloud/mcp` — 35 tools over the
  gagarin API. You sign in with GitHub or Google when Claude Code asks; nothing
  is installed and no token passes through the agent.
- **Commands** — `/gagarin:setup`, `/gagarin:status`, `/gagarin:ship`.
- **Subagents** — `gagarin-deploy` takes a repository to a working HTTPS URL;
  `gagarin-ci` wires a pipeline to deploy on push.

## You still want the CLI

The MCP server is the same API in another shape, and it deliberately cannot do
four things: **build** an image, **push** one, open a **tunnel**, or **wait** for
a job. The first two shell out to docker where your source is, and a server on
the internet has neither. So `gg` is the larger surface, and the way to get an
image into the registry:

```
brew install --cask gagarin-cloud/tap/gg
```

It is a cask. If you installed `gg` as a formula before that, `brew uninstall
gg` once first — homebrew will not swap one for the other on its own.

On Windows:

```
scoop bucket add gagarin https://github.com/gagarin-cloud/scoop-bucket
scoop install gagarin/gg
```

```
winget install Gagarin.gg
```

Or `go install github.com/gagarin-cloud/gg@latest`, or a
[released binary](https://github.com/gagarin-cloud/gg/releases) — every release
publishes checksums. There is deliberately no `curl | bash`.

`/gagarin:setup` walks through it, including `gg login`.

## Not using Claude Code?

The skill is an [Agent Skills](https://agentskills.io) skill, which Cursor,
Codex, Copilot, Cline, Windsurf, Goose, opencode, Zed and about seventy others
read. Install it into any of them:

```
npx skills add gagarin-cloud/claude-plugin -g
```

`-g` installs for your user; drop it to add the skill to one project instead.
`npx skills update` refreshes it later. Or copy `skills/gagarin/` to
`~/.agents/skills/gagarin/` yourself — that is all the installer does.

Or point any MCP client at `https://mcp.gagarin.cloud/mcp` and install nothing.

## The skill lives here

`skills/gagarin/SKILL.md` is the source of truth and is edited here. It used to
ship inside the `gg` binary, on the reasoning that co-location stopped it
describing a flag the CLI did not have. It did not really: shipping together is
not the same as agreeing. So `gg` no longer carries it, and CI checks the thing
that was actually wanted — `scripts/check-skill-against-gg.sh` installs the
latest released `gg`, reads its command tree, and fails if the skill names a
command, subcommand or flag that does not exist. It runs on every change and
once a day, because the skill can go stale without anyone touching this repo.

The consequence to keep in mind: **the skill can now be newer than someone's
`gg`.** It says which version it assumes, and tells an agent to check
`gg version` before concluding a command does not exist.

`scripts/bump-version.sh [major|minor|patch]` moves the version in both
manifests, which is what makes Claude Code re-install for people who have it.

## License

MIT.
