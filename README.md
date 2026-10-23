# Baig Pandoc GUI True Portable Builder v1.0

An independent **ZIP-only, manually triggered GitHub Actions** builder for the [baig/pandoc-gui](https://github.com/baig/pandoc-gui) Windows desktop app (upstream app version **2.0.0**). The builder compiles the GUI from its official upstream source, integrates official **Pandoc 3.12.1**, and adds native Data redirection and conservative TraceGuard diagnostics.

**This is different from `ivg-design/pandoc-gui-mk2`.** Use a separate GitHub repository and separate `BaigPandocGUIPortable` folder. It is not an official package from the app author or Pandoc.

## No-command-line build with GitHub Desktop (Windows 11)

1. Download and extract `BaigPandocGUI-True-Portable-Builder-v1.0.zip`.
2. In GitHub Desktop, choose **File > New repository**. Name it `BaigPandocGUI-True-Portable-Builder`. Leave **Initialize with README** unchecked; no template .gitignore or license is needed.
3. Select **Repository > Show in Explorer**, and copy the **contents** of the extracted builder folder into the repository folder. Make sure `.github/workflows/build.yml` is directly under the repository root.
4. Return to GitHub Desktop, enter `Initial Baig Pandoc GUI portable builder v1.0` in the Summary field, and click **Commit to main**.
5. Click **Publish repository** and choose private or public.
6. On GitHub, open your repository's **Actions** tab, choose **Build Baig Pandoc GUI True Portable**, and click **Run workflow**.
7. Once the workflow shows a green check, open the completed run and download the artifact `BaigPandocGUIPortable-v2.0.0-win64` under **Artifacts**.
8. Extract GitHub's downloaded artifact ZIP. Move the resulting `BaigPandocGUIPortable` folder into your PortableApps collection. Always start `BaigPandocGUIPortable.exe`, **not** `App/BaigPandocGUI.exe`.

GitHub deletes the artifact after **1 day**. Download it once the run succeeds.

## Expected portable folder

```
BaigPandocGUIPortable/
├── BaigPandocGUIPortable.exe            ← native launcher, original icon
├── App/
│   ├── BaigPandocGUI.exe                ← Tauri GUI built from baig/pandoc-gui
│   ├── Tools/Pandoc/pandoc.exe           ← SHA-256 verified Pandoc 3.12.1
│   └── AppInfo/
│       ├── appinfo.ini
│       ├── appicon.ico
│       ├── appicon_32.png
│       └── appicon_128.png
├── Data/                                  ← **always preserve on updates**
│   ├── Tauri/                             ← WebView2 profile / conversion history
│   ├── Profile/Roaming/ & Profile/Local/  ← redirected APPDATA profiles
│   ├── Home/                              ← user home for child processes
│   ├── Temp/                              ← temporary conversion files
│   ├── PandocUserData/                    ← Pandoc templates/configs
│   ├── Tools/                             ← optional portable utilities
│   └── TraceGuard/                        ← launch & host trace diagnostics
└── Other/
    ├── README-PORTABLE.txt
    ├── UPSTREAM-COMMIT.txt
    ├── UPSTREAM-README.md
    ├── THIRD-PARTY-NOTICES.txt
    └── Source-Patches/
```

## Portability design and source fixes

- The upstream app uses `window.__TAURI__.core` and `window.__TAURI__.dialog` from a vanilla-JavaScript frontend. This builder enables the **global Tauri interface** and adds a **narrow capability** for file open/save dialogs. Without these changes, browse/save dialogs may fail.
- The upstream app keeps conversion history in browser `localStorage`. The Tauri `appDirectoriesOverride` moves its app-managed profile into `Data/Tauri`. The associated WebView2 profile override is also set for the child process.
- The builder pins Tauri CLI **2.12.4**, Tauri runtime **2.12.5**, and tauri-build **2.7.4**, because previous Tauri releases cannot parse the app-directory-override option. Configuration validation runs before the build.
- The source backend runs `pandoc` via `Command::new("pandoc")`. The launcher places bundled `App/Tools/Pandoc` first in its inherited PATH, so no machine-wide Pandoc install is required.
- `APPDATA`, `LOCALAPPDATA`, `HOME`, `TEMP`, and `TMP` are overridden **only for the app and its child processes**. No global environment variables are changed.
- Original icon copied unmodified from `src-tauri/icons/icon.ico` into both the launcher and PortableApps Menu.
- No MSI, EXE setup installer, `.paf.exe`, Start Menu integration, or automatic update manager is created.
- TraceGuard snapshots exact app-specific top-level user-profile directories and HKCU keys. It removes only newly created **empty** app-specific directories. It never deletes or overwrites pre-existing paths, registry keys, or non-empty directories. Windows may still create generic system traces.

## What to test after the build

1. Run the root `BaigPandocGUIPortable.exe` and confirm the status recognizes bundled Pandoc.
2. Use **Browse** to convert a sample `.md` into `.docx`; open it to verify contents.
3. Save and test `.html`, then try converting `.docx` back into `.md`.
4. Close and reopen, confirm conversion history is retained.
5. Confirm files are being written inside `Data/Tauri` and `Data/TraceGuard`.
6. Move the whole folder to a different drive location and repeat the test.
7. Inspect `Data/TraceGuard/TraceGuard.log`. Any **NEW HOST APP-SPECIFIC TRACE** entry needs further investigation.

**Important upstream limitations:** the README advertises drag-and-drop, but the source currently asks users to use Browse when a file is dropped. Generating PDFs usually requires a separate TeX/PDF engine; this builder does not bundle one. The app may store absolute paths for documents selected by the user; saved paths may break after moving computers.

## Updating

Re-run GitHub Actions for a new build. **Preserve your existing `Data/` folder** and replace `App/`, `Other/`, and the root launcher as desired. This builder currently follows the original repository's **main branch** and checks its app version and expected code structure. If upstream changes its source layout, the patch deliberately stops instead of silently shipping a non-portable build.

## Licensing & provenance

- App: https://github.com/baig/pandoc-gui — `README.md` describes the project as MIT; repository appears not to include a dedicated LICENSE file. Verify authoritative redistribution terms before sharing publicly.
- Pandoc: https://github.com/jgm/pandoc/releases/tag/3.12.1 — GPL-2.0-or-later; Windows ZIP SHA256 `6ef431cb20b2c24a0371fc19200dc49d452be54b1b5c9239f3462841ef53e587`.
- Tauri: https://v2.tauri.app/reference/config/
- Original upstream Git commit SHA is included in `Other/UPSTREAM-COMMIT.txt`.

**Validation:** Builder files can be syntax/structure checked locally. Full Windows compilation and first-run TraceGuard behavior require running the GitHub Actions workflow and testing the resulting Windows executable. Never assume a green Actions build proves zero traces.
