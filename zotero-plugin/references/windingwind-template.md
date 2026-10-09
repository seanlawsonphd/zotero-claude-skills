# windingwind/zotero-plugin-template

TypeScript plugin skeleton maintained by the author of Better Notes and PDF Translate. It bundles `zotero-plugin-toolkit` (UI, menu, progress-window, keyboard, prompt, dialog helpers that clean up after themselves), `zotero-plugin-scaffold` (build, hot reload, test, release), and `zotero-types` (typings for Zotero's internals). Use it when the plugin has real UI or will keep growing.

## Create the project

```bash
gh repo create <user>/zotero-<slug> --template windingwind/zotero-plugin-template --public --clone
cd zotero-<slug>
cp .env.example .env
```

`.env` needs `ZOTERO_PLUGIN_ZOTERO_BIN_PATH=/Applications/Zotero.app/Contents/MacOS/zotero` and `ZOTERO_PLUGIN_PROFILE_PATH=<a development profile>` (create one once with `zotero -p`, or point at a throwaway profile made by `scripts/zotero-test-profile.sh`; never the user's daily profile, hot reload restarts Zotero). `ZOTERO_PLUGIN_DATA_DIR` may stay empty.

Edit `package.json`:

```jsonc
{
  "version": "0.1.0",
  "description": "What the plugin does",
  "config": {
    "addonName": "Reading Queue",            // shown in the Plugins pane
    "addonID": "reading-queue@seanlawsonphd", // permanent identity, must be unique
    "addonRef": "readingqueue",              // element-id and chrome:// prefix, lowercase, no dashes
    "addonInstance": "ReadingQueue",         // Zotero.ReadingQueue is the plugin object
    "prefsPrefix": "extensions.zotero.readingqueue"
  },
  "repository": { "type": "git", "url": "git+https://github.com/<user>/zotero-<slug>.git" },
  "author": "Name", "homepage": "...", "bugs": { "url": "..." }
}
```

`addon/manifest.json` uses `__placeholders__` filled from that block at build time; the only thing to edit there is `strict_max_version` (shipped as `8.*`; raise to the installed Zotero, e.g. `10.*`). `zotero-plugin.config.ts` sets `updateURL` to `https://github.com/{{owner}}/{{repo}}/releases/download/release/update.json`, which the release workflow maintains; leave it unless hosting elsewhere.

Then `npm install` (use `npm i -f` if typescript-eslint peer conflicts appear).

## Day-to-day

- `npm start`: builds in development mode, launches Zotero from `.env` with the plugin loaded from `.scaffold/build`, watches `src/**` and `addon/**`, rebuilds and reloads on save.
- `npm run build`: production build, `.scaffold/build/<name>.xpi`, plus `update.json`.
- `npm test`: mocha tests in `test/` run inside Zotero (`test/startup.test.ts` checks `Zotero.<addonInstance>` exists; `waitForPlugin` in the config waits for `addon.data.initialized`).
- `npm run lint:fix`: prettier + eslint.
- Debug: `ztoolkit.log(...)` (console disabled in production), Zotero's Help > Debug Output Logging, Tools > Developer > Run JavaScript.

## Where code goes

- `src/index.ts`: creates the `Addon` instance, defines globals `addon` and `ztoolkit`, attaches `Zotero.<addonInstance>`. Rarely edited.
- `src/addon.ts`: the `Addon` class holding `data` (env, config, ztoolkit, prefs window, dialog) and `hooks`.
- `src/hooks.ts`: lifecycle dispatch only. `onStartup` awaits `Zotero.initializationPromise`, `unlockPromise`, `uiReadyPromise`, then registers prefs/notifier/columns/sections and calls `onMainWindowLoad` for each existing window; `onMainWindowLoad(win)` creates a fresh ztoolkit, `win.MozXULElement.insertFTLIfNeeded(\`${addonRef}-mainWindow.ftl\`)`, registers menus and window-bound UI; `onMainWindowUnload`/`onShutdown` call `ztoolkit.unregisterAll()` and delete `Zotero.<addonInstance>`. Keep real work in modules and have hooks dispatch to them.
- `src/modules/*.ts`: features. `examples.ts` ships working samples for every common API; delete what you do not use.
- `src/utils/locale.ts` (`getString('message-id')`, `initLocale()`), `src/utils/prefs.ts` (`getPref`/`setPref` keyed under `prefsPrefix`), `src/utils/ztoolkit.ts` (toolkit instance and options).
- `addon/bootstrap.js`: registers `chrome://<addonRef>/content/` and loads the bundled script; do not edit.
- `addon/content/`: static assets, `preferences.xhtml`, icons, CSS; `addon/prefs.js`: default prefs (`pref("enable", true)` is prefixed at build time); `addon/locale/<lang>/*.ftl`: strings (ids are prefixed with `addonRef-` at build time, and TypeScript typings for them are generated).

## Toolkit APIs the template demonstrates (src/modules/examples.ts)

```ts
// item context menu
ztoolkit.Menu.register("item", {
  tag: "menuitem", id: "zotero-itemmenu-readingqueue-mark", label: getString("menuitem-label"),
  icon: `chrome://${addon.data.config.addonRef}/content/icons/favicon@0.5x.png`,
  commandListener: (ev) => addon.hooks.onDialogEvents("markQueued"),
});
ztoolkit.Menu.register("menuFile", { tag: "menuseparator" });              // menubar menus: menuFile, menuEdit, menuView, menuTools, menuHelp

// progress popup
new ztoolkit.ProgressWindow(addon.data.config.addonName)
  .createLine({ text: "Done", type: "success", progress: 100 }).show();

// preferences pane (native Zotero API)
Zotero.PreferencePanes.register({ pluginID: addon.data.config.addonID, src: rootURI + "content/preferences.xhtml", label: getString("prefs-title"), image: ... });

// extra item-tree column (native API, async)
await Zotero.ItemTreeManager.registerColumns({ pluginID, dataKey: "queued", label: "Queued", dataProvider: (item, dataKey) => ... });

// item pane section / info row (native API)
Zotero.ItemPaneManager.registerSection({ paneID, pluginID, header: {...}, sidenav: {...}, onRender: ({ body, item }) => ... });
Zotero.ItemPaneManager.registerInfoRow({ rowID, pluginID, label: {...}, onGetData: ({ item }) => ... });

// keyboard shortcuts, notifier, dialogs, prompt palette
ztoolkit.Keyboard.register((ev, keyOptions) => {...});
Zotero.Notifier.registerObserver({ notify: (event, type, ids, extraData) => {...} }, ["item"]);
new ztoolkit.Dialog(rows, cols).addCell(...).open("Title");
ztoolkit.Prompt.register([{ name: "Command", label: "Plugin", callback: (prompt) => {...} }]);
```

Elements created with `ztoolkit.UI.createElement(doc, tag, props)` are tracked and removed by `ztoolkit.unregisterAll()`.

## Release

`npm run release` runs bumpp: prompts for the new version, bumps `package.json`, commits, tags `v<version>`, pushes. The template's GitHub Action then builds and publishes the XPI to that tag's release and refreshes `update.json` (and `update-beta.json` for prerelease versions) on a rolling `release` tag, which is what `updateURL` points at. Publishing from a local machine instead needs `GITHUB_TOKEN` in `.env`. Check the Actions run finished before announcing the release.

## Gotchas

- Hot reload restarts the configured Zotero; point it at a development profile.
- `addonRef` becomes part of element ids, chrome URLs, and FTL prefixes; changing it later touches everything.
- Prefs read with `Zotero.Prefs.get(key, true)` need the full key including `extensions.zotero.`; `getPref` adds the prefix for you.
- Keep `strict_max_version` current in `addon/manifest.json`; the scaffold copies it into `update.json`.
