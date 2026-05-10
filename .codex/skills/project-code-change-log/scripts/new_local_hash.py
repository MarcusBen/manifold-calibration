#!/usr/bin/env python3
"""Generate a short pending local hash for one code-change batch."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import secrets
import subprocess


def current_head() -> str:
    try:
        return subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return "no-git-head"


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a pending local version hash such as local-a1b2c3d4."
    )
    parser.add_argument("--prefix", default="local")
    parser.add_argument("--length", type=int, default=8)
    parser.add_argument("--scope", default="")
    args = parser.parse_args()

    timestamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    seed = "|".join(
        [
            timestamp,
            current_head(),
            args.scope,
            secrets.token_hex(16),
        ]
    )
    digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()[: args.length]
    print(f"{args.prefix}-{digest}")


if __name__ == "__main__":
    main()
