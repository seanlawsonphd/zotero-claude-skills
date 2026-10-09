# Minimal bootstrap plugin (the make-it-red shape)

Layout produced by `scripts/new-minimal-plugin.sh`:

```
my-plugin/
├── src/                       # everything in here goes into the XPI, at the zip root
│   ├── manifest.json
│   ├── bootstrap.js           # Zotero calls these functions
│   ├── <slug>.js              # the plugin object, loaded by bootstrap.js
│   └── locale/en-US/<slug>.ftl
├── build.sh                   # zips src/ -> build/<slug>-<version>.xpi, prints sha256
├── updates.json               # what Zotero polls for updates (update_url points here)
├── README.md, LICENSE, .gitignore
```

## manifest.json

```json
{
	"manifest_version": 2,
	"name": "Add Missing Snapshots",
	"version": "1.0.0",
	"description": "One sentence shown in the Plugins pane.",
	"author": "Sean Lawson",
	"homepage_url": "https://github.com/seanlawsonphd/zotero-add-missing-snapshots",
	"applications": {
		"zotero": {
			"id": "add-missing-snapshots@seanlawsonphd",
			"update_url": "https://raw.githubusercontent.com/seanlawsonphd/zotero-add-missing-snapshots/main/updates.json",
			"strict_min_version": "7.0",
			"strict_max_version": "10.*"
		}
	}
}
```

- `id`: `something@somewhere` or a GUID; it is the plugin's permanent identity for updates and prefs.
- `update_url` must be https. `strict_min_version` may not contain `*`; `strict_max_version` must exist (Zotero's loader requirement).
- `icons` is optional (`{"48": "icon.png", "96": "icon@2x.png"}` relative to the zip root).

## bootstrap.js

```js
/* global Zotero, Services */
var MyPlugin;

function install() {}

async function startup({ id, version, rootURI }) {
	Services.scriptloader.loadSubScript(rootURI + 'my-plugin.js');   // defines the global MyPlugin
	MyPlugin.init({ id, version, rootURI });
	MyPlugin.addToAllWindows();      // windows already open when installed at runtime
}
function onMainWindowLoad({ window }) { MyPlugin.addToWindow(window); }
function onMainWindowUnload({ window }) { MyPlugin.removeFromWindow(window); }
function shutdown() {
	MyPlugin.removeFromAllWindows();
	MyPlugin.unregisterMenu();
	MyPlugin = undefined;
}
function uninstall() {}
```

Zotero passes `{ id, version, rootURI }` (rootURI ends with `/`) and a reason code to every hook, awaits returned promises, and logs any thrown error as `Error running bootstrap method '<name>' on <id>` in the debug output. `onMainWindowLoad` fires for each main window after startup, which is why `startup` must also handle windows that already exist.

## The plugin object

```js
MyPlugin = {
	id: null, version: null, rootURI: null, initialized: false, menuID: null,
	FTL_FILE: 'my-plugin.ftl',
	MENUITEM_ID: 'my-plugin-menuitem',
	MENU_L10N_ID: 'my-plugin-menuitem',

	init({ id, version, rootURI }) {
		if (this.initialized) return;
		Object.assign(this, { id, version, rootURI, initialized: true });
		this.registerMenu();
	},
	log(msg) { Zotero.debug(`My Plugin: ${msg}`); },

	useMenuManager() { return !!(Zotero.MenuManager && Zotero.MenuManager.registerMenu); },

	registerMenu() {
		if (!this.useMenuManager()) return;
		this.menuID = Zotero.MenuManager.registerMenu({
			menuID: 'my-plugin-item-menu',
			pluginID: this.id,
			target: 'main/library/item',
			menus: [{
				menuType: 'menuitem',
				l10nID: this.MENU_L10N_ID,
				onShowing: (_event, context) => context.setEnabled(context.items.some(i => i.isRegularItem())),
				onCommand: (_event, context) => this.run(context.items),
			}],
		});
	},
	unregisterMenu() {
		if (this.menuID && this.useMenuManager()) Zotero.MenuManager.unregisterMenu(this.menuID);
		this.menuID = null;
	},

	addToWindow(window) {
		window.MozXULElement.insertFTLIfNeeded(this.FTL_FILE);     // required for l10nID labels
		if (this.useMenuManager()) return;
		// Zotero 7.0 fallback: inject the menu item ourselves
		let doc = window.document;
		if (doc.getElementById(this.MENUITEM_ID)) return;
		let menuitem = doc.createXULElement('menuitem');
		menuitem.id = this.MENUITEM_ID;
		menuitem.setAttribute('data-l10n-id', this.MENU_L10N_ID);
		menuitem.addEventListener('command', () => this.run(window.ZoteroPane.getSelectedItems()));
		doc.getElementById('zotero-itemmenu').appendChild(menuitem);
	},
	addToAllWindows() { for (let win of Zotero.getMainWindows()) if (win.ZoteroPane) this.addToWindow(win); },
	removeFromWindow(window) {
		let doc = window.document;
		doc.getElementById(this.MENUITEM_ID)?.remove();
		doc.querySelector(`link[rel="localization"][href="${this.FTL_FILE}"]`)?.remove();
	},
	removeFromAllWindows() { for (let win of Zotero.getMainWindows()) if (win.ZoteroPane) this.removeFromWindow(win); },

	async run(items) { /* the actual work; report with Zotero.ProgressWindow */ },
};
```

FTL file (`src/locale/en-US/my-plugin.ftl`), attribute syntax because a `menuitem` label is an attribute:

```
my-plugin-menuitem =
    .label = Do The Thing
```

Zotero registers every `locale/<lang>/*.ftl` in the plugin automatically (falling back to en-US for other locales); the window still needs `insertFTLIfNeeded` to use it.

## Progress and results

```js
let progress = new Zotero.ProgressWindow();        // closeOnClick: true by default
progress.changeHeadline('Doing the thing');
progress.show();
let line = new progress.ItemProgress('attachmentSnapshot', item.getDisplayTitle());   // icon key, text
line.setProgress(50);  /* ... */  line.setProgress(100);  // or line.setError()
progress.addDescription('Plain text, <a> markup allowed');
progress.changeHeadline(`Added ${n} snapshots`);
progress.startCloseTimer(5000);
```

## Packaging

`build.sh` zips the contents of `src/` so that `manifest.json` sits at the zip root (a nested top-level folder breaks installation) and prints the SHA-256 for `updates.json`:

```json
{
	"addons": {
		"<id>": {
			"updates": [{
				"version": "1.0.0",
				"update_link": "https://github.com/<user>/<repo>/releases/download/v1.0.0/<slug>-1.0.0.xpi",
				"update_hash": "sha256:<hash of that exact file>",
				"applications": { "zotero": { "strict_min_version": "7.0", "strict_max_version": "10.*" } }
			}]
		}
	}
}
```

Version bump checklist: `src/manifest.json` version, `./build.sh`, new hash and link in `updates.json`, commit, push, `gh release create v<version> build/<slug>-<version>.xpi`. Zotero compares versions with Mozilla's version rules (`1.0.1` > `1.0.0`; `-beta` suffixes sort lower).
