"""What the checker pulls out of a file, without needing gg.

    python3 -m unittest discover -s scripts
"""
import unittest

from check_skill_against_gg import invocations

ROOTS = frozenset({"creds", "deploy", "status"})


class Markdown(unittest.TestCase):
    def test_code_span(self):
        self.assertEqual(invocations("Run `gg status acme` first."),
                         [["gg", "status", "acme"]])

    def test_prose_word_is_not_a_command(self):
        self.assertEqual(invocations("Check the `status` line.", ROOTS), [])

    def test_fenced_block_ends_at_two_spaces(self):
        text = "```\ngg creds        what has access\n```\n"
        self.assertEqual(invocations(text), [["gg", "creds"]])

    def test_table_continuation(self):
        text = "| `gg creds` / `creds create --name N` | mint one |\n"
        self.assertIn(["gg", "creds", "create", "--name", "N"], invocations(text, ROOTS))

    def test_run_step_in_yaml_fence(self):
        text = "```yaml\n      - name: release\n        run: gg deploy acme/web:8080 web:v1\n```\n"
        self.assertEqual(invocations(text), [["gg", "deploy", "acme/web:8080", "web:v1"]])


class Yaml(unittest.TestCase):
    WORKFLOW = """\
# gg login is never run here: the token is the pipeline's own.
on:
  push:
    branches: [main]
jobs:
  deploy:
    steps:
      - run: gg registry login
      - name: release
        run: |
          gg build acme/api:${{ github.sha }} --push
          gg deploy acme/api:4000 api:${{ github.sha }} --env PORT=4000
"""

    def test_every_line_is_read(self):
        got = invocations(self.WORKFLOW, yaml=True)
        self.assertEqual([t[:2] for t in got],
                         [["gg", "registry"], ["gg", "build"], ["gg", "deploy"]])

    def test_comments_are_not_commands(self):
        got = invocations(self.WORKFLOW, yaml=True)
        self.assertNotIn(["gg", "login"], [t[:2] for t in got])

    def test_flags_survive(self):
        deploy = invocations(self.WORKFLOW, yaml=True)[-1]
        self.assertIn("--env", deploy)

    def test_markdown_mode_skips_a_workflow(self):
        self.assertEqual(invocations(self.WORKFLOW), [])


if __name__ == "__main__":
    unittest.main()
