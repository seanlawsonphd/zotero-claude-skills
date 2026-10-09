#!/bin/bash
# Install a translator file into the Zotero data directory's translators/ folder.
#
#   scripts/install-translator.sh <Translator.js> [--force] [--keep-copy-in <dir>] [--data-dir <zotero data dir>]
#
# Finds the data directory from the Zotero profile's prefs.js (extensions.zotero.dataDir),
# falling back to ~/Zotero. Refuses to overwrite an existing file unless --force, because
# the folder also holds the ~750 official translators that Zotero keeps up to date.
set -euo pipefail
FILE=""; FORCE=0; KEEP=""; DATADIR=""
while [ $# -gt 0 ]; do
	case "$1" in
		--force) FORCE=1 ;;
		--keep-copy-in) KEEP="$2"; shift ;;
		--data-dir) DATADIR="$2"; shift ;;
		*) FILE="$1" ;;
	esac
	shift
done
[ -n "$FILE" ] && [ -f "$FILE" ] || { echo "usage: $0 <Translator.js> [--force] [--keep-copy-in <dir>] [--data-dir <dir>]" >&2; exit 2; }
head -c 1 "$FILE" | grep -q '{' || { echo "error: $FILE does not start with a JSON header" >&2; exit 2; }

if [ -z "$DATADIR" ]; then
	for prefs in "$HOME/Library/Application Support/Zotero/Profiles"/*/prefs.js "$HOME/.zotero/zotero"/*/prefs.js; do
		[ -f "$prefs" ] || continue
		if grep -q '"extensions.zotero.useDataDir", true' "$prefs"; then
			DATADIR=$(grep '"extensions.zotero.dataDir"' "$prefs" | sed -E 's/.*"extensions.zotero.dataDir", "([^"]*)".*/\1/')
		fi
		[ -n "$DATADIR" ] && break
	done
	[ -n "$DATADIR" ] || DATADIR="$HOME/Zotero"
fi
DEST="$DATADIR/translators"
[ -d "$DEST" ] || { echo "error: $DEST does not exist; is $DATADIR really the Zotero data directory?" >&2; exit 1; }

NAME=$(basename "$FILE")
if [ -e "$DEST/$NAME" ] && [ "$FORCE" -ne 1 ]; then
	echo "error: $DEST/$NAME already exists; pass --force to overwrite" >&2; exit 1
fi
cp "$FILE" "$DEST/$NAME" && echo "installed: $DEST/$NAME"
if [ -n "$KEEP" ]; then
	mkdir -p "$KEEP" && cp "$FILE" "$KEEP/$NAME" && echo "copy kept: $KEEP/$NAME"
fi
cat <<MSG

Next steps for the user:
  1. Restart Zotero (translators are loaded at startup).
  2. Browser Connector preferences > Advanced > "Update Translators", then reload the site.
  3. Keep the copy outside the data directory: Zotero's "Reset Translators" wipes $DEST.
Verify after the restart (read-only):
  curl -s -X POST http://127.0.0.1:23119/connector/getTranslators -H 'Content-Type: application/json' -d '{"url":"<an article url>"}'
MSG
