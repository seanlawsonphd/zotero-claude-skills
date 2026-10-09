/* global Zotero */

{{PLUGIN_OBJECT}} = {
	id: null,
	version: null,
	rootURI: null,
	initialized: false,
	running: false,
	menuID: null,
	FTL_FILE: '{{PLUGIN_SLUG}}.ftl',
	MENUITEM_ID: '{{PLUGIN_SLUG}}-menuitem',
	MENU_L10N_ID: '{{PLUGIN_SLUG}}-menuitem',

	init({ id, version, rootURI }) {
		if (this.initialized) return;
		this.id = id;
		this.version = version;
		this.rootURI = rootURI;
		this.initialized = true;
		this.registerMenu();
	},

	log(msg) {
		Zotero.debug(`{{PLUGIN_NAME}}: ${msg}`);
	},

	// Zotero 7.1 and later provide a menu API that covers every main window.
	// Zotero 7.0 gets a menu item inserted into each window instead.
	useMenuManager() {
		return !!(Zotero.MenuManager && Zotero.MenuManager.registerMenu);
	},

	registerMenu() {
		if (!this.useMenuManager()) return;
		this.menuID = Zotero.MenuManager.registerMenu({
			menuID: '{{PLUGIN_SLUG}}-item-menu',
			pluginID: this.id,
			target: 'main/library/item',
			menus: [
				{
					menuType: 'menuitem',
					l10nID: this.MENU_L10N_ID,
					onShowing: (_event, context) => {
						context.setEnabled((context.items || []).some(item => item.isRegularItem()));
					},
					onCommand: (_event, context) => {
						this.run(context.items || []);
					},
				},
			],
		});
	},

	unregisterMenu() {
		if (this.menuID && this.useMenuManager()) {
			Zotero.MenuManager.unregisterMenu(this.menuID);
		}
		this.menuID = null;
	},

	addToWindow(window) {
		// Make the plugin's Fluent strings available in this window
		window.MozXULElement.insertFTLIfNeeded(this.FTL_FILE);
		if (this.useMenuManager()) return;

		let doc = window.document;
		if (doc.getElementById(this.MENUITEM_ID)) return;
		let menuitem = doc.createXULElement('menuitem');
		menuitem.id = this.MENUITEM_ID;
		menuitem.setAttribute('data-l10n-id', this.MENU_L10N_ID);
		menuitem.addEventListener('command', () => {
			this.run(window.ZoteroPane.getSelectedItems());
		});
		doc.getElementById('zotero-itemmenu').appendChild(menuitem);
	},

	addToAllWindows() {
		for (let win of Zotero.getMainWindows()) {
			if (!win.ZoteroPane) continue;
			this.addToWindow(win);
		}
	},

	removeFromWindow(window) {
		let doc = window.document;
		doc.getElementById(this.MENUITEM_ID)?.remove();
		doc.querySelector(`link[rel="localization"][href="${this.FTL_FILE}"]`)?.remove();
	},

	removeFromAllWindows() {
		for (let win of Zotero.getMainWindows()) {
			if (!win.ZoteroPane) continue;
			this.removeFromWindow(win);
		}
	},

	// The command. Replace the body with the real work; keep the progress
	// window so long operations stay visible and errors are reported.
	async run(selectedItems) {
		let items = selectedItems.filter(item => item.isRegularItem());
		let progress = new Zotero.ProgressWindow();
		progress.changeHeadline('{{PLUGIN_NAME}}');
		progress.show();

		if (this.running) {
			progress.addDescription('Already running. Please wait for the current run to finish.');
			progress.startCloseTimer(5000);
			return;
		}
		if (!items.length) {
			progress.addDescription('No regular items selected.');
			progress.startCloseTimer(5000);
			return;
		}

		this.running = true;
		let done = 0;
		let failed = [];
		try {
			for (let item of items) {
				let line = new progress.ItemProgress(item.itemType, item.getDisplayTitle());
				line.setProgress(50);
				try {
					await this.processItem(item);
					line.setProgress(100);
					done++;
				}
				catch (e) {
					this.log(`Failed on "${item.getDisplayTitle()}": ${e}`);
					line.setError();
					failed.push(item.getDisplayTitle());
				}
			}
		}
		finally {
			this.running = false;
		}

		let summary = `Processed ${done} item${done == 1 ? '' : 's'}`;
		if (failed.length) summary += `, ${failed.length} failed`;
		progress.changeHeadline(summary);
		progress.startCloseTimer(failed.length ? 15000 : 5000);
	},

	// Per-item work goes here. This placeholder just logs the title.
	async processItem(item) {
		this.log(`Would process "${item.getDisplayTitle()}" (${item.getField('url') || 'no URL'})`);
	},
};
