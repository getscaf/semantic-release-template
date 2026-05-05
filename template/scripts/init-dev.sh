#!/usr/bin/env bash
set -euo pipefail

if command -v pre-commit >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  pre-commit install || echo "pre-commit install failed; continuing"
fi



echo "Local development setup complete."
