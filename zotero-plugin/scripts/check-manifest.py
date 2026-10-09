#!/usr/bin/env python3
"""Validate a Zotero plugin manifest the way Zotero's add-on manager does.

    python3 scripts/check-manifest.py <plugin.xpi | src-dir | manifest.json>

Checks the fields Zotero's loader hard-requires (applications.zotero.id, update_url,
strict_max_version), the forbidden '*' in strict_min_version, id shape, version shape,
https update_url, bootstrap.js presence, and (for an .xpi) that manifest.json sits at the
zip root. Any of these failing produces Zotero's generic "may be incompatible" dialog.
Optionally compares strict_max_version against the installed Zotero version.
"""
import json
import os
import re
import subprocess
import sys
import zipfile

ID_RE = re.compile(r'^([a-z0-9._-]+@[a-z0-9._-]+|\{[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\})$', re.I)


def load(target):
    if os.path.isdir(target):
        base = target
        with open(os.path.join(base, 'manifest.json'), encoding='utf-8') as f:
            return json.load(f), os.path.exists(os.path.join(base, 'bootstrap.js')), None
    if target.endswith('.xpi') or target.endswith('.zip'):
        with zipfile.ZipFile(target) as z:
            names = z.namelist()
            root_manifest = 'manifest.json' in names
            nested = [n for n in names if n.endswith('/manifest.json')]
            if not root_manifest:
                return None, False, f"manifest.json is not at the zip root (found {nested or 'none'}); zip the contents of src/, not the folder"
            return json.loads(z.read('manifest.json').decode('utf-8')), 'bootstrap.js' in names, None
    with open(target, encoding='utf-8') as f:
        return json.load(f), os.path.exists(os.path.join(os.path.dirname(target) or '.', 'bootstrap.js')), None


def installed_zotero_version():
    try:
        out = subprocess.run(['/usr/libexec/PlistBuddy', '-c', 'Print :CFBundleShortVersionString',
                              '/Applications/Zotero.app/Contents/Info.plist'], capture_output=True, text=True, timeout=5)
        return out.stdout.strip() or None
    except Exception:
        return None


def version_tuple(v):
    parts = []
    for p in v.split('.'):
        parts.append(10 ** 9 if p == '*' else int(re.match(r'\d*', p).group(0) or 0))
    return parts


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    manifest, has_bootstrap, fatal = load(argv[1])
    errors, warnings = [], []
    if fatal:
        errors.append(fatal)
    else:
        z = (manifest.get('applications') or {}).get('zotero') or {}
        if manifest.get('manifest_version') != 2:
            errors.append('manifest_version must be 2')
        if not manifest.get('name'):
            errors.append('name missing')
        if not re.match(r'^\d+(\.\d+)*([.-][0-9A-Za-z]+)*$', str(manifest.get('version', ''))):
            errors.append(f"version {manifest.get('version')!r} is not a valid version string")
        if not z:
            errors.append('applications.zotero block missing (Zotero ignores browser_specific_settings.gecko)')
        if not z.get('id'):
            errors.append('applications.zotero.id not provided')
        elif not ID_RE.match(z['id']):
            errors.append(f"applications.zotero.id {z['id']!r} must look like name@domain or be a GUID")
        if not z.get('update_url'):
            errors.append('applications.zotero.update_url not provided')
        elif not z['update_url'].startswith('https://'):
            errors.append('update_url must use https (Zotero refuses insecure update URLs)')
        if not z.get('strict_max_version'):
            errors.append('applications.zotero.strict_max_version not provided (Zotero requires it)')
        if '*' in str(z.get('strict_min_version', '')).split('.'):
            errors.append("'*' is not allowed in strict_min_version")
        if not has_bootstrap:
            errors.append('bootstrap.js missing next to manifest.json')
        installed = installed_zotero_version()
        if installed and z.get('strict_max_version'):
            if version_tuple(installed) > version_tuple(z['strict_max_version']):
                errors.append(f"strict_max_version {z['strict_max_version']} is below the installed Zotero {installed}")
            if z.get('strict_min_version') and version_tuple(installed) < version_tuple(z['strict_min_version']):
                errors.append(f"strict_min_version {z['strict_min_version']} is above the installed Zotero {installed}")
        if z.get('update_url', '').startswith('https://') and 'github.com/' in z['update_url'] and 'raw.githubusercontent.com' not in z['update_url'] and '/releases/download/' not in z['update_url']:
            warnings.append('update_url points at a github.com page, not a raw file; use raw.githubusercontent.com/<user>/<repo>/main/updates.json or a release asset')
    for w in warnings:
        print('WARN:', w)
    if errors:
        for e in errors:
            print('FAIL:', e)
        return 1
    print('OK: manifest passes Zotero\'s install checks', f"(id {manifest['applications']['zotero']['id']}, version {manifest['version']}, max {manifest['applications']['zotero']['strict_max_version']})")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
