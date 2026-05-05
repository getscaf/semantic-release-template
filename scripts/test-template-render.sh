#!/usr/bin/env bash
set -euo pipefail

copier_ci_provider="github"
copier_task_runner="just"
copier_enable_semantic_release="false"
copier_enable_secret_scanning="false"
copier_github_semantic_release_auth="github_token"

out_dir="$(mktemp -d /tmp/scaf-template-render-XXXXXX)"
trap 'rm -rf "$out_dir"' EXIT

copy_cmd=(
  copier copy . "$out_dir" --trust --defaults
  -d "copier__project_name_raw=Sample Project"
  -d "copier__project_slug=sample_project"
  -d "copier__description=Sample generated project"
  -d "copier__author_name=Sample Author"
  -d "copier__email=sample@example.com"
  -d "copier__version=0.1.0"
  -d "copier__configure_repo=false"
  -d "copier__create_repo=false"
  -d "copier__ci_provider=$copier_ci_provider"
  -d "copier__enable_semantic_release=$copier_enable_semantic_release"
  -d "copier__enable_secret_scanning=$copier_enable_secret_scanning"
  -d "copier__task_runner=$copier_task_runner"
)

if [[ "$copier_ci_provider" == "github" && "$copier_enable_semantic_release" == "true" ]]; then
  copy_cmd+=(-d "copier__github_semantic_release_auth=$copier_github_semantic_release_auth")
fi

"${copy_cmd[@]}"

test -f "$out_dir/README.md"
test -f "$out_dir/LICENSE"
test -f "$out_dir/.copier-answers.yml"
test ! -f "$out_dir/{{_copier_conf.answers_file}}"

if [[ "$copier_task_runner" == "make" ]]; then
  test -f "$out_dir/Makefile"
  test ! -f "$out_dir/Taskfile.yml"
  test ! -f "$out_dir/justfile"
elif [[ "$copier_task_runner" == "task" ]]; then
  test -f "$out_dir/Taskfile.yml"
  test ! -f "$out_dir/Makefile"
  test ! -f "$out_dir/justfile"
else
  test -f "$out_dir/justfile"
  test ! -f "$out_dir/Makefile"
  test ! -f "$out_dir/Taskfile.yml"
fi

if [[ "$copier_ci_provider" == "github" ]]; then
  test -f "$out_dir/.github/workflows/template-correctness.yaml"
  test ! -f "$out_dir/.gitlab-ci.yml"
else
  test -f "$out_dir/.gitlab-ci.yml"
  test ! -d "$out_dir/.github"
fi

if [[ "$copier_enable_semantic_release" == "true" ]]; then
  test -f "$out_dir/package.json"
  test -f "$out_dir/dependencies-init.txt"
  test -f "$out_dir/dependencies-dev-init.txt"
  test -f "$out_dir/.releaserc.json"
  test -f "$out_dir/CHANGELOG.md"
else
  test ! -f "$out_dir/package.json"
  test ! -f "$out_dir/dependencies-init.txt"
  test ! -f "$out_dir/dependencies-dev-init.txt"
  test ! -f "$out_dir/.releaserc.json"
  test ! -f "$out_dir/CHANGELOG.md"
fi

if [[ "$copier_ci_provider" == "github" && "$copier_enable_semantic_release" == "true" ]]; then
  test -f "$out_dir/.github/workflows/semantic-release.yaml"
  test -f "$out_dir/.github/workflows/semantic-pull-request.yaml"
else
  test ! -f "$out_dir/.github/workflows/semantic-release.yaml"
  test ! -f "$out_dir/.github/workflows/semantic-pull-request.yaml"
fi

if [[ "$copier_ci_provider" == "github" && "$copier_enable_secret_scanning" == "true" ]]; then
  test -f "$out_dir/.github/workflows/secret-scan.yaml"
else
  test ! -f "$out_dir/.github/workflows/secret-scan.yaml"
fi
