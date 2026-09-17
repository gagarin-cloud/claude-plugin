---
description: Take the current repository to production on Gagarin Cloud — build it, run it, and give it an address.
argument-hint: [project/service:port]
---

Deploy the repository in the working directory to Gagarin Cloud.

Target: $1

This is the human entry point to a full deploy. Hand it to the **gagarin-deploy**
subagent, which holds the whole procedure and its failure modes, passing along:

- the target `$1` if one was given — otherwise gagarin-deploy works out a
  sensible `project/service:port` from the repository and **confirms it with the
  user before creating anything**
- that this is the working directory the user wants shipped

Before delegating, check two things yourself, because both are faster to catch
here than three steps in:

- `gg` is on the PATH. If it is not, tell the user to run `/gagarin:setup` first.
  The MCP tools cannot substitute: they deliberately cannot build or push an
  image, and that is most of this command.
- `docker` is running. `gg build` and `gg push` shell out to it.

Do not deploy anything yourself. Delegate.
