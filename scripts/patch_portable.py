#!/usr/bin/env python3
"""Fail-closed portability adjustments for baig/pandoc-gui version 2.0.0.
No user documents or upstream conversion logic are modified.
"""
from pathlib import Path
import argparse, json, re

parser=argparse.ArgumentParser()
parser.add_argument('--source', required=True)
args=parser.parse_args()
root=Path(args.source)
config_file=root/'src-tauri/tauri.conf.json'
cargo_file=root/'src-tauri/Cargo.toml'
package_file=root/'package.json'
main_file=root/'src-tauri/src/main.rs'
frontend_file=root/'src/app.js'
icon_file=root/'src-tauri/icons/icon.ico'
for path in (config_file,cargo_file,package_file,main_file,frontend_file,icon_file):
    if not path.is_file(): raise SystemExit(f'PATCH FAILED: Expected upstream file missing: {path}')

config=json.loads(config_file.read_text(encoding='utf-8'))
package=json.loads(package_file.read_text(encoding='utf-8'))
cargo=cargo_file.read_text(encoding='utf-8')
main=main_file.read_text(encoding='utf-8')
frontend=frontend_file.read_text(encoding='utf-8')
if config.get('version') != '2.0.0' or package.get('version') != '2.0.0':
    raise SystemExit('PATCH FAILED: Unexpected upstream version; inspect source before building.')
if config.get('identifier') != 'com.pandocgui.app':
    raise SystemExit('PATCH FAILED: Upstream app identifier changed.')
if 'Command::new("pandoc")' not in main or 'window.__TAURI__.dialog' not in frontend or "pandocHistory" not in frontend:
    raise SystemExit('PATCH FAILED: Upstream Pandoc invocation, dialogs or history structure changed.')
if config.get('app',{}).get('security',{}).get('capabilities',None) != []:
    raise SystemExit('PATCH FAILED: Capabilities changed upstream; review security policy first.')
if 'appDirectoriesOverride' in config['app'] or 'withGlobalTauri' in config['app']:
    raise SystemExit('PATCH FAILED: Tauri app portability/global API settings already exist; review.')

# Upstream currently uses a broad Tauri 2 semver range. Pin versions known to
# support appDirectoriesOverride, to avoid the Tauri 2.9 incompatibility seen
# in another Pandoc GUI project. Pin the JS CLI and Rust runtime/build crates.
cli=package.get('devDependencies',{}).get('@tauri-apps/cli')
if cli != '^2.0.0':
    raise SystemExit(f'PATCH FAILED: unexpected original Tauri CLI dependency {cli!r}')
package['devDependencies']['@tauri-apps/cli']='2.12.4'
for crate, required, replacement in [('tauri-build','2','=2.7.4'),('tauri','2','=2.12.5')]:
    pat=re.compile(r'(?m)^('+re.escape(crate)+r'\s*=\s*\{\s*version\s*=\s*)"'+re.escape(required)+r'"')
    cargo,num=pat.subn(lambda m:m.group(1)+'"'+replacement+'"',cargo)
    if num != 1:
        raise SystemExit(f'PATCH FAILED: Cannot locate {crate} version {required}; found {num}.')

# relative to executable in BaigPandocGUIPortable/App
config['app']['appDirectoriesOverride']='../Data/Tauri'
# Source calls window.__TAURI__.core and window.__TAURI__.dialog.
config['app']['withGlobalTauri']=True
config['app']['security']['capabilities']=['portable']
# We do not generate installers; there is no need for bundle bootstrapper.
config['bundle']['active']=False

capdir=root/'src-tauri/capabilities'
capdir.mkdir(parents=True,exist_ok=True)
capfile=capdir/'portable.json'
if capfile.exists(): raise SystemExit('PATCH FAILED: Portable capability file already exists; inspect.')
cap={
 'identifier':'portable',
 'description':'Only core UI and document selection dialog permissions for the portable frontend.',
 'windows':['main'],
 'permissions':['core:default','dialog:allow-open','dialog:allow-save']
}
capfile.write_text(json.dumps(cap,indent=2)+'\n',encoding='utf-8')
config_file.write_text(json.dumps(config,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
package_file.write_text(json.dumps(package,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
cargo_file.write_text(cargo,encoding='utf-8')
(root/'PORTABLE_PATCH_SUMMARY.txt').write_text(
 'Upstream: baig/pandoc-gui, main branch, package version 2.0.0.\n'
 'App identifier preserved: com.pandocgui.app.\n'
 'Tauri CLI 2.12.4 / Rust runtime 2.12.5 / build 2.7.4.\n'
 'Tauri appDirectoriesOverride: ../Data/Tauri (relative to App executable).\n'
 'Global Tauri JS enabled (upstream uses window.__TAURI__).\n'
 'Capability for main window: core default and open/save dialogs only.\n'
 'Runtime environment isolation: APPDATA, LOCALAPPDATA, HOME, TEMP, TMP, PATH, WEBVIEW2_USER_DATA_FOLDER.\n'
 'Bundled official Pandoc 3.12.1 verified by SHA256.\n'
 'Upstream does not implement drag/drop file path handling; Browse remains the intended option.\n',encoding='utf-8')
print('PATCH OK: Tauri directory, global API, dialog capability, dependency versions, binary packaging.')
