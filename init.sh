#!/bin/bash
set -e

echo "=== Drilbur Initialization ==="

echo "=== Checking submodules ==="
if [[ ! -f "Vendor/Mole/mole" ]]; then
    echo "Mole submodule not found. Run: git submodule update --init --recursive"
    exit 1
fi

echo "=== Building ==="
make build

echo "=== Verifying ==="
make test

echo ""
echo "=== Next Steps ==="
echo "1. Read feature_list.json to see current feature state"
echo "2. Pick ONE unfinished feature to work on"
echo "3. Run /think to plan it before writing code"
echo "4. Re-run make test before claiming done"
