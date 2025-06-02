#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"        # always run from the script’s folder
source .venv/bin/activate
for s in {1..6}_import*.py; do
  echo "▶ running ${s} ..."
  python "$s"
done
