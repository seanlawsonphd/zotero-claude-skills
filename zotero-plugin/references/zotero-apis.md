# Zotero plugin API cheat sheet (Zotero 7 to 10)

All verified against the Zotero 10.0.6 source (`omni.ja`). When something here does not match the installed version, read the source: `unzip -o /Applications/Zotero.app/Contents/Resources/app/omni.ja 'chrome/content/zotero/xpcom/pluginAPI/*' 'chrome/content/zotero/xpcom/plugins.js' 'chrome/content/zotero/xpcom/attachments.js' 'chrome/content/zotero/xpcom/progressWindow.js' 'chrome/content/zotero/zoteroPane.js' -d /tmp/zotero-src`. Official docs: https://www.zotero.org/support/dev/zotero_7_for_developers and the sample plugin https://github.com/zotero/make-it-red.

## Bootstrap lifecycle (plugins.js)

Hooks: `install`, `startup`, `shutdown`, `uninstall`, `onMainWindowLoad`, `onMainWindowUnload`. Each receives `({ id, version, rootURI, [window] }, reason)`; reasons: APP_STARTUP 1, APP_SHUTDOWN 2, ADDON_ENABLE 3, ADDON_DISABLE 4, ADDON_INSTALL 5, ADDON_UNINSTALL 6, ADDON_UPGRADE 7, ADDON_DOWNGRADE 8. Reinstalling a running plugin calls `shutdown` + `uninstall` on the old version, then `install` + `startup` on the new one, no restart. Globals in the sandbox: `Zotero`, `Services`, `Components`/`Cc`/`Ci`/`Cu`, `ChromeUtils`. Load more files with `Services.scriptloader.loadSubScript(rootURI + 'file.js')` (or with a scope object as second argument). Locale files under `locale/<lang>/*.ftl` are registered automatically.

## Menus: Zotero.MenuManager (7.1+)

```js
let menuID = Zotero.MenuManager.registerMenu({
	menuID: 'unique-id', pluginID: id, target: 'main/library/item',
	menus: [{ menuType: 'menuitem' | 'submenu' | 'separator', l10nID: 'ftl-message-id', l10nArgs?: '{"n":3}',
	          icon?: 'chrome://... or rootURI + icon.svg (16x16, fill="context-fill")', darkIcon?,
	          enableForTabTypes?: ['library', 'reader/pdf'],
	          onShowing?(event, context), onShown?, onHiding?, onHidden?, onCommand?(event, context), menus?: [...] }]
});
Zotero.MenuManager.unregisterMenu(menuID);
```

Targets: `main/menubar/{file,edit,view,go,tools,help}`, `main/library/item`, `main/library/collection`, `main/library/addAttachment`, `main/library/addNote`, `main/tab`, `reader/menubar/{file,edit,view,go,window}`, `itemPane/info/row`, `notesPane/addItemNote`, `notesPane/addStandaloneNote`, `sidenav/locate`. Item-menu context: `{ items, collectionTreeRows, tabType: 'library', tabID, menuElem, setEnabled(bool), setVisible(bool), setL10nArgs(str), setIcon(light, dark) }`. Labels only via Fluent (`l10nID`); the window must have the plugin's FTL inserted (`window.MozXULElement.insertFTLIfNeeded('file.ftl')`).

Zotero 7.0 fallback: `doc.createXULElement('menuitem')` with `data-l10n-id`, appended to `doc.getElementById('zotero-itemmenu')` (item context menu) or `menu_viewPopup` etc.; remove on shutdown.

## Item pane and item tree

- `Zotero.ItemPaneManager.registerSection({ paneID, pluginID, header: { l10nID, icon }, sidenav: { l10nID, icon }, onInit, onRender({ body, item, editable, setL10nArgs }), onItemChange, onDestroy })`, `unregisterSection(paneID)`.
- `Zotero.ItemPaneManager.registerInfoRow({ rowID, pluginID, label: { l10nID }, position: 'afterCreators' | 'end', editable, onGetData({ item }), onSetData({ item, value }) })`.
- `await Zotero.ItemTreeManager.registerColumns({ pluginID, dataKey, label, dataProvider(item, dataKey), renderCell?, zoteroPersist? })`.
- `Zotero.PreferencePanes.register({ pluginID, src: rootURI + 'preferences.xhtml', scripts: [rootURI + 'preferences.js'], label, image })`.

## Items, attachments, library

- Selection: `Zotero.getActiveZoteroPane().getSelectedItems()` or `window.ZoteroPane.getSelectedItems()`; windows: `Zotero.getMainWindows()`, `Zotero.getMainWindow()`.
- `item.isRegularItem()`, `item.isAttachment()`, `item.isNote()`, `item.getField('url' | 'title' | 'DOI' | 'extra' | ...)`, `item.setField()`, `await item.saveTx()`, `item.getDisplayTitle()`, `item.libraryID`, `item.library.editable` / `.filesEditable`, `item.getAttachments()` (ids; `Zotero.Items.get(id)`), `attachment.attachmentLinkMode` (`Zotero.Attachments.LINK_MODE_IMPORTED_URL` = 1, `LINKED_URL` = 3), `attachment.attachmentContentType`, `item.getTags()`, `item.addTag()`, `item.getNotes()`.
- Snapshots: `await Zotero.Attachments.importFromURL({ libraryID, url, parentItemID, title, contentType: 'text/html' })` loads the page in Zotero's hidden browser and saves a SingleFile snapshot (HTML content types take this path; other types download the file). Also `importFromDocument`, `importFromSnapshotContent`, `linkFromURL`, `addFileFromURLs`.
- `Zotero.Items.get(ids)`, `Zotero.Items.getAsync`, `Zotero.Libraries.get`, `Zotero.Collections`, `Zotero.Notifier.registerObserver(observer, ['item', 'collection', 'tab'])` / `unregisterObserver(id)`.
- Prefs: `Zotero.Prefs.get('extensions.myplugin.key', true)` and `.set(key, value, true)` (the `true` means the key is not under `extensions.zotero.`); defaults from a bundled `prefs.js` are applied by Zotero on load.
- UI feedback: `Zotero.ProgressWindow` (see minimal-bootstrap.md), `Zotero.alert(window, title, text)`, `Zotero.getMainWindow().alert()`, `Services.prompt.confirm`.
- Logging: `Zotero.debug(msg)` (Help > Debug Output Logging), `Zotero.logError(e)`, `Zotero.warn`.
- Clipboard: `Components.classes["@mozilla.org/widget/clipboardhelper;1"].getService(Components.interfaces.nsIClipboardHelper).copyString(text)`.
- Async: `Zotero.Promise.delay(ms)`, `Zotero.initializationPromise`, `Zotero.uiReadyPromise`.

## Connector HTTP server (useful for tests, port 23119 by default)

- `GET /connector/ping`; `POST /connector/getTranslators {url}`; `POST /connector/import?session=<id>` with RIS/BibTeX text creates items; `POST /connector/saveItems`. Change the port per profile with `extensions.zotero.httpServer.port`.

## Reading the add-on manager's verdicts

- Manifest loader (Zotero patch in `Extension.sys.mjs`): requires `applications.zotero.id`, `.update_url`, `.strict_max_version`; `*` not allowed in `strict_min_version`.
- Compatibility (`XPIDatabase.isCompatibleWith`): Zotero release builds enforce `min <= appVersion <= max`; `10.*` covers all 10.x.
- Every install failure (`addon-install-failed`, `-blocked`, `-disabled`) shows one dialog: "could not be installed. It may be incompatible with this version of Zotero." The actual cause is in the debug output or the Error Console (Tools > Developer).
