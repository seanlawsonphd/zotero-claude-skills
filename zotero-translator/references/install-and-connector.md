# Installing a translator, refreshing the Connector, and the snapshot caveat

## Where translators live

The Zotero client loads translators from `<data directory>/translators/` at startup and serves them to the browser Connector. Find the data directory in the profile's `prefs.js`:

```bash
grep -h "extensions.zotero.dataDir\|useDataDir" ~/Library/Application\ Support/Zotero/Profiles/*/prefs.js
```

If `useDataDir` is true, use that path; otherwise the default is `~/Zotero`.

`scripts/install-translator.sh Label.js --keep-copy-in <folder>` does the lookup, refuses to overwrite an existing file, and keeps the user's own copy. The folder also holds the roughly 750 official translators that Zotero updates automatically; custom files with their own UUIDs survive those updates, but **Reset Translators** (Settings > Advanced > Files and Folders) deletes everything in the folder and re-downloads only the official set. That is why the copy outside the data directory matters.

## Making it active

1. Restart Zotero. Translators are read once at startup (cached in the `translatorCache` table by filename and modification time).
2. In the browser, open the Connector's preferences > Advanced > **Update Translators**. The Connector keeps its own copy of the translator list from the client and refreshes it only periodically.
3. Reload the site. The Connector icon should change from the generic page icon to the item type's icon (newspaper, video).

Verify from the terminal, read-only (needs Zotero running):

```bash
# Which translators match a URL (should list your label first, priority 100)
curl -s -X POST http://127.0.0.1:23119/connector/getTranslators \
  -H 'Content-Type: application/json' -d '{"url":"https://www.rt.com/russia/646973-example/"}'
```

There is also `POST /connector/detect` (`{"uri": ..., "html": ...}`) which runs detection on supplied HTML in the client's hidden browser; useful when a user reports "no icon" and you want to test the client's own copy of the translator.

## The multi-item snapshot limitation

When a user saves several items at once from the Connector's pick-list, the items are created but **no snapshots are saved**. This is deliberate in the Connector's item saver (`itemSaver.js`: "Don't save snapshots from search results", tracked as zotero-connectors issue 481, open since June 2024). The Connector can only SingleFile the tab it is on, and the Zotero team disabled client-side downloads of the other pages because they produced bad snapshots and got users flagged as bots. No translator code changes this; `attachment.document` becomes `{url, mimeType: 'text/html'}` in the Connector and is then filtered out for `"multiple"` saves.

Tell users before they notice. Two remedies:

- **Add Missing Snapshots plugin** (https://github.com/seanlawsonphd/zotero-add-missing-snapshots): select items, right-click, "Add Missing Snapshots". Backfills via Zotero's hidden browser in the Connector's SingleFile format.
- **Run JavaScript backfill** (Tools > Developer > Run JavaScript, "Run as async function"):

```js
var items = Zotero.getActiveZoteroPane().getSelectedItems().filter(i => i.isRegularItem());
var added = 0;
for (let item of items) {
	let url = item.getField('url');
	if (!/^https?:\/\//.test(url)) continue;
	let has = item.getAttachments().some(id => {
		let a = Zotero.Items.get(id);
		return a.attachmentLinkMode == Zotero.Attachments.LINK_MODE_IMPORTED_URL && a.attachmentContentType == 'text/html';
	});
	if (has) continue;
	await Zotero.Attachments.importFromURL({ libraryID: item.libraryID, url, parentItemID: item.id, title: 'Snapshot', contentType: 'text/html' });
	added++;
}
return 'Snapshots added: ' + added;
```

## Submitting upstream (optional)

If the translator is general-purpose, it can go to https://github.com/zotero/translators as a pull request: branch, keep `inRepository: true`, run the repo's `verify-translator` skill steps (update-metadata, lint, run-tests), and describe the site and page types covered. Until merged, the local install is what makes it work.
