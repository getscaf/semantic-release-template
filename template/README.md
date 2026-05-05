# {{ copier__project_name }}

{{ copier__description }}

## What This Includes

- Copier-based scaf template structure
- {{ copier__ci_provider | upper }} CI scaffolding
- Optional semantic-release automation
- Optional secret scanning
- Local init tasks for `make`, `task`, and `just` (primary: `{{ copier__task_runner }}`)
- Usage and upgrade docs

## Quick Start

1. Initialize your local development tools:

```bash
{% if copier__task_runner == "make" %}
make init
{% elif copier__task_runner == "just" %}
just init
{% else %}
task init
{% endif %}
```

2. Run a quick local sanity check:

```bash
{% if copier__task_runner == "make" %}
make check
{% elif copier__task_runner == "just" %}
just check
{% else %}
task check
{% endif %}
```

## Docs

- [Using This Template](docs/using-template.md)
- [Upgrading Projects](docs/upgrading.md)
{% if copier__ci_provider == "github" and copier__enable_semantic_release %}- [GitHub Semantic Release Setup](docs/semantic-release-github.md)
{% endif %}

