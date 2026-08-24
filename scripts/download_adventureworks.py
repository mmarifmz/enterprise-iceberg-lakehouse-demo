#!/usr/bin/env python3
"""Download a focused AdventureWorksDW CSV subset from Microsoft's official repository."""

from __future__ import annotations

import argparse
import hashlib
import json
import urllib.request
from pathlib import Path

BASE_URL = (
    "https://raw.githubusercontent.com/microsoft/sql-server-samples/master/"
    "samples/databases/adventure-works/data-warehouse-install-script"
)
FILES = (
    "DimCustomer.csv",
    "DimDate.csv",
    "DimProduct.csv",
    "DimProductCategory.csv",
    "DimProductSubcategory.csv",
    "FactInternetSales.csv",
)


def download(output: Path) -> dict[str, dict[str, object]]:
    output.mkdir(parents=True, exist_ok=True)
    manifest: dict[str, dict[str, object]] = {}
    for name in FILES:
        destination = output / name
        request = urllib.request.Request(f"{BASE_URL}/{name}", headers={"User-Agent": "lakehouse-demo"})
        with urllib.request.urlopen(request, timeout=120) as response:
            payload = response.read()
        destination.write_bytes(payload)
        manifest[name] = {
            "bytes": len(payload),
            "sha256": hashlib.sha256(payload).hexdigest(),
            "source": f"{BASE_URL}/{name}",
        }
        print(f"downloaded {name} ({len(payload):,} bytes)")
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("data/adventureworks"))
    args = parser.parse_args()
    download(args.output)


if __name__ == "__main__":
    main()

