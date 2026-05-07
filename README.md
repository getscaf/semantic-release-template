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

## Use in an Existing Project

Until Scaf has first-class support for applying templates to existing projects, use Copier directly from the existing project root:

```bash
cd /path/to/existing-project
copier copy /path/to/semantic-release-template . --trust
```

Use `--defaults` for non-interactive rendering:

```bash
copier copy /path/to/semantic-release-template . --trust --defaults
```

Copier will report conflicts for files that already exist. Review those conflicts carefully before overwriting CI or release configuration files.

Scaf support for this workflow is tracked in [getscaf/scaf#546](https://github.com/getscaf/scaf/issues/546).

## What Gets Rendered

- `.releaserc.json`
- provider-specific release CI configuration, unless `docs_only` is selected
- `docs/semantic-release.md`

## Local Template Tests

```bash
just test-template-render
```
