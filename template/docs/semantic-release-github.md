# GitHub Semantic Release Setup

This project supports two authentication modes for semantic-release on GitHub:

- `github_token`: uses `secrets.GITHUB_TOKEN`
- `github_app`: uses a GitHub App installation token

## Choose an Auth Mode

Set `copier__github_semantic_release_auth` to one of:

- `github_token`
- `github_app`

This option is only used when:

- `copier__ci_provider = github`
- `copier__enable_semantic_release = true`

## Mode 1: `github_token`

No additional app setup is required. The workflow uses:

- `GITHUB_TOKEN: ${{ '{{ secrets.GITHUB_TOKEN }}' }}`

If your branch protection/ruleset blocks direct pushes by GitHub Actions, semantic-release may fail when updating `CHANGELOG.md` and `package.json`.

## Mode 2: `github_app`

Use this when you need explicit bypass control for protected `main`.

### 1. Create the GitHub App

1. Open GitHub: `Settings` -> `Developer settings` -> `GitHub Apps` -> `New GitHub App`
2. Set:
   - **GitHub App name**: e.g. `semantic-release-bot`
   - **Homepage URL**: your repo/org URL
   - **Webhook**: disable for this use case
3. Repository permissions:
   - **Contents**: `Read and write`
   - **Metadata**: `Read-only` (default)
   - **Pull requests**: `Read-only` (optional)
   - **Issues**: `Read and write` (recommended for release notes/issues)
4. Click `Create GitHub App`.

### 2. Generate and Store App Credentials

1. In the app page, copy the **App ID**.
2. Under **Private keys**, click `Generate a private key` and download the PEM.
3. In your repository: `Settings` -> `Secrets and variables` -> `Actions` -> `New repository secret`.
4. Add:
   - `SEMANTIC_RELEASE_APP_ID`: the numeric App ID
   - `SEMANTIC_RELEASE_APP_PRIVATE_KEY`: full PEM content including `BEGIN/END` lines

### 3. Install the App

1. In the app page, open **Install App**.
2. Install to the org/user that owns the repo.
3. Grant access to the target repository (or all repos as needed).

### 4. Verify Workflow Configuration

When `github_app` is selected, workflow should include:

- `actions/create-github-app-token@v1`
- `actions/checkout@v4` using `token: steps.app-token.outputs.token`
- semantic-release with `GITHUB_TOKEN` set to the app token

## Configure Bypass Rules for `main`

If your `main` branch is protected, allow semantic-release to push release commits.

### Rulesets (recommended)

1. Go to `Settings` -> `Rules` -> `Rulesets`.
2. Open the ruleset applying to `main`.
3. Under **Bypass list**, add your GitHub App (`semantic-release-bot`).
4. Keep bypass scope as narrow as possible:
   - Branch target: `main`
   - Repository scope: only required repositories
5. Save ruleset.

### Classic Branch Protection

1. Go to `Settings` -> `Branches` -> branch protection rule for `main`.
2. If **Restrict who can push to matching branches** is enabled, add the GitHub App as an allowed actor.
3. Keep required status checks enabled.
4. Save changes.

## Security Recommendations

- Prefer `github_app` over a PAT for least-privilege automation.
- Restrict app installation to only repositories that need release automation.
- Rotate the private key periodically and update `SEMANTIC_RELEASE_APP_PRIVATE_KEY`.
