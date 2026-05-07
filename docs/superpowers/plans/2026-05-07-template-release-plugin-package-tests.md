# Template Release Plugin Package Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the template correctness test fail when rendered semantic-release CI/docs commands omit `npx --package` entries required by rendered external plugins or presets.

**Architecture:** Keep the existing Bash render-test harness and add one focused assertion helper that compares rendered `.releaserc.json` against a rendered command source file. The helper uses an allowlist for plugins bundled with base `semantic-release`, requires only outside packages, and is invoked for every rendered CI/docs variant.

**Tech Stack:** Bash, Copier render tests, Jinja-rendered semantic-release configs, GitHub Actions/GitLab CI/Gitea/Forgejo workflow templates.

---

## File Structure

Modify one file:

- `scripts/test-template-render.sh` — owns render cases and template correctness assertions. Add the external-package assertion helper here and call it after each rendered case.

No template file is expected to change unless the new test exposes a missing external package. If that happens, update the failing rendered command template and docs command to include only the missing outside package via `--package <name>`.

---

### Task 1: Add external plugin package coverage to the render test

**Files:**
- Modify: `scripts/test-template-render.sh`

- [ ] **Step 1: Insert helper functions after `assert_docs_only_ci`**

Open `scripts/test-template-render.sh` and add this exact block immediately after the existing `assert_docs_only_ci()` function:

```bash
is_base_semantic_release_plugin() {
  local package="$1"

  case "$package" in
    @semantic-release/commit-analyzer|\
@semantic-release/release-notes-generator|\
@semantic-release/github|\
@semantic-release/npm)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

assert_command_installs_package() {
  local command_file="$1"
  local package="$2"

  if ! grep -Fq -- "--package $package" "$command_file"; then
    echo "Missing --package $package in $command_file" >&2
    exit 1
  fi
}

assert_release_command_installs_external_packages() {
  local out_dir="$1"
  local command_file="$2"
  local config_file="$out_dir/.releaserc.json"

  while IFS= read -r package; do
    if is_base_semantic_release_plugin "$package"; then
      continue
    fi

    assert_command_installs_package "$command_file" "$package"
  done < <(grep -oE '"@[A-Za-z0-9._-]+/[^"[:space:]]+"' "$config_file" | tr -d '"' | sort -u)

  if grep -Eq '"preset"[[:space:]]*:[[:space:]]*"conventionalcommits"' "$config_file"; then
    assert_command_installs_package "$command_file" "conventional-changelog-conventionalcommits"
  fi
}
```

- [ ] **Step 2: Call the helper for the rendered GitHub case**

In the `github_dir` block, keep the existing provider assertions and replace this line:

```bash
grep -Fq 'npx semantic-release' "$github_dir/.github/workflows/semantic-release.yml"
```

with this exact line:

```bash
assert_release_command_installs_external_packages "$github_dir" "$github_dir/.github/workflows/semantic-release.yml"
```

Expected behavior: this does not require any `--package` entries for GitHub because the rendered GitHub config currently uses only base semantic-release plugins.

- [ ] **Step 3: Call the helper for the rendered GitLab case**

In the `gitlab_dir` block, keep the existing provider assertions and replace this line:

```bash
grep -Fq '@semantic-release/gitlab' "$gitlab_dir/.gitlab-ci.yml"
```

with this exact line:

```bash
assert_release_command_installs_external_packages "$gitlab_dir" "$gitlab_dir/.gitlab-ci.yml"
```

Expected behavior: this requires `--package @semantic-release/gitlab` in the rendered GitLab CI file.

- [ ] **Step 4: Call the helper for the rendered docs-only Codeberg case**

In the `codeberg_dir` block, after the existing `grep -Fq '"giteaUrl": "https://codeberg.org"' "$codeberg_dir/.releaserc.json"` assertion, add this exact line:

```bash
assert_release_command_installs_external_packages "$codeberg_dir" "$codeberg_dir/docs/semantic-release.md"
```

Expected behavior: this requires `--package @saithodev/semantic-release-gitea` in the rendered docs release command.

- [ ] **Step 5: Call the helper for the rendered Gitea case**

In the `gitea_dir` block, after the existing release-branch assertion, add this exact line:

```bash
assert_release_command_installs_external_packages "$gitea_dir" "$gitea_dir/.gitea/workflows/semantic-release.yml"
```

Expected behavior: this requires `--package @saithodev/semantic-release-gitea` in the rendered Gitea Actions workflow.

- [ ] **Step 6: Call the helper for the rendered Forgejo case**

In the `forgejo_dir` block, replace this line:

```bash
grep -Fq '@saithodev/semantic-release-gitea' "$forgejo_dir/.forgejo/workflows/semantic-release.yml"
```

with this exact line:

```bash
assert_release_command_installs_external_packages "$forgejo_dir" "$forgejo_dir/.forgejo/workflows/semantic-release.yml"
```

Expected behavior: this requires `--package @saithodev/semantic-release-gitea` in the rendered Forgejo Actions workflow.

- [ ] **Step 7: Verify the new test catches the real regression with a temporary mutation**

Temporarily remove the GitLab external package from the source template, run the render test, and restore the template:

```bash
python - <<'PY'
from pathlib import Path
path = Path('template/.gitlab-ci.yml.jinja')
text = path.read_text()
old = 'npx --package semantic-release --package @semantic-release/gitlab semantic-release'
new = 'npx semantic-release'
if old not in text:
    raise SystemExit(f'Expected text not found in {path}')
path.write_text(text.replace(old, new))
PY

if bash ./scripts/test-template-render.sh; then
  echo "Expected missing GitLab package mutation to fail" >&2
  git checkout -- template/.gitlab-ci.yml.jinja
  exit 1
fi

git checkout -- template/.gitlab-ci.yml.jinja
```

Expected: `bash ./scripts/test-template-render.sh` fails and prints:

```text
Missing --package @semantic-release/gitlab
```

- [ ] **Step 8: Run the full render test after restoring the mutation**

```bash
bash ./scripts/test-template-render.sh
```

Expected final line:

```text
All semantic-release template render tests passed.
```

- [ ] **Step 9: Review the diff**

```bash
git diff -- scripts/test-template-render.sh
```

Expected: only `scripts/test-template-render.sh` changed. The diff adds the helper functions and replaces narrow string checks with calls to `assert_release_command_installs_external_packages`.

- [ ] **Step 10: Commit the test coverage**

```bash
git add scripts/test-template-render.sh
git commit -m "test: require external release packages"
```

Expected: commit succeeds.

---

### Task 2: Fix any template command exposed by the new test

**Files:**
- Modify only if needed: `template/.github/workflows/semantic-release.yml.jinja`
- Modify only if needed: `template/.gitlab-ci.yml.jinja`
- Modify only if needed: `template/.gitea/workflows/semantic-release.yml.jinja`
- Modify only if needed: `template/.forgejo/workflows/semantic-release.yml.jinja`
- Modify only if needed: `template/docs/semantic-release.md.jinja`

- [ ] **Step 1: Run the render test from Task 1 on the unmutated tree**

```bash
bash ./scripts/test-template-render.sh
```

Expected: if all rendered commands already include required outside packages, the test passes and this task needs no file changes.

- [ ] **Step 2: If the test reports a missing package, update the named command source**

Use the error message to identify the package and file. For example, if the failure is:

```text
Missing --package @semantic-release/gitlab in /tmp/semantic-release-template-gitlab-XXXXXX/.gitlab-ci.yml
```

then update `template/.gitlab-ci.yml.jinja` so its release command includes the missing outside package:

```yaml
script:
  - npx --package semantic-release --package @semantic-release/gitlab semantic-release
```

For Gitea-compatible failures, use:

```yaml
run: npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release
```

For docs-only Gitea-compatible command failures, use this rendered docs command form:

```bash
npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release
```

Do not add `--package` entries for these base semantic-release plugins:

```text
@semantic-release/commit-analyzer
@semantic-release/release-notes-generator
@semantic-release/github
@semantic-release/npm
```

- [ ] **Step 3: Re-run the render test**

```bash
bash ./scripts/test-template-render.sh
```

Expected final line:

```text
All semantic-release template render tests passed.
```

- [ ] **Step 4: Commit any template command fixes**

Only run this if Step 2 changed files:

```bash
git add template/.github/workflows/semantic-release.yml.jinja \
  template/.gitlab-ci.yml.jinja \
  template/.gitea/workflows/semantic-release.yml.jinja \
  template/.forgejo/workflows/semantic-release.yml.jinja \
  template/docs/semantic-release.md.jinja
git commit -m "fix: install external release plugins in templates"
```

Expected: commit succeeds if there were command fixes. If there were no command fixes, skip this commit.

---

## Final Verification

- [ ] **Step 1: Run template correctness tests**

```bash
bash ./scripts/test-template-render.sh
```

Expected final line:

```text
All semantic-release template render tests passed.
```

- [ ] **Step 2: Confirm branch and commits**

```bash
git branch --show-current
git status --short
git log --oneline -3
```

Expected:

```text
fix/template-release-plugin-package-tests
```

`git status --short` should be empty after commits. The recent log should include the design/plan commits and `test: require external release packages`.
