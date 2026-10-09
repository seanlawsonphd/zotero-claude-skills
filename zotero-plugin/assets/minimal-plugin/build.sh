#!/bin/bash
# Packages src/ into build/{{PLUGIN_SLUG}}-<version>.xpi and prints its SHA-256
# (the hash goes into updates.json for Zotero's automatic plugin updates).
set -euo pipefail
cd "$(dirname "$0")"
VERSION=$(grep -o '"version": *"[^"]*"' src/manifest.json | head -1 | sed 's/.*: *"\(.*\)"/\1/')
mkdir -p build
XPI="build/{{PLUGIN_SLUG}}-$VERSION.xpi"
rm -f "$XPI"
(cd src && zip -r -X "../$XPI" . -x '.*' -x '*/.*')
echo
echo "Built $XPI"
echo "sha256:$(shasum -a 256 "$XPI" | cut -d' ' -f1)"
