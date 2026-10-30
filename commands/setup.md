---
description: Get this machine ready to deploy on Gagarin Cloud — install the gg CLI if it is missing, sign in, and check the rest of the toolchain (docker, git, gh or glab).
allowed-tools: Bash(gg *), Bash(~/.local/bin/gg *), Bash(command -v *), Bash(curl *), Bash(sh), Bash(sh *), Bash(powershell *), Bash(pwsh *), Bash(brew *), Bash(scoop *), Bash(winget *), Bash(go install *), Bash(go env *), Bash(docker info*), Bash(docker buildx version*), Bash(git rev-parse *), Bash(git remote get-url *), Bash(gh auth status*), Bash(glab auth status*)
---

Get the user ready to use Gagarin Cloud. Work through this in order and stop at
the first step that needs them.

## 1. Is `gg` already here?

!`command -v gg >/dev/null 2>&1 && gg version || echo "gg is not installed"`

If it printed a version, skip to step 3.

## 2. Install it

Run the install script. It checks the download against the release's
`checksums.txt`, puts `gg` in `~/.local/bin` without `sudo`, and never edits a
shell profile.

- macOS or Linux: `curl -fsSL https://gagarin.cloud/install.sh | sh`
- Windows (PowerShell): `irm https://gagarin.cloud/install.ps1 | iex`

If your harness refuses or prompts on piping into a shell, download it first and
run it as a file:

- macOS or Linux: `curl -fsSLo install.sh https://gagarin.cloud/install.sh && sh install.sh`
- Windows: `irm https://gagarin.cloud/install.ps1 -OutFile install.ps1; ./install.ps1`
  — if execution policy blocks it, `powershell -ExecutionPolicy Bypass -File install.ps1`

On Windows it installs to `%LOCALAPPDATA%\Programs\gg` and adds that to the
user's `PATH`. `GAGARIN_INSTALL_DIR` changes the directory and
`GAGARIN_INSTALL_VERSION` pins a version.

If `~/.local/bin` is not on `PATH`, the script prints the `export` line to add.
Call `gg` by its full path (`~/.local/bin/gg`) for the rest of this session and
tell the user the line; do not edit their shell configuration yourself.

Prefer a package manager? Any of these works too:

- macOS: `brew install --cask gagarin-cloud/tap/gg` (macOS only — casks do not
  work on Linux)
- Windows: `scoop bucket add gagarin https://github.com/gagarin-cloud/scoop-bucket`
  then `scoop install gagarin/gg`, or `winget install Gagarin.gg`
- any platform with a Go toolchain: `go install github.com/gagarin-cloud/gg@latest`
- Linux: a `.deb`, `.rpm` or `.apk` from
  https://github.com/gagarin-cloud/gg/releases (installing it needs `sudo`, so
  hand the command to the user)

Homebrew installs it as a **cask**, not a formula. If they already have a formula
`gg` (`brew list gg` finds it and `brew list --cask gg` does not), tell them to
`brew uninstall gg` once and then install the cask.

If `go install` succeeds but the shell still cannot find `gg`, its bin directory
(`go env GOPATH`/bin) is not on `PATH`. Same rule: say so and let them fix their
profile.

Do not download from a host you guessed.

## 3. Sign in

Run `gg whoami` first. If it names an account, they are already signed in — say
so and go on to step 4.

Otherwise run `gg login`. It prints a link and a code and exits. **Relay both to
the user exactly as printed** — you never handle a secret here. They open the
link, sign in with GitHub or Google, check the page shows the same code, and
approve. A new account starts with $5 on it.

Once they say they have approved, run `gg login` again to collect it.

## 4. Check the skill is not ahead of the binary

The skill ships in this plugin, not in `gg`, so the two update separately and it
can describe a `gg` newer than theirs. Run `gg version`. If it prints "gg vX is
available (you have vY)" on stderr, theirs is behind (`GAGARIN_NO_UPDATE_CHECK=1`
silences that check). Say so and run `gg upgrade`: it upgrades the way `gg` was
installed — brew, scoop, winget and `go install` are handed to that tool, a
script or archive install replaces itself after checking the checksum, and a
`.deb`/`.rpm`/`.apk` install prints a `sudo` command for the human to run.
`gg upgrade --dry-run` previews it first.

`gg upgrade` exists from v0.54.0. If theirs is older it will say the command is
unknown: re-run the install one-liner from step 2, or use the old per-manager
command (`brew upgrade --cask gagarin-cloud/tap/gg`, `scoop update gg`,
`winget upgrade Gagarin.gg`, or `go install ...@latest`). Do this rather than
letting an agent meet a refusal later and conclude the command does not exist.

## 5. Check the rest of the toolchain

`gg` is the only thing setup installs, but a good session needs more. Check
each, and report them together as one short list rather than one by one. Of
docker, git, gh, glab and jq, whichever has no path printed here is missing:

!`command -v docker git gh glab jq || true`

Then, for what was found:

- `docker info` — is the daemon actually up? `docker buildx version` — only
  `gg registry copy` needs it.
- `git rev-parse --is-inside-work-tree` and `git remote get-url origin` — is
  this a repository, and does it live on GitHub, GitLab or somewhere else?
- `gh auth status` (GitHub) or `glab auth status` (GitLab) — only the one that
  matches the remote. Present but not signed in is the same as missing.

What each one is for, and what to tell them when it is missing:

| tool | why | if missing |
|---|---|---|
| docker, running | **required** to build and push — `gg ship` is impossible without it | ask them to install or start Docker Desktop, OrbStack or colima (Docker Engine on Linux) |
| git | commit `.gagarin.json`, tie each image to a commit, find the forge | recommended; deploys still work |
| gh / glab, signed in | set the CI secret without it passing through the transcript, and watch the pipeline run | recommended once they want CI; they run `gh auth login` / `glab auth login` themselves |
| jq | pull one value out of JSON output | optional |

Do not install or start any of these yourself, and do not sign in to `gh` or
`glab` for them. Give the install command for their platform (`brew install gh`,
`winget install GitHub.cli`, `sudo apt install gh`; `glab` the same way) and let
them decide. A missing optional tool is a sentence, not a blocker.

## 6. Tell them what they have

Briefly: `gg` drives everything, and the `gagarin` skill in this plugin
documents it. If this session also has the Gagarin MCP tools connected, mention
that those cover the same API without a local install — but that **only `gg` can
build and push an image**, because that needs docker where the source is.

Do not deploy anything as part of setup. Stop here.
