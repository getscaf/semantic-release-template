# Semantic Release Scaf Template Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a small Scaf/Copier template named `semantic-release-template` that adds hosted semantic-release automation for GitHub, GitLab, Codeberg, Gitea, and Forgejo.

**Architecture:** Bootstrap from `template-starter` with `scaf`, then replace the generated template payload with focused semantic-release files only. Copier prompts choose the Git host, CI provider, release branch, and instance URL for Gitea/Forgejo. A small post-copy script removes unselected CI files after rendering.

**Tech Stack:** Scaf, Copier, Jinja templates, Bash render tests, semantic-release via CI-time `npx`, GitHub Actions, GitLab CI, Gitea/Forgejo Actions.

---

## File Structure

Create a new repository directory:

- `semantic-release-template/`

Inside it, maintain these files:

- `copier.yml` — prompts and Copier task for the semantic-release template.
- `README.md` — explains how to use this Scaf template.
- `justfile` — local test entrypoint.
- `scripts/test-template-render.sh` — render tests for all supported host/CI combinations.
- `template/.releaserc.json.jinja` — rendered semantic-release config.
- `template/docs/semantic-release.md.jinja` — rendered setup docs for tokens and CI wiring.
- `template/.github/workflows/semantic-release.yml.jinja` — GitHub Actions release workflow.
- `template/.gitlab-ci.yml.jinja` — GitLab CI release job.
- `template/.gitea/workflows/semantic-release.yml.jinja` — Gitea Actions release workflow.
- `template/.forgejo/workflows/semantic-release.yml.jinja` — Forgejo/Codeberg Actions release workflow.
- `template/.scaf/post-copy.py.jinja` — removes unselected CI files and `.scaf` after render.
- `template/{{_copier_conf.answers_file}}.jinja` — generated Copier answers file.

Design choices locked by this plan:

- Repository/template name: `semantic-release-template`.
- Config format: `.releaserc.json` only.
- Release mode: hosted release only.
- Supported hosts: `github`, `gitlab`, `codeberg`, `gitea`, `forgejo`.
- Bitbucket is excluded from the MVP.
- Gitea-compatible plugin: `@saithodev/semantic-release-gitea`.
- CI defaults:
  - GitHub → `github_actions`
  - GitLab → `gitlab_ci`
  - Codeberg → `docs_only`
  - Gitea → `gitea_actions`
  - Forgejo → `forgejo_actions`
- GitLab emits a full `.gitlab-ci.yml`; existing-project conflicts are handled by Copier conflict behavior and documented.

---

### Task 1: Bootstrap the template repository

**Files:**
- Create directory: `semantic-release-template/`
- Create via starter: initial generated template files

- [ ] **Step 1: Render the starter into a new repository directory**

Run from `/home/roche/projects/scaf/scaf-templates`:

```bash
scaf semantic-release-template --defaults \
  -d copier__project_name_raw="Semantic Release Template" \
  -d copier__project_slug="semantic_release_template" \
  -d copier__description="Scaf template that adds hosted semantic-release automation" \
  -d copier__author_name="Six Feet Up" \
  -d copier__email="info@sixfeetup.com" \
  -d copier__configure_repo=false \
  -d copier__enable_semantic_release=false \
  -d copier__enable_secret_scanning=false \
  -d copier__ci_provider="github" \
  -d copier__task_runner="just" \
  ./template-starter
```

Expected: `semantic-release-template/copier.yml`, `semantic-release-template/template/`, and `semantic-release-template/justfile` exist.

- [ ] **Step 2: Initialize git in the new template repository**

```bash
cd /home/roche/projects/scaf/scaf-templates/semantic-release-template
git init -b main
git status --short
```

Expected: `git status --short` lists the generated starter files as untracked.

- [ ] **Step 3: Commit the starter scaffold**

```bash
git add .
git commit -m "chore: bootstrap semantic-release scaf template"
```

Expected: commit succeeds.

---

### Task 2: Replace root template metadata and prompts

**Files:**
- Modify: `semantic-release-template/copier.yml`
- Modify: `semantic-release-template/README.md`
- Modify: `semantic-release-template/justfile`

- [ ] **Step 1: Replace `copier.yml`**

Write this exact content to `semantic-release-template/copier.yml`:

```yaml
_templates_suffix: ".jinja"
_subdirectory: template

_tasks:
  - python .scaf/post-copy.py

semantic_release__git_host:
  type: str
  default: github
  help: "Git hosting service where releases should be published."
  choices:
    - github
    - gitlab
    - codeberg
    - gitea
    - forgejo

semantic_release__instance_url:
  type: str
  default: ""
  help: "Base URL for your Gitea or Forgejo instance, for example https://git.example.com."
  when: "{{ semantic_release__git_host in ['gitea', 'forgejo'] }}"
  validator: >-
    {% if semantic_release__git_host in ['gitea', 'forgejo'] and not semantic_release__instance_url.strip() %}
      "Instance URL is required for {{ semantic_release__git_host }}."
    {% elif semantic_release__instance_url and not semantic_release__instance_url.startswith('http') %}
      "Instance URL must start with http:// or https://."
    {% endif %}

semantic_release__effective_instance_url:
  type: str
  default: "{{ 'https://codeberg.org' if semantic_release__git_host == 'codeberg' else semantic_release__instance_url.rstrip('/') }}"
  when: false

semantic_release__ci_provider:
  type: str
  default: >-
    {{
      'github_actions' if semantic_release__git_host == 'github' else
      'gitlab_ci' if semantic_release__git_host == 'gitlab' else
      'gitea_actions' if semantic_release__git_host == 'gitea' else
      'forgejo_actions' if semantic_release__git_host == 'forgejo' else
      'docs_only'
    }}
  help: "CI configuration to generate. Choose docs_only if you will wire the release command into existing CI manually."
  choices:
    - github_actions
    - gitlab_ci
    - gitea_actions
    - forgejo_actions
    - docs_only
  validator: >-
    {% set valid = {
      'github': ['github_actions', 'docs_only'],
      'gitlab': ['gitlab_ci', 'docs_only'],
      'codeberg': ['forgejo_actions', 'docs_only'],
      'gitea': ['gitea_actions', 'docs_only'],
      'forgejo': ['forgejo_actions', 'docs_only']
    } %}
    {% if semantic_release__ci_provider not in valid[semantic_release__git_host] %}
      "{{ semantic_release__ci_provider }} is not a supported CI provider for {{ semantic_release__git_host }}."
    {% endif %}

semantic_release__release_branch:
  type: str
  default: main
  help: "Branch semantic-release should publish from."
  validator: >-
    {% if not semantic_release__release_branch.strip() %}
      "Release branch cannot be empty."
    {% endif %}

```

- [ ] **Step 2: Replace `README.md`**

Write this exact content to `semantic-release-template/README.md`:

```markdown
# Semantic Release Template

A small Scaf/Copier template that adds hosted semantic-release automation to a new or existing project.

## Supported Git Hosts

- GitHub
- GitLab
- Codeberg
- Gitea instances
- Forgejo instances

The template creates hosted releases by default. It does not publish npm packages and it does not install semantic-release as a local dependency.

## Use This Template

```bash
scaf my-project /path/to/semantic-release-template
```

## What Gets Rendered

- `.releaserc.json`
- provider-specific release CI configuration, unless `docs_only` is selected
- `docs/semantic-release.md`

## Local Template Tests

```bash
just test-template-render
```
```

- [ ] **Step 3: Replace `justfile`**

Write this exact content to `semantic-release-template/justfile`:

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

test-template-render:
    bash ./scripts/test-template-render.sh
```

- [ ] **Step 4: Commit metadata and prompt changes**

```bash
git add copier.yml README.md justfile
git commit -m "feat: define semantic-release template prompts"
```

Expected: commit succeeds.

---

### Task 3: Replace the generated template payload

**Files:**
- Delete obsolete generated template files under `semantic-release-template/template/`
- Create: `semantic-release-template/template/.releaserc.json.jinja`
- Create: `semantic-release-template/template/{{_copier_conf.answers_file}}.jinja`
- Create: `semantic-release-template/template/docs/semantic-release.md.jinja`

- [ ] **Step 1: Remove inherited non-semantic-release payload files**

Run from `semantic-release-template`:

```bash
find template -mindepth 1 \
  ! -path 'template/.scaf' \
  ! -path 'template/.scaf/*' \
  -exec rm -rf {} +
mkdir -p template/docs template/.scaf
```

Expected: `template/` contains only `.scaf/` and `docs/` directories.

- [ ] **Step 2: Create `.releaserc.json.jinja`**

Write this exact content to `semantic-release-template/template/.releaserc.json.jinja`:

```json
{
  "branches": ["{{ semantic_release__release_branch }}"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator"{% if semantic_release__git_host == "github" %},
    "@semantic-release/github"{% elif semantic_release__git_host == "gitlab" %},
    "@semantic-release/gitlab"{% else %},
    [
      "@saithodev/semantic-release-gitea",
      {
        "giteaUrl": "{{ semantic_release__effective_instance_url }}"
      }
    ]{% endif %}
  ]
}
```

- [ ] **Step 3: Create the Copier answers template**

Write this exact content to `semantic-release-template/template/{{_copier_conf.answers_file}}.jinja`:

```jinja
# Changes here will be overwritten by Copier
{{ _copier_answers|to_nice_yaml -}}
```

- [ ] **Step 4: Create semantic-release setup docs**

Write this exact content to `semantic-release-template/template/docs/semantic-release.md.jinja`:

```markdown
# Semantic Release Setup

This project is configured for hosted releases with semantic-release.

## Release Branch

semantic-release publishes from:

```text
{{ semantic_release__release_branch }}
```

Protect this branch so only reviewed commits can trigger releases.

## Commit Format

semantic-release analyzes Conventional Commits:

- `fix: message` creates a patch release.
- `feat: message` creates a minor release.
- `feat!: message` or a commit body with `BREAKING CHANGE:` creates a major release.

## Git Host

Selected host: `{{ semantic_release__git_host }}`

{% if semantic_release__git_host == "github" %}
## Required GitHub Token

The generated workflow uses the built-in `GITHUB_TOKEN` secret by default.

If your project needs a personal access token instead, define `GH_TOKEN` in the repository secrets and update `.github/workflows/semantic-release.yml` to pass `GH_TOKEN` instead of `GITHUB_TOKEN`.
{% elif semantic_release__git_host == "gitlab" %}
## Required GitLab Token

Create a GitLab token with permissions to push tags and create releases. Add it to CI/CD variables as one of:

- `GL_TOKEN`
- `GITLAB_TOKEN`

The generated `.gitlab-ci.yml` expects one of those variables to be available.
{% else %}
## Required Gitea-compatible Token

Create an API token for your {{ semantic_release__git_host }} account with permission to push tags and create releases. Add it to CI secrets as:

- `GITEA_TOKEN`

Also provide the instance URL:

```text
GITEA_URL={{ semantic_release__effective_instance_url }}
```

The generated workflow sets `GITEA_URL` directly. You may move it to a secret or variable if your CI policy requires that.
{% endif %}

## CI Execution

{% if semantic_release__ci_provider == "github_actions" %}
GitHub Actions workflow: `.github/workflows/semantic-release.yml`
{% elif semantic_release__ci_provider == "gitlab_ci" %}
GitLab CI file: `.gitlab-ci.yml`
{% elif semantic_release__ci_provider == "gitea_actions" %}
Gitea Actions workflow: `.gitea/workflows/semantic-release.yml`
{% elif semantic_release__ci_provider == "forgejo_actions" %}
Forgejo Actions workflow: `.forgejo/workflows/semantic-release.yml`
{% else %}
No CI file was generated. Wire the release command below into your existing CI after tests pass.
{% endif %}

Release command:

```bash
{% if semantic_release__git_host == "github" %}npx semantic-release{% elif semantic_release__git_host == "gitlab" %}npx --package semantic-release --package @semantic-release/gitlab semantic-release{% else %}npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release{% endif %}
```

## Existing Projects

This template generates full CI files when a CI provider is selected. If your project already has CI configuration, let Copier show conflicts and merge the release job manually.

## What This Template Does Not Do

- It does not publish npm packages.
- It does not install semantic-release in `package.json`.
- It does not create repositories or configure Git remotes.
```

- [ ] **Step 5: Commit template payload changes**

```bash
git add template/.releaserc.json.jinja 'template/{{_copier_conf.answers_file}}.jinja' template/docs/semantic-release.md.jinja
git add -u template
git commit -m "feat: render semantic-release config and docs"
```

Expected: commit succeeds.

---

### Task 4: Add CI templates and post-copy pruning

**Files:**
- Create: `semantic-release-template/template/.github/workflows/semantic-release.yml.jinja`
- Create: `semantic-release-template/template/.gitlab-ci.yml.jinja`
- Create: `semantic-release-template/template/.gitea/workflows/semantic-release.yml.jinja`
- Create: `semantic-release-template/template/.forgejo/workflows/semantic-release.yml.jinja`
- Create: `semantic-release-template/template/.scaf/post-copy.py.jinja`

- [ ] **Step 1: Create CI template directories**

```bash
mkdir -p template/.github/workflows template/.gitea/workflows template/.forgejo/workflows template/.scaf
```

Expected: directories exist.

- [ ] **Step 2: Create GitHub Actions workflow template**

Write this exact content to `semantic-release-template/template/.github/workflows/semantic-release.yml.jinja`:

```yaml
name: semantic-release

on:
  workflow_dispatch:
  push:
    branches:
      - {{ semantic_release__release_branch }}

permissions:
  contents: write
  issues: write
  pull-requests: write

jobs:
  release:
    name: semantic-release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"

      - name: Release
        env:
          GITHUB_TOKEN: ${{ "{{ secrets.GITHUB_TOKEN }}" }}
        run: npx semantic-release
```

- [ ] **Step 3: Create GitLab CI template**

Write this exact content to `semantic-release-template/template/.gitlab-ci.yml.jinja`:

```yaml
stages:
  - release

semantic_release:
  stage: release
  image: node:22
  variables:
    GIT_DEPTH: "0"
  rules:
    - if: '$CI_COMMIT_BRANCH == "{{ semantic_release__release_branch }}"'
  before_script:
    - git fetch --tags --force
  script:
    - npx --package semantic-release --package @semantic-release/gitlab semantic-release
```

- [ ] **Step 4: Create Gitea Actions workflow template**

Write this exact content to `semantic-release-template/template/.gitea/workflows/semantic-release.yml.jinja`:

```yaml
name: semantic-release

on:
  workflow_dispatch:
  push:
    branches:
      - {{ semantic_release__release_branch }}

jobs:
  release:
    name: semantic-release
    runs-on: ubuntu-latest
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: "22"

      - name: Release
        env:
          GITEA_TOKEN: ${{ "{{ secrets.GITEA_TOKEN }}" }}
          GITEA_URL: "{{ semantic_release__effective_instance_url }}"
        run: npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release
```

- [ ] **Step 5: Create Forgejo Actions workflow template**

Write this exact content to `semantic-release-template/template/.forgejo/workflows/semantic-release.yml.jinja`:

```yaml
name: semantic-release

on:
  workflow_dispatch:
  push:
    branches:
      - {{ semantic_release__release_branch }}

jobs:
  release:
    name: semantic-release
    runs-on: docker
    container:
      image: node:22
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Release
        env:
          GITEA_TOKEN: ${{ "{{ secrets.GITEA_TOKEN }}" }}
          GITEA_URL: "{{ semantic_release__effective_instance_url }}"
        run: npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release
```

- [ ] **Step 6: Create post-copy pruning script**

Write this exact content to `semantic-release-template/template/.scaf/post-copy.py.jinja`:

```python
#!/usr/bin/env python3
from __future__ import annotations

import pathlib
import shutil

CI_PROVIDER = "{{ semantic_release__ci_provider }}"
PROJECT_ROOT = pathlib.Path.cwd()

CI_FILES = {
    "github_actions": PROJECT_ROOT / ".github" / "workflows" / "semantic-release.yml",
    "gitlab_ci": PROJECT_ROOT / ".gitlab-ci.yml",
    "gitea_actions": PROJECT_ROOT / ".gitea" / "workflows" / "semantic-release.yml",
    "forgejo_actions": PROJECT_ROOT / ".forgejo" / "workflows" / "semantic-release.yml",
}


def remove(path: pathlib.Path) -> None:
    if not path.exists():
        return
    if path.is_file() or path.is_symlink():
        path.unlink()
    else:
        shutil.rmtree(path)


def remove_empty_parents(path: pathlib.Path) -> None:
    current = path
    while current != PROJECT_ROOT and current.exists():
        try:
            current.rmdir()
        except OSError:
            return
        current = current.parent


def main() -> None:
    keep = CI_FILES.get(CI_PROVIDER)

    for ci_file in CI_FILES.values():
        if keep is not None and ci_file == keep:
            continue
        remove(ci_file)
        remove_empty_parents(ci_file.parent)

    remove(PROJECT_ROOT / ".scaf")
    print(f"semantic-release template rendered with ci_provider={CI_PROVIDER}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 7: Commit CI templates and pruning script**

```bash
git add template/.github template/.gitlab-ci.yml.jinja template/.gitea template/.forgejo template/.scaf/post-copy.py.jinja
git commit -m "feat: add provider release CI templates"
```

Expected: commit succeeds.

---

### Task 5: Add render tests

**Files:**
- Modify: `semantic-release-template/scripts/test-template-render.sh`

- [ ] **Step 1: Replace `scripts/test-template-render.sh`**

Write this exact content to `semantic-release-template/scripts/test-template-render.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

render_case() {
  local name="$1"
  shift
  local out_dir
  out_dir="$(mktemp -d "/tmp/semantic-release-template-${name}-XXXXXX")"

  copier copy "$ROOT_DIR" "$out_dir" --trust --defaults "$@"

  test -f "$out_dir/.releaserc.json"
  test -f "$out_dir/docs/semantic-release.md"
  test -f "$out_dir/.copier-answers.yml"
  ! grep -Fq '@semantic-release/npm' "$out_dir/.releaserc.json"

  echo "$out_dir"
}

assert_only_github_ci() {
  local out_dir="$1"
  test -f "$out_dir/.github/workflows/semantic-release.yml"
  test ! -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.gitea"
  test ! -d "$out_dir/.forgejo"
}

assert_only_gitlab_ci() {
  local out_dir="$1"
  test -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.github"
  test ! -d "$out_dir/.gitea"
  test ! -d "$out_dir/.forgejo"
}

assert_only_gitea_ci() {
  local out_dir="$1"
  test -f "$out_dir/.gitea/workflows/semantic-release.yml"
  test ! -d "$out_dir/.github"
  test ! -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.forgejo"
}

assert_only_forgejo_ci() {
  local out_dir="$1"
  test -f "$out_dir/.forgejo/workflows/semantic-release.yml"
  test ! -d "$out_dir/.github"
  test ! -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.gitea"
}

assert_docs_only_ci() {
  local out_dir="$1"
  test ! -d "$out_dir/.github"
  test ! -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.gitea"
  test ! -d "$out_dir/.forgejo"
}

main() {
  local github_dir
  github_dir="$(render_case github \
    -d semantic_release__git_host=github \
    -d semantic_release__release_branch=main)"
  assert_only_github_ci "$github_dir"
  grep -Fq '"@semantic-release/github"' "$github_dir/.releaserc.json"
  grep -Fq 'npx semantic-release' "$github_dir/.github/workflows/semantic-release.yml"
  rm -rf "$github_dir"

  local gitlab_dir
  gitlab_dir="$(render_case gitlab \
    -d semantic_release__git_host=gitlab \
    -d semantic_release__release_branch=main)"
  assert_only_gitlab_ci "$gitlab_dir"
  grep -Fq '"@semantic-release/gitlab"' "$gitlab_dir/.releaserc.json"
  grep -Fq '@semantic-release/gitlab' "$gitlab_dir/.gitlab-ci.yml"
  rm -rf "$gitlab_dir"

  local codeberg_dir
  codeberg_dir="$(render_case codeberg \
    -d semantic_release__git_host=codeberg \
    -d semantic_release__ci_provider=docs_only \
    -d semantic_release__release_branch=main)"
  assert_docs_only_ci "$codeberg_dir"
  grep -Fq '"@saithodev/semantic-release-gitea"' "$codeberg_dir/.releaserc.json"
  grep -Fq '"giteaUrl": "https://codeberg.org"' "$codeberg_dir/.releaserc.json"
  rm -rf "$codeberg_dir"

  local gitea_dir
  gitea_dir="$(render_case gitea \
    -d semantic_release__git_host=gitea \
    -d semantic_release__instance_url=https://git.example.com \
    -d semantic_release__release_branch=release)"
  assert_only_gitea_ci "$gitea_dir"
  grep -Fq '"giteaUrl": "https://git.example.com"' "$gitea_dir/.releaserc.json"
  grep -Fq 'branches": ["release"]' "$gitea_dir/.releaserc.json"
  rm -rf "$gitea_dir"

  local forgejo_dir
  forgejo_dir="$(render_case forgejo \
    -d semantic_release__git_host=forgejo \
    -d semantic_release__instance_url=https://forgejo.example.com \
    -d semantic_release__release_branch=main)"
  assert_only_forgejo_ci "$forgejo_dir"
  grep -Fq '"giteaUrl": "https://forgejo.example.com"' "$forgejo_dir/.releaserc.json"
  grep -Fq '@saithodev/semantic-release-gitea' "$forgejo_dir/.forgejo/workflows/semantic-release.yml"
  rm -rf "$forgejo_dir"

  local invalid_dir
  invalid_dir="$(mktemp -d /tmp/semantic-release-template-invalid-XXXXXX)"
  if copier copy "$ROOT_DIR" "$invalid_dir" --trust --defaults \
    -d semantic_release__git_host=gitea; then
    echo "Expected Gitea render without instance_url to fail" >&2
    exit 1
  fi
  rm -rf "$invalid_dir"

  if grep -Riq 'bitbucket' "$ROOT_DIR/copier.yml" "$ROOT_DIR/template"; then
    echo "Bitbucket should not be present in the MVP template" >&2
    exit 1
  fi

  echo "All semantic-release template render tests passed."
}

main "$@"
```

- [ ] **Step 2: Make the render test script executable**

```bash
chmod +x scripts/test-template-render.sh
```

Expected: script is executable.

- [ ] **Step 3: Commit render tests**

```bash
git add scripts/test-template-render.sh
git commit -m "test: cover semantic-release template renders"
```

Expected: commit succeeds.

---

### Task 6: Run verification and fix render issues

**Files:**
- Modify files from earlier tasks only if verification reveals an issue.

- [ ] **Step 1: Run the full render test suite**

```bash
just test-template-render
```

Expected output includes:

```text
All semantic-release template render tests passed.
```

- [ ] **Step 2: If tests fail, inspect the first failure**

Run:

```bash
bash -x ./scripts/test-template-render.sh
```

Expected: the trace shows the exact failing render/assertion.

- [ ] **Step 3: Apply the smallest fix**

Use the failure output to edit only the file responsible for the failed assertion. Examples:

- If `.releaserc.json` contains invalid JSON, edit `template/.releaserc.json.jinja`.
- If an unselected CI directory remains, edit `template/.scaf/post-copy.py.jinja`.
- If a provider token doc is wrong, edit `template/docs/semantic-release.md.jinja`.

- [ ] **Step 4: Re-run verification after any fix**

```bash
just test-template-render
```

Expected output includes:

```text
All semantic-release template render tests passed.
```

- [ ] **Step 5: Commit verification fixes if any files changed**

```bash
git status --short
```

If files changed, commit them:

```bash
git add .
git commit -m "fix: satisfy semantic-release render tests"
```

Expected: either no changes remain or a fix commit succeeds.

---

### Task 7: Final review against the design spec

**Files:**
- Read: `/home/roche/projects/scaf/scaf-templates/docs/superpowers/specs/2026-05-05-semantic-release-scaf-template-design.md`
- Read/verify: `semantic-release-template/copier.yml`
- Read/verify: `semantic-release-template/template/.releaserc.json.jinja`
- Read/verify: `semantic-release-template/scripts/test-template-render.sh`

- [ ] **Step 1: Verify supported providers match the spec**

Run:

```bash
grep -nE 'github|gitlab|codeberg|gitea|forgejo|bitbucket' copier.yml template/.releaserc.json.jinja scripts/test-template-render.sh
```

Expected:

- `github`, `gitlab`, `codeberg`, `gitea`, and `forgejo` appear.
- `bitbucket` appears only in the negative assertion inside `scripts/test-template-render.sh`.

- [ ] **Step 2: Verify npm publishing is absent**

Run:

```bash
! grep -R '@semantic-release/npm' copier.yml template scripts
```

Expected: command exits 0 because `@semantic-release/npm` is absent.

- [ ] **Step 3: Verify generated files are semantic-release-only**

Run:

```bash
find template -type f | sort
```

Expected output contains only these paths:

```text
template/.forgejo/workflows/semantic-release.yml.jinja
template/.gitea/workflows/semantic-release.yml.jinja
template/.github/workflows/semantic-release.yml.jinja
template/.gitlab-ci.yml.jinja
template/.releaserc.json.jinja
template/.scaf/post-copy.py.jinja
template/{{_copier_conf.answers_file}}.jinja
template/docs/semantic-release.md.jinja
```

- [ ] **Step 4: Run final verification**

```bash
just test-template-render
git status --short
```

Expected:

- render tests print `All semantic-release template render tests passed.`
- `git status --short` is empty.

- [ ] **Step 5: Report completion with evidence**

Report the final verification commands and their outputs. Do not claim the implementation is complete unless Task 7 Step 4 has passed in the current session.
