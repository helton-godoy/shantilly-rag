import os
import subprocess
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]
CONFIG_PATH = ROOT / "config" / "sources.yaml"
RAW_DIR = ROOT / "data" / "raw"


def load_sources():
    with CONFIG_PATH.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def clone_or_update_repo(owner_repo: str) -> None:
    """Clona ou atualiza um repositório GitHub em data/raw/github/owner/repo.

    Espera uma string no formato "owner/repo".
    """
    owner, repo = owner_repo.split("/", 1)
    target_dir = RAW_DIR / "github" / owner / repo
    ensure_dir(target_dir.parent)

    if not target_dir.exists():
        subprocess.run([
            "git",
            "clone",
            f"https://github.com/{owner_repo}.git",
            str(target_dir),
        ], check=True)
    else:
        subprocess.run([
            "git",
            "-C",
            str(target_dir),
            "pull",
            "--ff-only",
        ], check=True)


def main() -> None:
    ensure_dir(RAW_DIR)

    data = load_sources() or {}

    for group_key in ("charmbracelet_official", "derived_projects", "go_libraries"):
        for entry in data.get(group_key, []) or []:
            repo = entry.get("repo")
            if not repo:
                continue
            print(f"[fetch] {group_key}: {repo}")
            clone_or_update_repo(repo)

    # TODO: baixar manual_docs (HTML/markdown) e salvar em data/raw/web


if __name__ == "__main__":
    main()
