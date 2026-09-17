---
description: Show what is actually running in a Gagarin Cloud project — desired vs actual state, addresses, sizes and today's cost.
argument-hint: [project]
allowed-tools: Bash(gg status *), Bash(gg projects)
---

Report the state of the user's Gagarin Cloud project.

Project: $1

If no project was named, run `gg projects` first and ask which one they mean —
do not guess, and do not infer a project from the working directory. Gagarin
names nothing after the directory you stand in.

Then run `gg status <project>`.

Two things about reading the result:

- **`gg status` is the only thing that reads the cluster.** Every other write
  records a demand without watching it come true, so this is the only answer to
  "is it up".
- Every row already carries a sentence written by the engine, so that a terminal
  and a dashboard cannot describe the same row differently. **Relay those
  sentences rather than rewriting them into your own words.** Summarise what
  needs attention; do not re-render the table.

If a service is waiting on DNS or a certificate, `gg status` says which side it
is waiting on — theirs or gagarin's. Say which.

If the gagarin MCP tools are connected and `gg` is not installed, use the
`status` tool instead; it reads the same thing.
