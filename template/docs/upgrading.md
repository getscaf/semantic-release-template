# Upgrading Projects

## Standard Copier Upgrade

From the generated project root:

```bash
copier update
```

If you use answers-file overrides:

```bash
copier update --answers-file .copier-answers.yml
```

## Recommended Upgrade Workflow

1. Create a branch for the upgrade.
2. Run `copier update`.
3. Resolve conflicts and re-run checks.
4. Open a PR with generated diff and release notes.

## Version Pinning

Prefer pinning template refs in your project bootstrap docs (tag/commit) so updates are explicit and repeatable.
