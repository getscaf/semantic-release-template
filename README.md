# Semantic Release Template

Scaf template that adds hosted semantic-release automation

This repository is a Copier template. It renders project scaffolding from the `template/` directory.

## Use This Template

```bash
# From a local clone
copier copy . /path/to/new-project --trust

# Or from a remote repository URL
copier copy <template-repo-url> /path/to/new-project --trust
```

## What Gets Rendered

- Project metadata and docs
- CI scaffolding
- Optional semantic-release wiring
- Optional secret scanning
- Task runner files (`make`, `task`, or `just`, pruned by selected option)

## Template Validation

Run local render checks with:

```bash

just test-template-render

```

This repository also includes `.github/workflows/template-correctness.yaml`, which runs the same check on every push/PR (for GitHub CI).
