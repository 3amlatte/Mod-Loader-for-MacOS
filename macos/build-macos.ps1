# Builds the experimental macOS package.
#
# Run from Windows or macOS with the .NET 10 SDK:
#   pwsh ./macos/build-macos.ps1 -GameData "/path/to/data_GamesByMalcs.Melvor2_windows_x86_64"
#
# The compile-time references are the game's managed DLLs. They are the same on every
# platform (the native engine is what differs), so the Windows data folder is fine.
#
# Output: dist-macos/ModLoaderForMacOS-<version>-macos.zip
#         dist-macos/ModLoaderForMacOS-<version>-macos.zip.sha256

[CmdletBinding()]
param(
    # Loader version; defaults to <Version> in Loader/MelvorModLoader.csproj.
    [string] $Version,

    # The game's data folder (contains GamesByMalcs.Melvor2.dll and GodotSharp.dll).
    # Defaults to MELVOR_GAMEDATA, then to <game>/data_GamesByMalcs.Melvor2_windows_x86_64
    # when this repository is cloned into the game folder as MelvorModLoader_src.
    [string] $GameData,

    [ValidateSet('arm64', 'x64')]
    [string[]] $Architectures = @('arm64', 'x64'),

    # Built Mod Viewer zip (contains mods/ModViewer/...). Defaults to the newest
    # ModViewer-*.zip in ../melvor-idle-2-mods/dist when that folder exists.
    [string] $ModViewerZip,

    [string] $OutputDir
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

$root = Split-Path -Parent $PSScriptRoot
$loaderProject = Join-Path $root 'Loader\MelvorModLoader.csproj'
$outDir = if ($OutputDir) { $OutputDir } else { Join-Path $root 'dist-macos' }

if (-not (Test-Path $loaderProject)) { throw "Loader project not found: $loaderProject" }

if (-not $Version) {
    [xml] $xml = Get-Content -LiteralPath $loaderProject
    $node = $xml.Project.PropertyGroup | Where-Object { $_.Version } | Select-Object -First 1
    $Version = if ($node) { [string] $node.Version } else { '0.0.0' }
}

if (-not $GameData) { $GameData = $env:MELVOR_GAMEDATA }

if (-not $GameData) {
    $relative = Join-Path $root '..\..\data_GamesByMalcs.Melvor2_windows_x86_64'
    if (Test-Path -LiteralPath (Join-Path $relative 'GamesByMalcs.Melvor2.dll')) {
        $GameData = (Resolve-Path -LiteralPath $relative).ProviderPath
    }
}

if (-not $GameData -or -not (Test-Path -LiteralPath (Join-Path $GameData 'GamesByMalcs.Melvor2.dll'))) {
    throw "Game data folder not found. Pass -GameData '<game data folder>' (it must contain GamesByMalcs.Melvor2.dll)."
}
$GameData = (Resolve-Path -LiteralPath $GameData).ProviderPath

# Bundle the newest Mod Viewer build by default. The installer replaces any older
# Mod Viewer copy in the player's mods and mods-disabled folders.
if (-not $ModViewerZip) {
    $siblingDist = Join-Path (Split-Path -Parent $root) 'melvor-idle-2-mods\dist'
    $candidates = @(Get-ChildItem -LiteralPath $siblingDist -Filter 'ModViewer-*.zip' -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $match = [regex]::Match($_.Name, 'ModViewer-([0-9]+(?:\.[0-9]+)*)\.zip$')
            $version = if ($match.Success) { [version] $match.Groups[1].Value } else { [version] '0.0.0' }
            [pscustomobject]@{ File = $_.FullName; Version = $version }
        } |
        Sort-Object Version -Descending)
    if ($candidates.Count -gt 0) { $ModViewerZip = $candidates[0].File }
}

if ($ModViewerZip -and -not (Test-Path -LiteralPath $ModViewerZip)) {
    throw "Mod Viewer zip not found: $ModViewerZip"
}

$stageRoot = Join-Path $outDir 'stage'
$publishRoot = Join-Path $outDir '_publish'
$packageName = "ModLoaderForMacOS-$Version-macos"
$packageRoot = Join-Path $stageRoot $packageName
$zipPath = Join-Path $outDir "$packageName.zip"

Write-Host "Mod Loader for MacOS $Version for macOS"
Write-Host "  game data:  $GameData"
Write-Host "  Mod Viewer: $(if ($ModViewerZip) { $ModViewerZip } else { '(not found; package will not include it)' })"
Write-Host "  output:     $outDir"

if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

# The loader payload and the real scripts stay at the package root, like the Windows
# zip, so they can also be copied into the .app by hand. The .app bundles are thin
# shell-script wrappers that show native dialogs and call install.sh / uninstall.sh.
$installApp = Join-Path $packageRoot 'Install Mod Loader for MacOS.app'
$installMacOS = Join-Path $installApp 'Contents\MacOS'
$installRes = Join-Path $installApp 'Contents\Resources'
$uninstallApp = Join-Path $packageRoot 'Uninstall Mod Loader for MacOS.app'
$uninstallMacOS = Join-Path $uninstallApp 'Contents\MacOS'
$uninstallRes = Join-Path $uninstallApp 'Contents\Resources'
New-Item -ItemType Directory -Force -Path $installMacOS, $installRes, $uninstallMacOS, $uninstallRes | Out-Null

$archMap = @{
    arm64 = @{ Rid = 'osx-arm64'; Suffix = 'macos_arm64';  Folder = 'data_MelvorModLoader_macos_arm64' }
    x64   = @{ Rid = 'osx-x64';   Suffix = 'macos_x86_64'; Folder = 'data_MelvorModLoader_macos_x86_64' }
}

foreach ($arch in $Architectures) {
    $info = $archMap[$arch]
    $publishDir = Join-Path $publishRoot $info.Rid
    if (Test-Path -LiteralPath $publishDir) { Remove-Item -LiteralPath $publishDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $publishDir | Out-Null

    Write-Host "  publishing $($info.Rid) ..."
    & dotnet publish $loaderProject -c Release -r $info.Rid `
        "-p:GameData=$GameData" -p:UseAppHost=false -o $publishDir
    if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $($info.Rid) (exit $LASTEXITCODE)." }

    $dest = Join-Path (Join-Path $packageRoot $arch) $info.Folder
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item -Path (Join-Path $publishDir '*') -Destination $dest -Recurse -Force

    # These are build/debug leftovers, not needed by Godot.
    Get-ChildItem -LiteralPath $dest -Filter '*.pdb' -File -ErrorAction SilentlyContinue | Remove-Item -Force
    foreach ($leftover in @('MelvorModLoader', 'MelvorModLoader.exe')) {
        $path = Join-Path $dest $leftover
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }

    $dll = Join-Path $dest 'MelvorModLoader.dll'
    $hostfxr = Join-Path $dest 'libhostfxr.dylib'
    if (-not (Test-Path -LiteralPath $dll)) { throw "Missing $dll" }
    if (-not (Test-Path -LiteralPath $hostfxr)) { throw "Missing $hostfxr" }

    Write-Host ("    {0} files, {1:N1} MB" -f (Get-ChildItem -LiteralPath $dest -File).Count,
        ((Get-ChildItem -LiteralPath $dest -File | Measure-Object Length -Sum).Sum / 1MB))
}

# The apps are thin wrappers. The payload and the real scripts stay at the package
# root, like the Windows zip, so a manual drag-and-drop install is possible.
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'installer-app.sh') `
    -Destination (Join-Path $installMacOS 'install-mod-loader-for-macos') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstaller-app.sh') `
    -Destination (Join-Path $uninstallMacOS 'uninstall-mod-loader-for-macos') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README-MACOS.txt') `
    -Destination (Join-Path $installRes 'README.txt') -Force

# Branding assets, including the .icns used as the Finder icon.
foreach ($res in @($installRes, $uninstallRes)) {
    foreach ($asset in @('AppIcon.icns', 'logo.png', 'logo.svg', 'icon.png', 'icon.svg')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $asset) -Destination $res -Force
    }
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-LfFile {
    param([string] $Path, [string] $Text)
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8NoBom)
}

function New-AppInfoPlist {
    param([string] $Path, [string] $Executable, [string] $Identifier, [string] $Name, [string] $Version)
    $plist = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleExecutable</key><string>$Executable</string>
    <key>CFBundleIdentifier</key><string>$Identifier</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>$Name</string>
    <key>CFBundleDisplayName</key><string>$Name</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$Version</string>
    <key>CFBundleVersion</key><string>$Version</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
"@
    [IO.File]::WriteAllText($Path, $plist, $utf8NoBom)
}

New-AppInfoPlist -Path (Join-Path $installApp 'Contents\Info.plist') `
    -Executable 'install-mod-loader-for-macos' -Identifier 'com.modloaderformacos.install' `
    -Name 'Install Mod Loader for MacOS' -Version $Version
New-AppInfoPlist -Path (Join-Path $uninstallApp 'Contents\Info.plist') `
    -Executable 'uninstall-mod-loader-for-macos' -Identifier 'com.modloaderformacos.uninstall' `
    -Name 'Uninstall Mod Loader for MacOS' -Version $Version
foreach ($app in @($installApp, $uninstallApp)) {
    [IO.File]::WriteAllText((Join-Path $app 'Contents\PkgInfo'), 'APPL????',
        [Text.Encoding]::ASCII)
}

# Top-level files: the same pieces the Windows package has, so they can be copied
# into the .app by hand. The two .app bundles above are just optional UI wrappers.
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.sh') -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.sh') -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'README-MACOS.txt') -Destination $packageRoot -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE.txt') -Force
foreach ($asset in @('AppIcon.icns', 'logo.png', 'logo.svg', 'logo@2x.png', 'icon.png', 'icon.svg', 'icon@2x.png')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $asset) -Destination $packageRoot -Force
}
Write-LfFile -Path (Join-Path $packageRoot 'override.cfg') `
    -Text "[dotnet]`n`nproject/assembly_name=`"MelvorModLoader`"`n"

# Mod Viewer goes to the package root as mods/ModViewer. install.sh installs it when
# no Mod Viewer is present, or updates this project's earlier copy; manual installers
# can drag it.
if ($ModViewerZip) {
    $viewerStage = Join-Path $outDir '_modviewer'
    if (Test-Path -LiteralPath $viewerStage) { Remove-Item -LiteralPath $viewerStage -Recurse -Force }
    Expand-Archive -LiteralPath $ModViewerZip -DestinationPath $viewerStage

    $viewerSrc = Join-Path $viewerStage 'mods\ModViewer'
    if (-not (Test-Path -LiteralPath (Join-Path $viewerSrc 'ModViewer.dll'))) {
        throw "The Mod Viewer zip does not contain mods\ModViewer\ModViewer.dll: $ModViewerZip"
    }

    $viewerDest = Join-Path $packageRoot 'mods\ModViewer'
    New-Item -ItemType Directory -Force -Path $viewerDest | Out-Null
    Copy-Item -Path (Join-Path $viewerSrc '*') -Destination $viewerDest -Recurse -Force
    Remove-Item -LiteralPath $viewerStage -Recurse -Force

    $viewerDlls = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'mods') -Recurse -Filter 'ModViewer.dll' -File)
    if ($viewerDlls.Count -ne 1) {
        throw "Expected exactly one ModViewer.dll in the package, found $($viewerDlls.Count)."
    }

    Write-Host "  bundled Mod Viewer: $([IO.Path]::GetFileName($ModViewerZip))"
}
else {
    Write-Warning "No Mod Viewer zip found. Pass -ModViewerZip '<path>' to include it; building without it."
}

function ConvertTo-ZipExternalAttributes {
    param([Parameter(Mandatory)] [uint32] $Mode)
    # High 16 bits: Unix st_mode. The low bits stay 0 (no DOS attributes needed).
    $shifted = [uint32](([uint64] $Mode) * 65536)
    return [BitConverter]::ToInt32([BitConverter]::GetBytes($shifted), 0)
}

$modeDir = ConvertTo-ZipExternalAttributes ([uint32]0x41ED)   # 040755
$modeFile = ConvertTo-ZipExternalAttributes ([uint32]0x81A4)  # 0100644
$modeExec = ConvertTo-ZipExternalAttributes ([uint32]0x81ED)  # 0100755

$sourceFull = (Resolve-Path -LiteralPath $stageRoot).ProviderPath.TrimEnd('\', '/')
$files = @(Get-ChildItem -LiteralPath $sourceFull -Recurse -File | Sort-Object FullName)
if ($files.Count -eq 0) { throw "Nothing to package in $stageRoot" }

$directories = New-Object 'System.Collections.Generic.SortedSet[string]'
foreach ($file in $files) {
    $relative = ($file.FullName.Substring($sourceFull.Length).TrimStart('\', '/')) -replace '\\', '/'
    $parts = $relative -split '/'
    for ($i = 1; $i -lt $parts.Length; $i++) {
        [void] $directories.Add(($parts[0..($i - 1)] -join '/'))
    }
}

if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force }

$stream = [IO.File]::Open($zipPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::ReadWrite)
try {
    $archive = New-Object -TypeName System.IO.Compression.ZipArchive -ArgumentList @(
        $stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        foreach ($relative in $directories) {
            $entry = $archive.CreateEntry($relative + '/')
            $entry.ExternalAttributes = $modeDir
        }

        foreach ($file in $files) {
            $relative = ($file.FullName.Substring($sourceFull.Length).TrimStart('\', '/')) -replace '\\', '/'
            $entry = $archive.CreateEntry($relative, [IO.Compression.CompressionLevel]::Optimal)
            try { $entry.LastWriteTime = [DateTimeOffset] $file.LastWriteTime } catch { }

            $isExecutable = $relative.EndsWith('.sh') -or $relative.EndsWith('.command') -or
                ($relative -match '/Contents/MacOS/[^/]+$')
            $entry.ExternalAttributes = if ($isExecutable) { $modeExec } else { $modeFile }

            $input = [IO.File]::OpenRead($file.FullName)
            try {
                $output = $entry.Open()
                try { $input.CopyTo($output) } finally { $output.Dispose() }
            }
            finally { $input.Dispose() }
        }
    }
    finally { $archive.Dispose() }
}
finally { $stream.Dispose() }

Remove-Item -LiteralPath $stageRoot -Recurse -Force

$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
("{0}  {1}" -f $hash, (Split-Path -Leaf $zipPath)) |
    Set-Content -LiteralPath ($zipPath + '.sha256') -Encoding ASCII

$sizeMb = (Get-Item -LiteralPath $zipPath).Length / 1MB
Write-Host ""
Write-Host ("Package: {0} ({1:N1} MB)" -f $zipPath, $sizeMb)
Write-Host ("SHA256:  {0}" -f $hash)
Write-Host ""
Write-Host "This build is experimental and has not been tested on a Mac."
Write-Host "On the Mac: unzip, then double-click 'Install Mod Loader for MacOS.app'."
Write-Host "Terminal alternative: bash install.sh"
