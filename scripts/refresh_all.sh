#!/usr/bin/env bash
set -euo pipefail

python scripts/fetch_sources.py
python scripts/build_chunks.py
python scripts/index_qdrant.py
