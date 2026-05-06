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
