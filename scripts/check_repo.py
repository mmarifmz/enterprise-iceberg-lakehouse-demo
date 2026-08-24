#!/usr/bin/env python3
"""Fast, dependency-free repository checks used locally and in CI."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REQUIRED = [
    "README.md",
    ".env.example",
    "deploy/kind/cluster.yaml",
    "deploy/kubernetes/lakehouse.yaml",
    "scripts/download_adventureworks.py",
    "scripts/deploy-core-local.ps1",
    "scripts/verify-core-local.ps1",
    "jobs/ingest_adventureworks.py",
    "infra/digitalocean/main.tf",
    ".github/workflows/ci.yml",
]
FORBIDDEN = [
    re.compile(r"ghp_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"do[op]_v1_[A-Za-z0-9]{40,}"),
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
]


def main() -> int:
    errors: list[str] = []
    for relative in REQUIRED:
        if not (ROOT / relative).is_file():
            errors.append(f"missing required file: {relative}")

    for path in ROOT.rglob("*"):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.name == ".env.example":
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for pattern in FORBIDDEN:
            if pattern.search(text):
                errors.append(f"possible secret in {path.relative_to(ROOT)}")

    if errors:
        print("Repository checks failed:")
        print("\n".join(f"- {error}" for error in errors))
        return 1
    print(f"Repository checks passed ({len(REQUIRED)} required files; no secret patterns).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
