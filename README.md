# The Gagarin plugin for Claude Code

[Gagarin](https://gagarin.cloud) runs your containers on managed infrastructure.
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
  command, every error code, and the mistakes worth not making. It lives in this
  repository, so it can be newer than the `gg` you have; CI checks every command
  it names against the latest released `gg` (see [The skill lives here](#the-skill-lives-here)).
- **The MCP server** at `https://mcp.gagarin.cloud/mcp` — the Gagarin API as
  tools, and the project's **memory**: the durable facts an agent keeps about a
  codebase so the next session does not rediscover them, reachable only here.
  A fact that changes takes a key and is replaced, not piled up; a memory is
  confirmed when checked, disputed when wrong, and `memory_review` says what to tidy.
  You sign in with GitHub or Google when Claude Code asks; nothing is installed
  and no token passes through the agent.
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
curl -fsSL https://gagarin.cloud/install.sh | sh
```

On Windows, in PowerShell:

```
irm https://gagarin.cloud/install.ps1 | iex
```

The script checks the download against the release checksums, installs to
`~/.local/bin` (Windows: `%LOCALAPPDATA%\Programs\gg`) without `sudo`, and never
edits your shell profile; if the directory is not on your `PATH` it prints the
line to add. `gg upgrade` (v0.54.0 and later) keeps it current.

Prefer a package manager? On macOS, `brew install --cask gagarin-cloud/tap/gg` —
a cask, so it is macOS only, and if you installed `gg` as a formula before that,
`brew uninstall gg` once first. On Windows, `scoop bucket add gagarin
https://github.com/gagarin-cloud/scoop-bucket` then `scoop install gagarin/gg`,
or `winget install Gagarin.gg`. Or `go install
github.com/gagarin-cloud/gg@latest`, or a `.deb`, `.rpm` or `.apk` from the
[releases page](https://github.com/gagarin-cloud/gg/releases).

`/gagarin:setup` walks through it, including `gg login`, and then checks the
rest of the toolchain:

- **docker**, running — required to build and push. `gg ship` cannot work
  without it.
- **git** — recommended. It is how `.gagarin.json` gets committed, and with a
  clean work tree `gg build` and `gg ship` tag the image with the commit's
  short hash instead of the clock.
- **gh** or **glab**, signed in — recommended once you want CI. It puts the
  deploy credential in the secret store without it passing through the agent's
  output, and lets the agent watch the pipeline run.
- **jq** — optional.

Setup installs only `gg`; for the rest it tells you what is missing and how to
get it.

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
