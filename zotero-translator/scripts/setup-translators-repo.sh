#!/bin/bash
# Clone (or refresh) the zotero/translators repo with its tooling ready to use.
#
#   scripts/setup-translators-repo.sh [target-dir]      default: ./translators-repo
#
# Why depth 2: the repo's ESLint plugin runs `git grep '"lastUpdated"' HEAD~1`
# when it loads, so a depth-1 clone makes `npm run lint` fail with
# "ESLint configuration of processor ... 'zotero-translator/translator' was not found".
set -euo pipefail
DIR="${1:-translators-repo}"

if [ -d "$DIR/.git" ]; then
	echo "Refreshing existing clone in $DIR"
	git -C "$DIR" fetch -q --deepen=1 origin || true
	git -C "$DIR" pull -q --ff-only || true
else
	git clone -q --depth 2 https://github.com/zotero/translators.git "$DIR"
	echo "Cloned zotero/translators into $DIR"
fi

# Node 22 via nvm when available (the .bin tools need Node 18+, Playwright likes 20+)
if [ -s "${NVM_DIR:-$HOME/.nvm}/nvm.sh" ]; then
	# shellcheck disable=SC1091
	. "${NVM_DIR:-$HOME/.nvm}/nvm.sh" >/dev/null 2>&1
	nvm use 22 >/dev/null 2>&1 || nvm use --lts >/dev/null 2>&1 || true
fi
echo "node $(node -v)"

(cd "$DIR" && npm ci --no-audit --no-fund >/dev/null 2>&1 && echo "npm ci done (eslint, zotero-translator plugin, playwright)")

cat <<MSG

Ready. Work from inside $DIR with:
  node .bin/init-translator.mjs --label "<Label>" --creator "<Name>" --target '<regex>' --type web
  node .bin/inspect-page.mjs "<url>" --selector h1 --eval '<js>'
  node .bin/create-test.mjs "<Label>.js" --url "<url>"
  node .bin/update-metadata.mjs "<Label>.js" && npm run lint -- "<Label>.js"
  node .bin/run-tests.mjs "<Label>.js" --no-dependents
The first create-test/run-tests call builds the Zotero Connector into .ci/pull-request-check/connectors (~165 MB).
Remember to run: export NVM_DIR="\$HOME/.nvm"; . "\$NVM_DIR/nvm.sh"; nvm use 22   in each new shell.
MSG
