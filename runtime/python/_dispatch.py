#!/usr/bin/env python3
from __future__ import annotations

import os
import sys
from pathlib import Path


def _candidates() -> list[Path]:
    here = Path(__file__).resolve()
    return [
        here.parents[2],
        Path.home() / ".local" / "share" / "coderabbit-fixer",
    ]


def resolve_bash_target(command_name: str) -> Path:
    for base in _candidates():
        target = base / "runtime" / "bash" / command_name
        if target.is_file():
            return target
    raise FileNotFoundError(
        f"Could not locate bash implementation for '{command_name}'."
    )


def main(command_name: str) -> "None":
    target = resolve_bash_target(command_name)
    os.execv(str(target), [str(target), *sys.argv[1:]])
