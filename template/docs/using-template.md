# Using This Template

## Create a Project

```bash
scaf my-template-project <this-template-repo-url-or-path>
```

Answer copier prompts to choose:

- CI provider (`github` or `gitlab`)
- Whether to include semantic-release
- GitHub semantic-release auth mode (`github_token` or `github_app`) when GitHub + semantic-release is enabled
- Whether to include secret scanning
- Preferred task runner (`make`, `task`, `just`)

## Local Development

Run init once after generating:

```bash
{% if copier__task_runner == "make" %}
make init
{% elif copier__task_runner == "just" %}
just init
{% else %}
task init
{% endif %}
```

Run checks:

```bash
{% if copier__task_runner == "make" %}
make check
{% elif copier__task_runner == "just" %}
just check
{% else %}
task check
{% endif %}
```

## CI Behaviors

- Template correctness CI renders the template in CI and validates generated output.
- Secret scanning CI runs gitleaks when enabled.
- Semantic release runs on default branch when enabled.
- Semantic-release npm dependencies are initialized during project generation from `dependencies-init.txt` and `dependencies-dev-init.txt` (no pinned versions in template source).

## GitHub Semantic Release Auth

If you selected GitHub CI + semantic-release, see:

- [GitHub Semantic Release Setup](semantic-release-github.md)
