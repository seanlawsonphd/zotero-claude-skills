#!/bin/bash
# Run a throwaway Zotero alongside the real one, for plugin or translator testing.
#
#   scripts/zotero-test-profile.sh start <dir> [--port 23129]   create <dir>/profile + <dir>/data, launch with debug log
#   scripts/zotero-test-profile.sh seed <port> <file.ris>       import items through the instance's connector server
#   scripts/zotero-test-profile.sh stop                         stop the instance started with -profile (real Zotero untouched)
#
# ZOTERO_BIN overrides the binary (default: /Applications/Zotero.app/Contents/MacOS/zotero).
set -euo pipefail
BIN="${ZOTERO_BIN:-/Applications/Zotero.app/Contents/MacOS/zotero}"
cmd="${1:-}"; shift || true
case "$cmd" in
	start)
		DIR="${1:?dir required}"; shift || true; PORT=23129
		while [ $# -gt 0 ]; do case "$1" in --port) PORT="$2"; shift ;; esac; shift; done
		[ -x "$BIN" ] || { echo "Zotero binary not found at $BIN" >&2; exit 1; }
		mkdir -p "$DIR/profile" "$DIR/data"
		cat > "$DIR/profile/prefs.js" <<PREFS
user_pref("extensions.zotero.dataDir", "$DIR/data");
user_pref("extensions.zotero.useDataDir", true);
user_pref("extensions.zotero.firstRun2", false);
user_pref("extensions.zotero.firstRunGuidance", false);
user_pref("extensions.zotero.httpServer.port", $PORT);
user_pref("extensions.zotero.automaticScraperUpdates", false);
user_pref("extensions.zotero.sync.autoSync", false);
user_pref("extensions.zotero.showConnectorVersionWarning", false);
user_pref("app.update.auto", false);
user_pref("app.update.enabled", false);
PREFS
		( cd "$DIR" && nohup "$BIN" -profile "$DIR/profile" -no-remote -ZoteroDebugText > "$DIR/zotero-debug.log" 2>&1 & )
		echo "launched; waiting for the connector server on port $PORT"
		curl -s -m 5 --retry 20 --retry-delay 2 --retry-all-errors -o /dev/null -w "ping HTTP %{http_code}\n" "http://127.0.0.1:$PORT/connector/ping" || echo "server not answering yet; check $DIR/zotero-debug.log"
		echo "debug log: $DIR/zotero-debug.log   (grep for \"Calling bootstrap method\" after installing a plugin)"
		;;
	seed)
		PORT="${1:?port required}"; FILE="${2:?ris/bibtex file required}"
		curl -s -m 60 -X POST "http://127.0.0.1:$PORT/connector/import?session=seed$RANDOM" -H "Content-Type: text/plain" \
			-H "X-Zotero-Connector-API-Version: 3" --data-binary @"$FILE" -w "\nimport HTTP %{http_code}\n" | head -c 1500; echo
		;;
	stop)
		PID=$(pgrep -f "zotero -profile" || true)
		[ -n "$PID" ] || { echo "no throwaway instance running"; exit 0; }
		kill -TERM $PID; for i in $(seq 1 30); do pgrep -f "zotero -profile" >/dev/null || break; python3 -c "import time; time.sleep(0.5)"; done
		pgrep -f "zotero -profile" >/dev/null && kill -KILL $PID || true
		echo "throwaway instance stopped"
		;;
	*) echo "usage: $0 start <dir> [--port N] | seed <port> <file.ris> | stop" >&2; exit 2 ;;
esac
