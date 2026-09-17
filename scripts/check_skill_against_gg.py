"""Check every `gg ...` in the skill against the real CLI.

See check-skill-against-gg.sh for why this exists.

It walks gg's own help to learn the command tree and each command's flags, then
pulls every gg invocation out of the skill's code spans and fenced blocks and
checks it. Placeholders (PROJECT, P/SVC, <name>) are skipped: only lowercase
words are treated as command names.
"""
import re
import subprocess
import sys

SKILL = "skills/gagarin/SKILL.md"
WORD = re.compile(r"^[a-z][a-z-]*$")


def help_for(path):
    r = subprocess.run(["gg", *path, "--help"], capture_output=True, text=True)
    return r.stdout + r.stderr


def parse_help(text):
    """Return (subcommands, long flags) from one --help page."""
    subs, flags = set(), set()
    section = None
    for line in text.splitlines():
        if re.match(r"^[A-Z][A-Za-z ]+:\s*$", line):
            section = line.strip().rstrip(":").lower()
            continue
        for f in re.findall(r"--([a-z][a-z0-9-]*)", line):
            flags.add(f)
        if section and "command" in section:
            m = re.match(r"^\s{2,}([a-z][a-z-]*)\s{2,}\S", line)
            if m:
                subs.add(m.group(1))
    return subs, flags


def walk():
    """Map command path -> (subcommands, allowed flags), over the whole tree."""
    tree = {}
    def visit(path):
        subs, flags = parse_help(help_for(path))
        subs -= {"completion", "help"}
        tree[tuple(path)] = (subs, flags)
        for s in sorted(subs):
            visit(path + [s])
    visit([])
    return tree


def invocations(text, roots=frozenset()):
    """Every gg invocation in a code span or fenced block, as a token list.

    The command map writes continuations without the prefix — `gg creds` /
    `creds create --name N` — so inside a table row a span whose first token is
    a known root command counts too. Elsewhere it does not: `status` in prose
    backticks is a word, not an invocation.
    """
    spans = []
    for line in text.splitlines():
        in_table = line.lstrip().startswith("|")
        for span in re.findall(r"`([^`\n]+)`", line):
            spans.append((span, in_table))
    for block in re.findall(r"```[a-z]*\n(.*?)```", text, re.S):
        spans.extend((line, False) for line in block.splitlines())

    out = []
    for raw, in_table in spans:
        # Split a pipeline, but not a markdown table cell — the rows are split
        # on "/" above, and a literal | inside a row would already have ended it.
        for part in re.split(r"\s*(?:\|\||&&|;)\s*", raw.strip()):
            for sub in part.split(" / "):
                # The skill aligns a description after a command in fenced
                # blocks — "gg creds        what has access, ..." — so a run of
                # two or more spaces ends the command and starts prose.
                sub = re.split(r"\s{2,}", sub.strip())[0]
                sub = sub.split(" #")[0]
                toks = sub.split()
                if not toks:
                    continue
                if toks[0] == "gg":
                    out.append(toks)
                elif in_table and toks[0] in roots:
                    out.append(["gg", *toks])
    return out


def main():
    tree = walk()
    known_roots = tree[()][0]
    if not known_roots:
        sys.exit("could not read gg's command list — is gg on the PATH?")

    text = open(SKILL).read()
    errors, checked = [], 0

    for toks in invocations(text, known_roots):
        args = toks[1:]
        if not args:
            continue
        # Resolve the deepest command path made of plain lowercase words.
        path = []
        i = 0
        while i < len(args) and WORD.match(args[i]) and tuple(path + [args[i]]) in tree:
            path.append(args[i])
            i += 1
        if not path:
            first = args[0]
            if WORD.match(first) and first not in known_roots:
                errors.append(f"unknown command: gg {first}")
            continue
        checked += 1
        subs, allowed = tree[tuple(path)]
        # A command that takes subcommands, followed by a plain word that is not
        # one of them, is a renamed or invented subcommand — the exact case this
        # check exists for, and the one a flag scan alone walks straight past.
        if subs and i < len(args) and WORD.match(args[i]):
            errors.append(
                f"unknown subcommand: gg {' '.join(path)} {args[i]} "
                f"(has: {', '.join(sorted(subs))})")
        for flag in re.findall(r"(?<!\S)--([a-z][a-z0-9-]*)", " ".join(args[i:])):
            if flag not in allowed:
                errors.append(f"unknown flag --{flag} for: gg {' '.join(path)}")

    # Every root command should be mentioned somewhere; a command the skill
    # never names is a command an agent will never use.
    named = set()
    for toks in invocations(text, known_roots):
        if len(toks) > 1 and WORD.match(toks[1]):
            named.add(toks[1])
    unmentioned = sorted(known_roots - named - {"completion", "help", "version"})

    if errors:
        print(f"{len(errors)} problem(s) between the skill and gg:")
        for e in sorted(set(errors)):
            print(f"  {e}")
        sys.exit(1)

    print(f"ok — {checked} gg invocations in the skill, all real commands and flags")
    if unmentioned:
        print(f"note: gg commands the skill never mentions: {', '.join(unmentioned)}")


if __name__ == "__main__":
    main()
