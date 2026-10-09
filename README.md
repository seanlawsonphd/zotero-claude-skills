# Zotero skills for Claude Code

Two [Claude Code skills](https://docs.anthropic.com/en/docs/claude-code/skills) for working on Zotero:

- **zotero-translator**: write, test, install, and maintain custom Zotero web translators (the
  site-specific scrapers the Zotero Connector uses) with the official
  [zotero/translators](https://github.com/zotero/translators) tooling. Includes tested code
  patterns for news sites, site-analysis recipes, and helper scripts for repo setup, installing a
  translator into the Zotero data directory, and refreshing stale test cases.
- **zotero-plugin**: build, test, package, and publish Zotero 7+ plugins, either as a minimal
  bootstrap plugin (a ready-to-fill skeleton with a generator script) or with the
  [windingwind zotero-plugin-template](https://github.com/windingwind/zotero-plugin-template).
  Includes a manifest validator that replicates Zotero's own install checks, a throwaway-profile
  launcher for safe testing, and references for the plugin APIs, testing, and GitHub releases.

Both grew out of building the [RT.com and TASS.com translators](https://github.com/seanlawsonphd/zotero-translators)
and the [Add Missing Snapshots](https://github.com/seanlawsonphd/zotero-add-missing-snapshots) plugin.

## Install

Clone this repo and copy (or symlink) the two folders into your skills directory:

```bash
git clone https://github.com/seanlawsonphd/zotero-claude-skills.git
cp -R zotero-claude-skills/zotero-translator zotero-claude-skills/zotero-plugin ~/.claude/skills/
```

Claude Code picks them up on the next session. Each `SKILL.md` lists what triggers it and which
reference file to read for what.

## Requirements

- Zotero 7 or later (the references were verified against Zotero 10).
- Node.js 18+ (22 recommended) and Google Chrome for the translator test tools, which build the
  Zotero Connector and run it headless against live sites.
- The GitHub CLI (`gh`) for the publishing steps.

## Layout

```
zotero-translator/   SKILL.md, references/, scripts/, evals/
zotero-plugin/       SKILL.md, references/, assets/minimal-plugin/, scripts/, evals/
sync.sh              maintainer helper: copies the live skills from ~/.claude/skills into this repo
```

## License

MIT. See [LICENSE](LICENSE).
