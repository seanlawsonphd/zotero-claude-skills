/* global Zotero, Services */

var {{PLUGIN_OBJECT}};

function log(msg) {
	Zotero.debug(`{{PLUGIN_NAME}}: ${msg}`);
}

function install() {
	log('Installed');
}

async function startup({ id, version, rootURI }) {
	log(`Starting ${version}`);
	Services.scriptloader.loadSubScript(rootURI + '{{PLUGIN_SLUG}}.js');
	{{PLUGIN_OBJECT}}.init({ id, version, rootURI });
	{{PLUGIN_OBJECT}}.addToAllWindows();
}

function onMainWindowLoad({ window }) {
	{{PLUGIN_OBJECT}}.addToWindow(window);
}

function onMainWindowUnload({ window }) {
	{{PLUGIN_OBJECT}}.removeFromWindow(window);
}

function shutdown() {
	log('Shutting down');
	{{PLUGIN_OBJECT}}.removeFromAllWindows();
	{{PLUGIN_OBJECT}}.unregisterMenu();
	{{PLUGIN_OBJECT}} = undefined;
}

function uninstall() {
	log('Uninstalled');
}
