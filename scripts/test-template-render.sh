#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

render_case() {
  local name="$1"
  shift
  local out_dir
  out_dir="$(mktemp -d "/tmp/semantic-release-template-${name}-XXXXXX")"

  copier copy "$ROOT_DIR" "$out_dir" --trust --defaults "$@" >&2

  test -f "$out_dir/.releaserc.json"
  test -f "$out_dir/docs/semantic-release.md"
  test -f "$out_dir/.copier-answers.yml"
  test ! -d "$out_dir/.scaf"
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
  invalid_dir="$(mktemp -d /tmp/semantic-release-template-invalid-gitea-XXXXXX)"
  if copier copy "$ROOT_DIR" "$invalid_dir" --trust --defaults \
    -d semantic_release__git_host=gitea >/dev/null 2>&1; then
    echo "Expected Gitea render without instance_url to fail" >&2
    exit 1
  fi
  rm -rf "$invalid_dir"

  invalid_dir="$(mktemp -d /tmp/semantic-release-template-invalid-forgejo-XXXXXX)"
  if copier copy "$ROOT_DIR" "$invalid_dir" --trust --defaults \
    -d semantic_release__git_host=forgejo >/dev/null 2>&1; then
    echo "Expected Forgejo render without instance_url to fail" >&2
    exit 1
  fi
  rm -rf "$invalid_dir"

  invalid_dir="$(mktemp -d /tmp/semantic-release-template-invalid-url-XXXXXX)"
  if copier copy "$ROOT_DIR" "$invalid_dir" --trust --defaults \
    -d semantic_release__git_host=gitea \
    -d semantic_release__instance_url=httpx://git.example.com >/dev/null 2>&1; then
    echo "Expected invalid instance_url scheme to fail" >&2
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
