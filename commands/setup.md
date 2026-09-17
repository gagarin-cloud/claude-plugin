---
description: Get this machine ready to deploy on Gagarin Cloud — install the gg CLI if it is missing, then sign in.
allowed-tools: Bash(gg *), Bash(command -v *), Bash(brew *), Bash(go install *), Bash(go env *)
---

Get the user ready to use Gagarin Cloud. Work through this in order and stop at
the first step that needs them.

## 1. Is `gg` already here?

!`command -v gg >/dev/null 2>&1 && gg version || echo "gg is not installed"`

If it printed a version, skip to step 3.

## 2. Install it

Prefer whichever the machine can already run, in this order:

- `brew install gagarin-cloud/tap/gg`
- `go install github.com/gagarin-cloud/gg@latest`

If it has neither, point them at https://github.com/gagarin-cloud/gg/releases —
every release publishes checksums and they should verify them. **Do not pipe a
script from a URL into a shell**, and do not download from a host you guessed.

If `go install` succeeds but the shell still cannot find `gg`, its bin directory
(`go env GOPATH`/bin) is not on `PATH`. Say so and let them fix their profile;
do not edit their shell configuration yourself.

## 3. Sign in

Run `gg whoami` first. If it names an account, they are already set up — say so
and stop.

Otherwise run `gg login`. It prints a link and a code and exits. **Relay both to
the user exactly as printed** — you never handle a secret here. They open the
link, sign in with GitHub or Google, check the page shows the same code, and
approve. A new account starts with $5 on it.

Once they say they have approved, run `gg login` again to collect it.

## 4. Check the skill is not ahead of the binary

The skill ships in this plugin, not in `gg`, so the two update separately and it
can describe a `gg` newer than theirs. Run `gg version` and compare it against
the minimum the skill names in its "Installing gg" section. If theirs is older,
say so and tell them to upgrade — the same way they installed it — rather than
letting an agent meet a refusal later and conclude the command does not exist.

## 5. Tell them what they have

Briefly: `gg` drives everything, and the `gagarin` skill in this plugin
documents it. If this session also has the gagarin MCP tools connected, mention
that those cover the same API without a local install — but that **only `gg` can
build and push an image**, because that needs docker where the source is.

Do not deploy anything as part of setup. Stop here.
