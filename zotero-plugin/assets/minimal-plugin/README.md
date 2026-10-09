# {{PLUGIN_NAME}} (Zotero plugin)

{{DESCRIPTION}}

## Install

1. Download the latest `.xpi` from the [Releases](../../releases) page.
2. In Zotero, open **Tools → Plugins**, click the gear icon, choose
   **Install Plugin From File…**, and pick the `.xpi`.

Requires Zotero 7 or later (declared compatible through {{MAX_VERSION}}; compatibility is
extended via the update manifest). Updates arrive through Zotero's plugin updater.

## Use

Select one or more items, right-click, and choose **{{MENU_LABEL}}**.

## Build from source

```bash
./build.sh
```

This writes `build/{{PLUGIN_SLUG}}-<version>.xpi` and prints its SHA-256, which belongs in
`updates.json`. Reinstall the new `.xpi` through Tools → Plugins → Install Plugin From File
after each change; Zotero reloads the plugin without a restart.

## License

MIT. See [LICENSE](LICENSE).
