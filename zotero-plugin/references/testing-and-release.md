# Testing a plugin safely and releasing it

## Throwaway Zotero instance

Never test against the user's library. A second Zotero with its own profile and data directory runs alongside the real one:

```bash
scripts/zotero-test-profile.sh start /tmp/zt-test --port 23129
# writes prefs.js (dataDir, useDataDir, firstRun2=false, httpServer.port, sync and translator updates off),
# launches: zotero -profile /tmp/zt-test/profile -no-remote -ZoteroDebugText > /tmp/zt-test/zotero-debug.log
scripts/zotero-test-profile.sh seed 23129 /path/items.ris      # POST /connector/import, creates test items
scripts/zotero-test-profile.sh stop                            # TERM the -profile instance only
```

A minimal RIS seed:

```
TY  - NEWS
TI  - Example story
PY  - 2026
UR  - https://www.rt.com/russia/646973-montenegro-russian-blogger-detained/
ER  - 
```

Installing the plugin into that instance:
- GUI: Tools > Plugins > gear > Install Plugin From File, pick the XPI.
- Run JavaScript (Tools > Developer), no file dialog: `var {AddonManager} = ChromeUtils.importESModule("resource://gre/modules/AddonManager.sys.mjs"); AddonManager.installTemporaryAddon(Zotero.File.pathToFile("/abs/path/plugin.xpi")).then(a => Zotero.debug("TEMP INSTALL OK " + a.id), e => Zotero.debug("TEMP INSTALL FAIL " + e)); "started"` then check the debug log. Temporary installs load the same way as permanent ones but vanish on restart.
- Not possible: copying the XPI or a pointer file into `<profile>/extensions/`. Current Zotero never scans that folder.

What to read in `zotero-debug.log`:
- `Calling bootstrap method 'startup' for plugin <id> version <v>`: loaded.
- `Error running bootstrap method ...` followed by the exception: your code threw.
- `Plugin <id> is missing bootstrap method 'x'`: harmless unless you expected the hook.
- Nothing mentioning the id at all: the add-on manager rejected the manifest; run `scripts/check-manifest.py`.

Driving Zotero's Run JavaScript window with automation: its code box is a code editor that auto-indents and auto-closes brackets and quotes, so typing a multi-line script produces stray `}` and a SyntaxError, and background GUI tools cannot type into it at all (no accessibility tree). What works: select-all, delete, then type one line, `eval(atob("<base64 of the script>"))`, and click Run; the result pane shows the value of the script's last expression. Use `return` only with "Run as async function" ticked.

Driving the test instance with GUI automation: both Zoteros share bundle id `org.zotero.zotero`, so tools that address an app by bundle id reach only the first process. Screen-coordinate clicks work; so does simply asking the user to try it in their own Zotero once the manifest check passes.

## Reading the user's failure dialogs

"The add-on ... could not be installed. It may be incompatible with this version of Zotero." covers every install failure. Check in order: required manifest fields (id, update_url, strict_max_version), `strict_min_version` without `*`, `strict_max_version` >= installed version, `manifest.json` at the zip root, valid JSON, and a plugin id that is unique and well-formed (`name@domain` or GUID).

## GitHub repository and release (minimal variant)

```bash
cd <plugin repo>
git init -b main && git add -A && git commit -m "Initial release"      # set user.name/email per repo if no global identity
gh repo create <user>/<repo> --public --source=. --remote=origin --push --description "..."
gh repo edit <user>/<repo> --add-topic zotero --add-topic zotero-plugin
./build.sh                                                            # prints sha256; put it in updates.json with the release URL
git commit -am "Release v1.0.0" && git push
gh release create v1.0.0 build/<slug>-1.0.0.xpi --title "v1.0.0" --notes "..."
# verify: the released asset must hash to what updates.json says
curl -sL -o /tmp/released.xpi https://github.com/<user>/<repo>/releases/download/v1.0.0/<slug>-1.0.0.xpi && shasum -a 256 /tmp/released.xpi
curl -s https://raw.githubusercontent.com/<user>/<repo>/main/updates.json
```

`gh auth status` must show a valid token (`gh auth login -h github.com` if not); `gh repo create --template windingwind/zotero-plugin-template` works for the template variant.

Hold the release until the plugin has been exercised at least once (by you in the throwaway instance or by the user); pushing the repo earlier is fine because nothing installs from `main`.

## Updating

1. Bump `version` in `src/manifest.json` (minimal) or `npm run release` (template).
2. Rebuild; put the new `update_link`, `update_hash`, and any raised `strict_max_version` into `updates.json`; commit and push.
3. Create the GitHub release with the new XPI. Installed copies pick it up on Zotero's next update check (daily) or via Tools > Plugins > gear > Check for Updates.
4. Extending compatibility to a new Zotero major needs only a changed `strict_max_version` in `updates.json`, no new XPI, if the code still works.
