#!/usr/bin/env python3
import pathlib
import shutil
import subprocess

CI_PROVIDER = "github"
SEMANTIC_RELEASE = False
SECRET_SCANNING = False
TASK_RUNNER = "just"
CONFIGURE_REPO = False
REPO_PROVIDER = "github"
REPO_ORG = "getscaf"
REPO_NAME = "semantic-release-template"
REPO_URL = ""
CREATE_REPO = True
REPO_VISIBILITY = "public"
AUTHOR_NAME = "Six Feet Up"
AUTHOR_EMAIL = "info@sixfeetup.com"

PROJECT_ROOT = pathlib.Path.cwd()
TERMINATOR = "\x1b[0m"
WARNING = "\x1b[1;33m [WARNING]: "
INFO = "\x1b[1;33m [INFO]: "
SUCCESS = "\x1b[1;32m [SUCCESS]: "


def run(
    cmd: list[str], *, cwd: pathlib.Path | None = None, capture_output: bool = False
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        check=True,
        cwd=cwd,
        capture_output=capture_output,
        text=True,
    )


def try_run(cmd: list[str], *, cwd: pathlib.Path | None = None) -> bool:
    return subprocess.run(cmd, cwd=cwd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0


def remove(path: pathlib.Path) -> None:
    if not path.exists():
        return
    if path.is_file() or path.is_symlink():
        path.unlink()
    else:
        shutil.rmtree(path)


def init_git_repo() -> bool:
    if (PROJECT_ROOT / ".git").exists():
        return False
    print(INFO + "Initializing git repository..." + TERMINATOR)
    print(INFO + f"Current working directory: {PROJECT_ROOT}" + TERMINATOR)
    run(["git", "-c", "init.defaultBranch=main", "init", ".", "--quiet"], cwd=PROJECT_ROOT)
    print(SUCCESS + "Git repository initialized." + TERMINATOR)
    return True


def maybe_create_repo() -> None:
    if not CREATE_REPO or not CONFIGURE_REPO:
        return
    if not REPO_ORG.strip() or not REPO_NAME.strip():
        print(WARNING + "Repo org/name not set. Skipping repo creation." + TERMINATOR)
        return
    repo_name = f"{REPO_ORG.strip()}/{REPO_NAME.strip()}"

    if REPO_PROVIDER == "github":
        if not shutil.which("gh"):
            print(WARNING + "gh CLI is not installed. Skipping repo creation." + TERMINATOR)
            return
        if try_run(["gh", "repo", "view", repo_name], cwd=PROJECT_ROOT):
            print(INFO + f"GitHub repository {repo_name} already exists." + TERMINATOR)
            return
        print(INFO + f"Creating GitHub repository {repo_name} ({REPO_VISIBILITY})..." + TERMINATOR)
        created = subprocess.run(
            ["gh", "repo", "create", repo_name, f"--{REPO_VISIBILITY}"],
            capture_output=True,
            text=True,
        )
        if created.returncode != 0:
            error = created.stderr.strip() or created.stdout.strip() or "unknown error"
            print(WARNING + f"Failed to create GitHub repository {repo_name}: {error}" + TERMINATOR)
            return
        print(SUCCESS + f"GitHub repository {repo_name} created." + TERMINATOR)
        return

    if REPO_PROVIDER == "gitlab":
        if not shutil.which("glab"):
            print(WARNING + "glab CLI is not installed. Skipping repo creation." + TERMINATOR)
            return
        if try_run(["glab", "repo", "view", repo_name], cwd=PROJECT_ROOT):
            print(INFO + f"GitLab repository {repo_name} already exists." + TERMINATOR)
            return
        print(INFO + f"Creating GitLab repository {repo_name} ({REPO_VISIBILITY})..." + TERMINATOR)
        created = subprocess.run(
            ["glab", "repo", "create", repo_name, f"--{REPO_VISIBILITY}"],
            capture_output=True,
            text=True,
        )
        if created.returncode != 0:
            error = created.stderr.strip() or created.stdout.strip() or "unknown error"
            print(WARNING + f"Failed to create GitLab repository {repo_name}: {error}" + TERMINATOR)
            return
        print(SUCCESS + f"GitLab repository {repo_name} created." + TERMINATOR)
        return

    print(
        WARNING
        + f"Repo creation not implemented for provider '{REPO_PROVIDER}'. Skipping."
        + TERMINATOR
    )


def configure_git_remote() -> None:
    if not CONFIGURE_REPO:
        return

    repo_url = REPO_URL.strip()
    if not repo_url:
        print(WARNING + "No repo_url provided. Skipping git remote configuration." + TERMINATOR)
        return

    print(INFO + f"repo_url: {repo_url}" + TERMINATOR)
    if try_run(["git", "remote", "get-url", "origin"], cwd=PROJECT_ROOT):
        current_origin = run(["git", "remote", "get-url", "origin"], cwd=PROJECT_ROOT, capture_output=True)
        print(
            INFO
            + f"Remote origin already configured ({current_origin.stdout.strip()}). Skipping add."
            + TERMINATOR
        )
        return

    run(["git", "remote", "add", "origin", repo_url], cwd=PROJECT_ROOT)
    print(SUCCESS + f"Remote origin={repo_url} added." + TERMINATOR)


def run_init_script() -> None:
    run(["bash", "./scripts/init-dev.sh"], cwd=PROJECT_ROOT)


def prune_files() -> None:
    if TASK_RUNNER != "make":
        remove(PROJECT_ROOT / "Makefile")
    if TASK_RUNNER != "task":
        remove(PROJECT_ROOT / "Taskfile.yml")
    if TASK_RUNNER != "just":
        remove(PROJECT_ROOT / "justfile")

    if CI_PROVIDER != "github":
        remove(PROJECT_ROOT / ".github")
    if CI_PROVIDER != "gitlab":
        remove(PROJECT_ROOT / ".gitlab-ci.yml")

    if not SEMANTIC_RELEASE:
        remove(PROJECT_ROOT / "package.json")
        remove(PROJECT_ROOT / "dependencies-init.txt")
        remove(PROJECT_ROOT / "dependencies-dev-init.txt")
        remove(PROJECT_ROOT / ".releaserc.json")
        remove(PROJECT_ROOT / "CHANGELOG.md")
        remove(PROJECT_ROOT / ".github/workflows/semantic-release.yaml")
        remove(PROJECT_ROOT / ".github/workflows/semantic-pull-request.yaml")

    if not SECRET_SCANNING:
        remove(PROJECT_ROOT / ".github/workflows/secret-scan.yaml")


def maybe_initial_commit(initialized_repo: bool) -> None:
    if not initialized_repo:
        return
    if try_run(["git", "rev-parse", "--verify", "HEAD"], cwd=PROJECT_ROOT):
        return

    run(["git", "add", "-A"], cwd=PROJECT_ROOT)
    status = run(["git", "status", "--porcelain"], cwd=PROJECT_ROOT, capture_output=True)
    if not status.stdout.strip():
        return

    commit_result = subprocess.run(
        [
            "git",
            "-c",
            f"user.name={AUTHOR_NAME}",
            "-c",
            f"user.email={AUTHOR_EMAIL}",
            "commit",
            "--no-verify",
            "-m",
            "chore: initialize from template",
        ],
        cwd=PROJECT_ROOT,
    )
    if commit_result.returncode != 0:
        print(
            WARNING
            + "Initial commit failed. Configure git user.name and user.email, then commit manually."
            + TERMINATOR
        )
        return
    print(SUCCESS + "Initial commit created." + TERMINATOR)


def main() -> None:
    initialized_repo = init_git_repo()
    maybe_create_repo()
    configure_git_remote()
    run_init_script()
    prune_files()
    remove(PROJECT_ROOT / ".scaf/post-copy.py")
    try:
        (PROJECT_ROOT / ".scaf").rmdir()
    except OSError:
        pass
    maybe_initial_commit(initialized_repo)


if __name__ == "__main__":
    main()
