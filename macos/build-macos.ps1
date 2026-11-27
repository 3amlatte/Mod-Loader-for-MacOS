# Builds the experimental macOS package.
#
# Run from macOS or another machine with the .NET 10 SDK:
#   pwsh ./macos/build-macos.ps1 -GameData "/path/to/data_GamesByMalcs.Melvor2_macos_arm64"
#
# The game's managed DLLs are the same on every platform; point this at the game data folder.
#
# Output: dist-macos/ModLoaderForMacOS-<version>-macos.zip
#         dist-macos/ModLoaderForMacOS-<version>-macos.zip.sha256

[CmdletBinding()]
param(
    # Loader version; defaults to <Version> in Loader/MelvorModLoader.csproj.
    [string] $Version,

    # The game's data folder (contains GamesByMalcs.Melvor2.dll and GodotSharp.dll).
    # Defaults to MELVOR_GAMEDATA, then to <game>/data_GamesByMalcs.Melvor2_macos_arm64
    # when this repository is cloned into the game folder as MelvorModLoader_src.
    [string] $GameData,

    [ValidateSet('arm64', 'x64')]
    [string[]] $Architectures = @('arm64', 'x64'),

    # Built Mod Viewer zip (contains mods/ModViewer/...). Defaults to the newest
    # ModViewer-*.zip in ../melvor-idle-2-mods/dist when that folder exists.
    [string] $ModViewerZip,

    # Built Backup Saver zip (contains mods/BackupSaver/...). Defaults to the newest
    # BackupSaver-*.zip in ../melvor-idle-2-mods/dist when that folder exists.
    [string] $BackupSaverZip,

    # Nexus-safe package: no .sh or .command installer scripts.
    [switch] $ScriptFree,

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
    $relative = Join-Path $root '..\..\data_GamesByMalcs.Melvor2_macos_arm64'
    if (Test-Path -LiteralPath (Join-Path $relative 'GamesByMalcs.Melvor2.dll')) {
        $GameData = (Resolve-Path -LiteralPath $relative).ProviderPath
    }
}

if (-not $GameData -or -not (Test-Path -LiteralPath (Join-Path $GameData 'GamesByMalcs.Melvor2.dll'))) {
    throw "Game data folder not found. Pass -GameData '<game data folder>' (it must contain GamesByMalcs.Melvor2.dll)."
}
$GameData = (Resolve-Path -LiteralPath $GameData).ProviderPath

# Bundle the newest Mod Viewer build by default. The install script replaces any older
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

# Bundle the newest Backup Saver build by default.
if (-not $BackupSaverZip) {
    $siblingDist = Join-Path (Split-Path -Parent $root) 'melvor-idle-2-mods\dist'
    $candidates = @(Get-ChildItem -LiteralPath $siblingDist -Filter 'BackupSaver-*.zip' -File -ErrorAction SilentlyContinue |
        ForEach-Object {
            $match = [regex]::Match($_.Name, 'BackupSaver-([0-9]+(?:\.[0-9]+)*)\.zip$')
            $version = if ($match.Success) { [version] $match.Groups[1].Value } else { [version] '0.0.0' }
            [pscustomobject]@{ File = $_.FullName; Version = $version }
        } |
        Sort-Object Version -Descending)
    if ($candidates.Count -gt 0) { $BackupSaverZip = $candidates[0].File }
}

if ($BackupSaverZip -and -not (Test-Path -LiteralPath $BackupSaverZip)) {
    throw "Backup Saver zip not found: $BackupSaverZip"
}

$stageRoot = Join-Path $outDir 'stage'
$publishRoot = Join-Path $outDir '_publish'
$packageSuffix = if ($ScriptFree) { '-manual' } else { '' }
$packageName = "ModLoaderForMacOS-$Version-macos$packageSuffix"
$packageRoot = Join-Path $stageRoot $packageName
$zipPath = Join-Path $outDir "$packageName.zip"

Write-Host "Mod Loader for MacOS $Version for macOS"
Write-Host "  game data:  $GameData"
Write-Host "  Mod Viewer: $(if ($ModViewerZip) { $ModViewerZip } else { '(not found)' })"
Write-Host "  Backup Saver: $(if ($BackupSaverZip) { $BackupSaverZip } else { '(not found)' })"
Write-Host "  output:     $outDir"

if (Test-Path -LiteralPath $stageRoot) { Remove-Item -LiteralPath $stageRoot -Recurse -Force }
New-Item -ItemType Directory -Force -Path $packageRoot | Out-Null

# The loader payload and the install scripts live at the package root. There is no
# installer .app: users run the readable install.sh from Terminal instead of opening
# an unsigned application.
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

    # These are build/debug leftovers, not needed by Godot. createdump is also
    # removed from the Nexus package because Nexus quarantines native executables.
    Get-ChildItem -LiteralPath $dest -Filter '*.pdb' -File -ErrorAction SilentlyContinue | Remove-Item -Force
    $leftovers = @('MelvorModLoader', 'MelvorModLoader.exe')
    if ($ScriptFree) { $leftovers += 'createdump' }
    foreach ($leftover in $leftovers) {
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

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-LfFile {
    param([string] $Path, [string] $Text)
    [IO.File]::WriteAllText($Path, ($Text -replace "`r`n", "`n"), $utf8NoBom)
}

# Top-level files. The normal package has the double-click scripts; the Nexus
# package leaves them out because Nexus quarantines script installers.
if (-not $ScriptFree) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'install.sh') -Destination $packageRoot -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'uninstall.sh') -Destination $packageRoot -Force
    foreach ($command in @('Install Mod Loader for MacOS.command', 'Uninstall Mod Loader for MacOS.command')) {
        $source = Join-Path $PSScriptRoot $command
        $text = [IO.File]::ReadAllText($source)
        Write-LfFile -Path (Join-Path $packageRoot $command) -Text $text
    }
}

$readme = if ($ScriptFree) { 'README-NEXUS.txt' } else { 'README-MACOS.txt' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot $readme) `
    -Destination (Join-Path $packageRoot 'README-MACOS.txt') -Force
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $packageRoot 'LICENSE.txt') -Force
foreach ($asset in @('AppIcon.icns', 'logo.png', 'logo.svg', 'logo@2x.png', 'icon.png', 'icon.svg', 'icon@2x.png')) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $asset) -Destination $packageRoot -Force
}
Write-LfFile -Path (Join-Path $packageRoot 'override.cfg') `
    -Text "[dotnet]`n`nproject/assembly_name=`"MelvorModLoader`"`n"

# Mod Viewer goes to the package root as mods/ModViewer. install.sh installs it when
# no Mod Viewer is present, or updates this project's earlier copy.
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
    throw "No Mod Viewer zip found. Mod Viewer is required, so the package cannot be built without it. Pass -ModViewerZip '<path>'."
}

# Backup Saver is preinstalled. It backs up saves automatically and keeps the five newest.
if ($BackupSaverZip) {
    $backupStage = Join-Path $outDir '_backupsaver'
    if (Test-Path -LiteralPath $backupStage) { Remove-Item -LiteralPath $backupStage -Recurse -Force }
    Expand-Archive -LiteralPath $BackupSaverZip -DestinationPath $backupStage

    $backupSrc = Join-Path $backupStage 'mods\BackupSaver'
    if (-not (Test-Path -LiteralPath (Join-Path $backupSrc 'BackupSaver.dll'))) {
        throw "The Backup Saver zip does not contain mods\BackupSaver\BackupSaver.dll: $BackupSaverZip"
    }

    $backupDest = Join-Path $packageRoot 'mods\BackupSaver'
    New-Item -ItemType Directory -Force -Path $backupDest | Out-Null
    Copy-Item -Path (Join-Path $backupSrc '*') -Destination $backupDest -Recurse -Force
    Remove-Item -LiteralPath $backupStage -Recurse -Force

    $backupDlls = @(Get-ChildItem -LiteralPath (Join-Path $packageRoot 'mods') -Recurse -Filter 'BackupSaver.dll' -File)
    if ($backupDlls.Count -ne 1) {
        throw "Expected exactly one BackupSaver.dll in the package, found $($backupDlls.Count)."
    }

    Write-Host "  bundled Backup Saver: $([IO.Path]::GetFileName($BackupSaverZip))"
}
else {
    throw "No Backup Saver zip found. Backup Saver is preinstalled, so the package cannot be built without it. Pass -BackupSaverZip '<path>'."
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
if ($ScriptFree) {
    Write-Host "Nexus package: unzip and follow README-MACOS.txt for the manual install."
}
else {
    Write-Host "On the Mac: unzip, then double-click 'Install Mod Loader for MacOS.command'."
}
