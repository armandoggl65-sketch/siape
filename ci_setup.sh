#!/usr/bin/env bash
set -euo pipefail
cd /workspaces/siape
git checkout main
git pull
git checkout -b claude/ci-github-actions

mkdir -p '.github/workflows'
cat > '.github/workflows/tests.yml' <<'SIAPE_CI_EOF_1_MARK'
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  pytest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
          cache: "pip"

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt

      - name: Run tests
        run: pytest tests/ -v
SIAPE_CI_EOF_1_MARK

git add -A
git commit -m "Add CI: GitHub Actions workflow to run pytest on push/PR to main"
git push -u origin claude/ci-github-actions
echo "LISTO"