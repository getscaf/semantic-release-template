# Template Release Plugin Package Tests Design

## Context

The project release workflow previously failed because `npx semantic-release` installed only the base `semantic-release` package while the repository config referenced plugins and presets that were not available in the transient npx environment. The generated template can fail the same way if rendered CI commands drift from rendered `.releaserc.json` plugin requirements.

The current template tests render provider-specific outputs and check for a few strings, but they do not verify that rendered CI release commands install every plugin package required outside the base `semantic-release` package.

## Goal

Add template correctness coverage that fails when a rendered semantic-release config references an external plugin or preset that the corresponding rendered release command does not install with `npx --package`.

## Policy

Rendered release commands should list only packages outside the base `semantic-release` package. They should not be required to list plugins bundled with base `semantic-release`.

Bundled plugin allowlist:

- `@semantic-release/commit-analyzer`
- `@semantic-release/release-notes-generator`
- `@semantic-release/github`
- `@semantic-release/npm`

External packages currently expected by host:

- GitLab: `@semantic-release/gitlab`
- Gitea/Forgejo/Codeberg-compatible: `@saithodev/semantic-release-gitea`

Preset package rule:

- If rendered `.releaserc.json` uses `"preset": "conventionalcommits"`, the checked release command must include `--package conventional-changelog-conventionalcommits`.

## Test Approach

Extend `scripts/test-template-render.sh` with a reusable assertion helper:

1. Render a template case as today.
2. Read the rendered `.releaserc.json`.
3. Read the relevant rendered command source:
   - GitHub Actions: `.github/workflows/semantic-release.yml`
   - GitLab CI: `.gitlab-ci.yml`
   - Gitea Actions: `.gitea/workflows/semantic-release.yml`
   - Forgejo Actions: `.forgejo/workflows/semantic-release.yml`
   - Docs-only: `docs/semantic-release.md`
4. For each rendered plugin package:
   - Ignore packages in the bundled allowlist.
   - Require external packages to appear as `--package <name>` in the command source.
5. If the config uses `preset: conventionalcommits`, require the conventionalcommits preset package.

The helper should print a clear error naming the missing package and checked file before exiting.

## Implementation Notes

A bash implementation is sufficient because the existing test suite is bash-based. Since rendered `.releaserc.json` is small and predictable, the first implementation can use focused `grep` checks rather than introducing a JSON parser dependency. If config complexity grows, the helper can later move to Python for exact JSON parsing.

The existing GitHub template currently uses only bundled plugins, so it should not need extra `--package` entries unless future config changes add external plugins or presets. GitLab and Gitea-compatible templates already include their external plugin packages and should be covered by the new helper.

## Non-Goals

- Do not execute semantic-release in tests.
- Do not perform network installs during template correctness tests.
- Do not require CI commands to list plugins bundled with base `semantic-release`.
- Do not change release behavior beyond fixing any missing external package declarations exposed by the tests.

## Verification

Run:

```bash
bash ./scripts/test-template-render.sh
```

Expected result: all template render tests pass. A regression that removes a required external package from a rendered release command should make this command fail with a clear missing-package message.
