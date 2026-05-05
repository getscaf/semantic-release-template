# Semantic Release Scaf Template Design

## Summary

Create a small Scaf/Copier template that adds semantic-release automation to a new or existing project. The template should only scaffold semantic-release-related configuration, CI release jobs, and setup documentation. It should avoid assuming npm package publishing, avoid semantic-release's provider-specific defaults, and support common hosted Git providers plus Gitea-compatible instances.

## Goals

- Add semantic-release to existing or new projects with minimal generated files.
- Support GitHub, GitLab, Codeberg, Gitea, and Forgejo.
- Treat Gitea and Forgejo as self-hosted or instance-based software, not centralized providers.
- Support Codeberg as a known public Forgejo instance.
- Create hosted releases by default using the appropriate provider plugin.
- Use CI-time `npx` execution with the latest semantic-release at bootstrap.
- Generate clear provider-specific docs for required tokens and CI variables.

## Non-goals

- Do not scaffold an application, package, library, or language-specific build system.
- Do not publish npm packages by default.
- Do not install semantic-release as a local project dependency by default.
- Do not support providers without mature hosted-release plugin support in the MVP.
- Do not manage repository creation or remotes.

## Recommended Approach

Use Scaf to dogfood `template-starter` into a compact template repository named `semantic-release-template`, then simplify it to focus on semantic-release. The generated project should contain a Copier template under `template/` that emits semantic-release config, release CI files, and docs into the target project.

The template should always write an explicit semantic-release plugin list because semantic-release defaults include npm and GitHub plugins. The baseline should be:

```json
{
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator"
  ]
}
```

Provider-specific hosted release plugins are always added for the selected host.

## Provider Model

### GitHub

- Provider choice: `github`
- Hosted release support: yes
- Plugin: `@semantic-release/github`
- Token docs: `GH_TOKEN` or `GITHUB_TOKEN`
- CI: GitHub Actions workflow

### GitLab

- Provider choice: `gitlab`
- Hosted release support: yes
- Plugin: `@semantic-release/gitlab`
- Token docs: `GL_TOKEN` or `GITLAB_TOKEN`
- CI: GitLab CI job

### Codeberg

- Provider choice: `codeberg`
- Hosted release support: via Gitea-compatible plugin, with documentation caveats
- Plugin: `@saithodev/semantic-release-gitea`
- Default instance URL: `https://codeberg.org`
- Token docs: `GITEA_TOKEN`, `GITEA_URL=https://codeberg.org`
- CI: Forgejo/Gitea Actions-compatible workflow or docs-only fallback, depending on target project setup

### Gitea

- Provider choice: `gitea`
- Hosted release support: yes via Gitea-compatible plugin
- Plugin: `@saithodev/semantic-release-gitea`
- Required prompt: `instance_url`
- Token docs: `GITEA_TOKEN`, `GITEA_URL`, optional `GITEA_PREFIX`
- CI: Forgejo/Gitea Actions-compatible workflow or docs-only fallback

### Forgejo

- Provider choice: `forgejo`
- Hosted release support: yes via Gitea-compatible plugin for MVP
- Plugin: `@saithodev/semantic-release-gitea`
- Required prompt: `instance_url`
- Token docs: `GITEA_TOKEN`, `GITEA_URL`, optional `GITEA_PREFIX`
- CI: Forgejo/Gitea Actions-compatible workflow or docs-only fallback

Forgejo-specific plugins exist, but the MVP should prefer the more established Gitea-compatible semantic-release plugin unless testing proves it does not work for Forgejo.

## Copier Prompts

Recommended prompts for the generated template:

```yaml
semantic_release__git_host:
  type: str
  choices:
    - github
    - gitlab
    - codeberg
    - gitea
    - forgejo

semantic_release__instance_url:
  type: str
  when: "{{ semantic_release__git_host in ['gitea', 'forgejo'] }}"

semantic_release__ci_provider:
  type: str
  choices:
    - github_actions
    - gitlab_ci
    - gitea_actions
    - forgejo_actions
    - docs_only

semantic_release__release_branch:
  type: str
  default: main

```

Validation should require `semantic_release__instance_url` for Gitea and Forgejo.

## Generated Files

The target project should receive only semantic-release-related files:

- `.releaserc.json`
- provider-specific CI file, when selected:
  - `.github/workflows/semantic-release.yml`
  - `.gitlab-ci.yml` snippet or file
  - `.forgejo/workflows/semantic-release.yml` or `.gitea/workflows/semantic-release.yml`
- `docs/semantic-release.md`

For existing projects, the docs should warn users before overwriting existing CI files. The implementation can initially generate full files and rely on Copier conflict handling rather than trying to merge arbitrary existing CI configuration.

## CI Execution Strategy

Generated CI should run semantic-release after tests succeed. Use `npx --package` rather than local installation so provider plugins are available only in the release job.

GitHub hosted releases can run with semantic-release alone because `@semantic-release/github` is bundled with semantic-release:

```sh
npx semantic-release
```

GitLab hosted releases should include the GitLab plugin:

```sh
npx --package semantic-release --package @semantic-release/gitlab semantic-release
```

Gitea-compatible hosted releases should include the Gitea plugin:

```sh
npx --package semantic-release --package @saithodev/semantic-release-gitea semantic-release
```

## Semantic-release Config Strategy

The template should generate explicit plugin arrays:

### GitHub hosted release

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/github"
  ]
}
```

### GitLab hosted release

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    "@semantic-release/gitlab"
  ]
}
```

### Gitea-compatible hosted release

```json
{
  "branches": ["main"],
  "plugins": [
    "@semantic-release/commit-analyzer",
    "@semantic-release/release-notes-generator",
    [
      "@saithodev/semantic-release-gitea",
      {
        "giteaUrl": "https://example.com"
      }
    ]
  ]
}
```

## Testing Strategy

The template repository should include render tests that validate at least:

- GitHub hosted release output includes GitHub plugin and GitHub Actions workflow.
- GitLab hosted release output includes GitLab plugin and GitLab CI.
- Codeberg output uses Gitea-compatible plugin and `https://codeberg.org` default URL.
- Gitea output requires and renders a custom instance URL.
- Forgejo output requires and renders a custom instance URL.
- No rendered config accidentally includes `@semantic-release/npm`.

## Open Decisions for Implementation Plan

- Use `just` as the template repository's local task runner.
- Whether Gitea-compatible CI should default to `.forgejo/workflows`, `.gitea/workflows`, or docs-only.
- Whether GitLab CI should overwrite a full `.gitlab-ci.yml` or emit snippet docs by default.
