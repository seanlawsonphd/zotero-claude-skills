---
name: zotero-plugin
description: Build, test, package, and publish Zotero 7+ plugins (XPI add-ons that run inside the Zotero desktop app), either as a minimal bootstrap plugin or with the windingwind zotero-plugin-template (TypeScript, zotero-plugin-toolkit, zotero-plugin-scaffold). Use this whenever the user wants a Zotero plugin, add-on, or extension, a new item context-menu command, toolbar or menu item, preference pane, item-pane section or column inside Zotero, wants to turn a Run JavaScript snippet into something clickable, asks why a plugin "may be incompatible with this version of Zotero", or wants to release a plugin on GitHub with auto-updates, even if they only say "can we make this a plugin".
---

# Zotero plugins

A Zotero plugin is a zip renamed `.xpi` containing `manifest.json` plus a `bootstrap.js` whose functions Zotero calls on install, startup, window load, shutdown, and uninstall. Plugin code runs in a sandbox with `Zotero` and `Services` as globals and full access to Zotero's internal APIs. Two ways to build one:

| | Minimal bootstrap | windingwind template |
|---|---|---|
| Best for | One or two commands, a menu item, a small tool; no build step | Larger plugins: preference pane, item-pane sections, columns, shortcuts, dialogs, localization in several languages |
| Language | Plain JavaScript, 3 to 5 files | TypeScript, esbuild, `zotero-plugin-toolkit` helpers, typed Zotero API (`zotero-types`) |
| Workflow | `./build.sh` zips `src/`; install via Tools > Plugins | `npm start` hot-reloads into a dev Zotero; `npm run build`; `npm run release` via GitHub Actions |
| Reference | `references/minimal-bootstrap.md` | `references/windingwind-template.md` |

Pick minimal when the whole plugin fits in a few hundred lines; pick the template when the plugin has UI surface or will grow. Both share the same manifest rules, Zotero APIs, testing method, and release mechanics below. `references/zotero-apis.md` is the API cheat sheet for either; `references/testing-and-release.md` covers verification and publishing.

## Facts that cost a day to learn

1. **Three manifest fields are mandatory in Zotero's loader**: `applications.zotero.id`, `applications.zotero.update_url`, and `applications.zotero.strict_max_version`. Zotero's patched `Extension.sys.mjs` rejects the manifest if any is missing, and every rejection surfaces as the same dialog, "could not be installed. It may be incompatible with this version of Zotero". Mozilla's loader treats `strict_max_version` as optional, so examples from the Firefox world mislead here. `scripts/check-manifest.py` replicates these checks; run it before every install.
2. **Choose `strict_max_version` deliberately.** `10.*` means "all Zotero 10.x"; the docs suggest the last minor you tested (`10.0.*`). Zotero disables the plugin for users on a newer major until you raise it, which you can do in `updates.json` without a new release. The windingwind template ships with `8.*`; raise it for the installed Zotero (`/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' /Applications/Zotero.app/Contents/Info.plist`).
3. **Sideloading does not exist.** Dropping an `.xpi` or a pointer file into a profile's `extensions/` folder is ignored by current Zotero, whatever the scope prefs say. Install through Tools > Plugins > gear > Install Plugin From File, or from Run JavaScript with `AddonManager.installTemporaryAddon(file)`. Zotero reloads a bootstrapped plugin on reinstall without a restart.
4. **Menus: use `Zotero.MenuManager.registerMenu`** (Zotero 7.1+) with `target: "main/library/item"` for the item context menu; the command receives `context.items` (selected `Zotero.Item`s). Labels come only from Fluent: ship `locale/en-US/<slug>.ftl`, give the menu an `l10nID`, and call `window.MozXULElement.insertFTLIfNeeded('<slug>.ftl')` in `onMainWindowLoad` and for existing windows at startup, or the item renders with no label. Keep a DOM-injection fallback (`doc.getElementById('zotero-itemmenu')`) for Zotero 7.0.
5. **Clean up on shutdown**: unregister menus, remove injected elements and the `<link rel="localization">`, drop globals. Zotero disables and re-enables plugins without restarting.
6. **Long work needs feedback**: `Zotero.ProgressWindow` with one `ItemProgress` line per item (`setProgress(50)`, then `100` or `setError()`), a `changeHeadline` summary, and `startCloseTimer`.
7. **When unsure about an API, read Zotero's own source** from the installed app: `unzip -o /Applications/Zotero.app/Contents/Resources/app/omni.ja 'chrome/content/zotero/xpcom/pluginAPI/*' 'chrome/content/zotero/xpcom/plugins.js' -d /tmp/zotero-src`. The menu manager, item-pane manager, and item-tree manager each document their option schema in JSDoc at the top of the file. Zotero 10 is built on Firefox ESR 140.

## Minimal bootstrap workflow

```bash
scripts/new-minimal-plugin.sh --name "Copy DOIs" --slug copy-dois --id copy-dois@yourname \
  --author "Your Name" --repo https://github.com/yourname/zotero-copy-dois --dir ~/code/zotero-copy-dois
```

This copies `assets/minimal-plugin/` (manifest, bootstrap, main object with a working item-menu command, FTL file, build script, update manifest, README, MIT license) and fills in the placeholders. Then:

1. Edit `src/<slug>.js`: put the real work in `run(items)`; keep `init/registerMenu/addToWindow/removeFromWindow` as they are unless you add UI.
2. `./build.sh` writes `build/<slug>-<version>.xpi` and prints its SHA-256.
3. `python3 scripts/check-manifest.py build/<slug>-<version>.xpi` before handing it over.
4. Test (next section), then publish (`references/testing-and-release.md`).

## Template workflow (summary; details in the reference)

```bash
gh repo create yourname/zotero-my-plugin --template windingwind/zotero-plugin-template --public --clone
cd zotero-my-plugin && cp .env.example .env    # set ZOTERO_PLUGIN_ZOTERO_BIN_PATH and a dev profile path
# edit package.json: version, description, config.addonName/addonID/addonRef/addonInstance/prefsPrefix, repository, author
# raise addon/manifest.json strict_max_version
npm install && npm start                        # builds, launches Zotero with the plugin, hot-reloads on save
```

Put features in `src/modules/*.ts`, wire them in `src/hooks.ts` (`onStartup`, `onMainWindowLoad`, `onShutdown`), strings in `addon/locale/<lang>/*.ftl` (the build prefixes message ids with `addonRef-`), preferences in `addon/prefs.js` + `addon/content/preferences.xhtml`. `npm run build` produces `.scaffold/build/*.xpi`; `npm run release` bumps the version, tags, and lets the GitHub Action publish the XPI and `update.json` to a `release` tag.

## Testing without touching the user's library

Use a throwaway profile and data directory so the user's real library is never at risk:

```bash
scripts/zotero-test-profile.sh start /tmp/zt-profile --port 23129     # launches Zotero with -profile, -no-remote, debug log
scripts/zotero-test-profile.sh seed 23129 items.ris                    # imports test items over the connector API
scripts/zotero-test-profile.sh stop
```

Then install the XPI in that instance (Tools > Plugins), exercise the command, and read the debug log for `Calling bootstrap method 'startup' for plugin <id>` and any `Error running bootstrap method` lines. Caveats: the second Zotero shares the first one's bundle id, so GUI-automation tools that address apps by bundle id see only the first instance; coordinate-based clicks still work, as does asking the user to test in their own Zotero. `references/testing-and-release.md` has the full procedure, including what every failure dialog means.

## Release mechanics

Zotero auto-updates plugins from the `update_url` in the manifest: a JSON file listing versions with `update_link` (the XPI download) and `update_hash` (`sha256:` of that exact file). For the minimal variant, keep `updates.json` in the repo and point `update_url` at its raw GitHub URL; attach the XPI to a GitHub release and put the release asset URL in `update_link`. Verify after publishing by downloading the asset and comparing hashes. Commands and the version-bump checklist are in `references/testing-and-release.md`.
