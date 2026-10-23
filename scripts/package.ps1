param(
 [Parameter(Mandatory=$true)][string]$Upstream,
 [Parameter(Mandatory=$true)][string]$BuilderRoot,
 [Parameter(Mandatory=$true)][string]$Launcher
)
$ErrorActionPreference = 'Stop'
$target = Join-Path $BuilderRoot 'dist/BaigPandocGUIPortable'
if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
foreach ($rel in @('App','App/AppInfo','App/Tools/Pandoc','Data','Data/Tauri','Data/Profile/Roaming','Data/Profile/Local','Data/Home','Data/Temp','Data/Tools','Data/PandocUserData','Data/TraceGuard','Other','Other/Source-Patches')) {
 New-Item -ItemType Directory -Path (Join-Path $target $rel) -Force | Out-Null
}
$exe = Join-Path $Upstream 'src-tauri/target/release/pandoc-gui.exe'
if (!(Test-Path -LiteralPath $exe -PathType Leaf)) { throw "GUI executable missing: $exe" }
Copy-Item -LiteralPath $exe -Destination (Join-Path $target 'App/BaigPandocGUI.exe')
Get-ChildItem -LiteralPath (Join-Path $Upstream 'src-tauri/target/release') -Filter '*.dll' -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target 'App') }
Copy-Item -LiteralPath $Launcher -Destination (Join-Path $target 'BaigPandocGUIPortable.exe')
$icon = Join-Path $Upstream 'src-tauri/icons/icon.ico'
if (!(Test-Path -LiteralPath $icon)) { throw "Official source icon missing: $icon" }
Copy-Item -LiteralPath $icon -Destination (Join-Path $target 'App/AppInfo/appicon.ico')
foreach ($pair in @(@('32x32.png','appicon_32.png'),@('128x128.png','appicon_128.png'))) {
 $from = Join-Path $Upstream "src-tauri/icons/$($pair[0])"
 if (Test-Path -LiteralPath $from) { Copy-Item -LiteralPath $from -Destination (Join-Path $target "App/AppInfo/$($pair[1])") }
}

# Download the official Pandoc Windows ZIP (not the installer).
$pandocVersion='3.12.1'
$pandocHash='6ef431cb20b2c24a0371fc19200dc49d452be54b1b5c9239f3462841ef53e587'
$url="https://github.com/jgm/pandoc/releases/download/$pandocVersion/pandoc-$pandocVersion-windows-x86_64.zip"
$zip=Join-Path $BuilderRoot 'pandoc-official.zip'
$extract=Join-Path $BuilderRoot 'pandoc-official-extract'
Write-Host "Fetching $url"
Invoke-WebRequest -Uri $url -OutFile $zip -MaximumRedirection 10
$got=(Get-FileHash -LiteralPath $zip -Algorithm SHA256).Hash.ToLowerInvariant()
if ($got -ne $pandocHash) { throw "Pandoc official SHA256 mismatch! Expected $pandocHash / found $got" }
Expand-Archive -LiteralPath $zip -DestinationPath $extract -Force
$pandocExe = Get-ChildItem -LiteralPath $extract -Recurse -Filter pandoc.exe -File | Select-Object -First 1
if (!$pandocExe) { throw 'Pandoc executable not found in official archive' }
Copy-Item -LiteralPath $pandocExe.FullName -Destination (Join-Path $target 'App/Tools/Pandoc/pandoc.exe')
Get-ChildItem -LiteralPath $pandocExe.Directory.FullName -File | Where-Object {$_.Name -ne 'pandoc.exe'} | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $target 'App/Tools/Pandoc') }

$ini=@"
[Format]
Type=PortableApps.comFormat
Version=3.8

[Details]
Name=Baig Pandoc GUI Portable
AppID=BaigPandocGUIPortable
Publisher=baig (app) and community portable builder
Homepage=https://github.com/baig/pandoc-gui
Category=Office
Description=Baig Pandoc GUI with bundled Pandoc conversion engine
Language=English

[License]
Shareable=true
OpenSource=true
Freeware=true
CommercialUse=true

[Version]
PackageVersion=2.0.0.0
DisplayVersion=2.0.0 Portable 1.0

[Control]
Icons=1
Start=BaigPandocGUIPortable.exe
"@
[System.IO.File]::WriteAllText((Join-Path $target 'App/AppInfo/appinfo.ini'), $ini, [Text.UTF8Encoding]::new($false))
foreach ($rel in @('Data/Tauri','Data/Profile/Roaming','Data/Profile/Local','Data/Home','Data/Temp','Data/Tools','Data/PandocUserData','Data/TraceGuard')) {
 [System.IO.File]::WriteAllText((Join-Path $target "$rel/KEEP.txt"),'Preserve Data when upgrading.',[Text.UTF8Encoding]::new($false))
}
$license=Join-Path $Upstream 'LICENSE'
if (Test-Path -LiteralPath $license) { Copy-Item -LiteralPath $license -Destination (Join-Path $target 'Other/LICENSE-Baig-Pandoc-GUI.txt') }
# The README describes the upstream project as MIT, but the repository may omit a standalone LICENSE file.
Copy-Item -LiteralPath (Join-Path $Upstream 'README.md') -Destination (Join-Path $target 'Other/UPSTREAM-README.md')
# Include upstream Pandoc's actual GPL license and copyright rather than links alone.
foreach ($entry in @(@('COPYING.md','COPYING-Pandoc.md'),@('COPYRIGHT','COPYRIGHT-Pandoc.txt'))) {
  $licenseUrl = "https://raw.githubusercontent.com/jgm/pandoc/$pandocVersion/$($entry[0])"
  $licenseDest = Join-Path $target "Other/$($entry[1])"
  Invoke-WebRequest -Uri $licenseUrl -OutFile $licenseDest
  if (!(Test-Path -LiteralPath $licenseDest -PathType Leaf) -or (Get-Item $licenseDest).Length -lt 100) { throw "Pandoc license/copyright missing: $licenseUrl" }
}
Copy-Item -LiteralPath (Join-Path $Upstream 'PORTABLE_CAPABILITY.json') -Destination (Join-Path $target 'Other/Source-Patches/portable-capability.json')
$revision = (git -C $Upstream rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $revision.Length -lt 30) { throw 'Cannot record upstream Git SHA' }
[System.IO.File]::WriteAllText((Join-Path $target 'Other/UPSTREAM-COMMIT.txt'),$revision,[Text.UTF8Encoding]::new($false))
foreach ($file in @('PORTABLE_PATCH_SUMMARY.txt','PORTABLE_PATCH.diff')) {
 Copy-Item -LiteralPath (Join-Path $Upstream $file) -Destination (Join-Path $target 'Other/Source-Patches')
}
Copy-Item -LiteralPath (Join-Path $BuilderRoot 'scripts/patch_portable.py') -Destination (Join-Path $target 'Other/Source-Patches/patch_portable.py')
Copy-Item -LiteralPath (Join-Path $BuilderRoot 'launcher/launcher.cpp') -Destination (Join-Path $target 'Other/Source-Patches/launcher.cpp')
$notes=@"
BAIG PANDOC GUI TRUE PORTABLE BUILDER v1.0
GUI: https://github.com/baig/pandoc-gui (upstream branch main, application version 2.0.0)
Source commit: $revision
Pandoc: https://github.com/jgm/pandoc/releases/tag/3.12.1
Pandoc official Windows ZIP SHA256: $pandocHash

Start BaigPandocGUIPortable.exe. Do NOT run App/BaigPandocGUI.exe directly.
Preserve the entire Data folder on upgrades. Replace App and launcher only.
Conversion history is stored by browser localStorage and intended to remain in Data/Tauri.
Source uses global Tauri interface; builder enables it and file open/save capability.
Windows WebView2 Runtime is needed. Many Win11 systems include it, but it isn't bundled.
The source project does not implement drag-and-drop file selection. Use Browse instead.
Markdown to DOCX/HTML/EPUB conversions work through bundled Pandoc. PDF output
needs a suitable external PDF engine; none is included. Copy optional binary tools
into Data/Tools, where possible, and test.
Input/output paths are chosen by the user and may point outside the portable folder.
TraceGuard snapshots known app-named directories and HKCU keys. It only removes
newly-created EMPTY exact app-named folders and leaves nonempty/pre-existing/shared
system traces intact; no zero-host-remnants guarantee is made.
"@
[System.IO.File]::WriteAllText((Join-Path $target 'Other/README-PORTABLE.txt'),$notes,[Text.UTF8Encoding]::new($false))
$notices=@"
Original Pandoc GUI author/repository: https://github.com/baig/pandoc-gui
The README describes the project license as MIT. Check upstream for complete license terms.
Pandoc is independently distributed and licensed GPL-2.0-or-later:
https://github.com/jgm/pandoc/blob/3.12.1/COPYING.md
https://github.com/jgm/pandoc/blob/3.12.1/COPYRIGHT
Pandoc official source: https://github.com/jgm/pandoc/tree/3.12.1
Portable launcher & modification scripts included in Other/Source-Patches.
"@
[System.IO.File]::WriteAllText((Join-Path $target 'Other/THIRD-PARTY-NOTICES.txt'),$notices,[Text.UTF8Encoding]::new($false))
foreach ($rel in @('BaigPandocGUIPortable.exe','App/BaigPandocGUI.exe','App/Tools/Pandoc/pandoc.exe','App/AppInfo/appinfo.ini','App/AppInfo/appicon.ico','Data/Tauri/KEEP.txt','Other/UPSTREAM-COMMIT.txt','Other/README-PORTABLE.txt')) {
 $f=Join-Path $target $rel
 if (!(Test-Path -LiteralPath $f -PathType Leaf) -or (Get-Item -LiteralPath $f).Length -eq 0) { throw "VALIDATION FAILED missing/empty: $rel" }
}
Write-Host 'PACKAGE VALIDATION OK: unique app, original icon, signed-off Pandoc hash, Data folders.'
