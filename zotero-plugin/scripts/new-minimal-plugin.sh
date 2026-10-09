#!/bin/bash
# Create a minimal Zotero plugin project from assets/minimal-plugin.
#
#   scripts/new-minimal-plugin.sh --name "Copy DOIs" --slug copy-dois --id copy-dois@yourname \
#       --author "Your Name" --repo https://github.com/yourname/zotero-copy-dois --dir ~/code/zotero-copy-dois \
#       [--description "One sentence"] [--menu-label "Copy DOIs"] [--max-version 10.*]
#
# Produces src/ (manifest.json, bootstrap.js, <slug>.js, locale/en-US/<slug>.ftl), build.sh,
# updates.json, README.md, LICENSE (MIT), .gitignore with every placeholder filled in.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
NAME=""; SLUG=""; ID=""; AUTHOR=""; REPO=""; DIR=""; DESC=""; LABEL=""; MAXV=""
while [ $# -gt 0 ]; do
	case "$1" in
		--name) NAME="$2"; shift ;;
		--slug) SLUG="$2"; shift ;;
		--id) ID="$2"; shift ;;
		--author) AUTHOR="$2"; shift ;;
		--repo) REPO="$2"; shift ;;
		--dir) DIR="$2"; shift ;;
		--description) DESC="$2"; shift ;;
		--menu-label) LABEL="$2"; shift ;;
		--max-version) MAXV="$2"; shift ;;
		*) echo "unknown option $1" >&2; exit 2 ;;
	esac
	shift
done
[ -n "$NAME" ] && [ -n "$SLUG" ] && [ -n "$ID" ] && [ -n "$AUTHOR" ] && [ -n "$REPO" ] && [ -n "$DIR" ] || {
	echo "usage: $0 --name <Name> --slug <slug> --id <id@domain> --author <Name> --repo <https url> --dir <path> [--description ..] [--menu-label ..] [--max-version ..]" >&2; exit 2; }
echo "$SLUG" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || { echo "slug must be lowercase letters, digits, dashes" >&2; exit 2; }
echo "$ID" | grep -Eq '^([a-z0-9._-]+@[a-z0-9._-]+|\{[0-9a-f-]{36}\})$' || { echo "id must look like name@domain or be a GUID" >&2; exit 2; }
[ -e "$DIR" ] && { echo "error: $DIR already exists" >&2; exit 1; }
[ -n "$DESC" ] || DESC="$NAME for Zotero."
[ -n "$LABEL" ] || LABEL="$NAME"
if [ -z "$MAXV" ]; then
	V=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Zotero.app/Contents/Info.plist 2>/dev/null || echo "")
	MAXV="${V%%.*}.*"; [ "$MAXV" != ".*" ] || MAXV="10.*"
fi
# PascalCase object name from the slug: copy-dois -> CopyDois
OBJ=$(echo "$SLUG" | awk -F- '{for (i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}')
RAW=$(echo "$REPO" | sed -E 's#https://github.com/#https://raw.githubusercontent.com/#')

cp -R "$HERE/assets/minimal-plugin" "$DIR"
mv "$DIR/src/plugin.js" "$DIR/src/$SLUG.js"
mv "$DIR/src/locale/en-US/plugin.ftl" "$DIR/src/locale/en-US/$SLUG.ftl"
python3 "$HERE/scripts/fill-placeholders.py" "$DIR" "PLUGIN_NAME=$NAME" "PLUGIN_SLUG=$SLUG" "PLUGIN_ID=$ID" \
	"AUTHOR=$AUTHOR" "REPO_URL=$REPO" "RAW_REPO_URL=$RAW" "DESCRIPTION=$DESC" "MENU_LABEL=$LABEL" \
	"MAX_VERSION=$MAXV" "PLUGIN_OBJECT=$OBJ"
chmod +x "$DIR/build.sh"
echo "created $DIR"
find "$DIR" -type f | sed "s#^$DIR/##" | sort
cat <<MSG

Next:
  1. Implement processItem()/run() in src/$SLUG.js
  2. ./build.sh                       -> build/$SLUG-1.0.0.xpi + sha256
  3. python3 $HERE/scripts/check-manifest.py build/$SLUG-1.0.0.xpi
  4. Install in Zotero: Tools > Plugins > gear > Install Plugin From File
  5. Put the sha256 into updates.json before the GitHub release
MSG
