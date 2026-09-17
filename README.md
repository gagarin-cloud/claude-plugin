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
brew install gagarin-cloud/tap/gg
```

or `go install github.com/gagarin-cloud/gg@latest`, or a
[released binary](https://github.com/gagarin-cloud/gg/releases) — every release
publishes checksums. There is deliberately no `curl | bash`.

`/gagarin:setup` walks through it, including `gg login`.

## Not using Claude Code?

The skill is an [Agent Skills](https://agentskills.io) skill, which Cursor,
Codex, Copilot, Cline, Windsurf, Goose, opencode, Zed and others read. Install it
for any of them with the CLI:

```
gg skill install --agent agentskills   # ~/.agents/skills, read by most clients
gg skill install --agent all           # every harness gg knows by name
gg skill install -i                    # pick from a checklist
```

Or point any MCP client at `https://mcp.gagarin.cloud/mcp`.

## Vendored files

**`skills/gagarin/SKILL.md` is generated. Do not edit it here.** It is copied
byte-for-byte from [`gagarin-cloud/gg`](https://github.com/gagarin-cloud/gg) at
the tag recorded in `skills/gagarin/SOURCE.json`, and CI fails if the two
disagree. The skill lives in the CLI's repository so that it can never describe
a flag the CLI does not have — change it there, cut a gg release, and
`.github/workflows/sync-skill.yml` opens a pull request here.

Versions are `<gg-major>.<gg-minor>.<plugin-counter>`: `0.33.x` is the skill from
gg 0.33, and the patch moves when the plugin changes on its own.
`scripts/bump-version.sh` is the only thing that applies those rules.

## License

MIT. The skill is MIT from `gagarin-cloud/gg`, under the same terms.
