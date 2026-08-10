<#
.SYNOPSIS
    Resonance Windows Release & Delta Patch Packager
    Builds Flutter Windows, Inno Setup Installer, Portable Zip, Delta Patch, and Manifest.
    Saves outputs into unified: Releases/v<Version>/Windows/

.PARAMETER Version
    Optional version string. If omitted, automatically parsed from pubspec.yaml.

.PARAMETER PreviousVersion
    Optional previous version to generate a delta patch against (e.g. "0.1.2-beta").
    If omitted, the script automatically searches the Releases/ folder for the latest older version.
#>

param(
    [string]$Version = "",
    [string]$PreviousVersion = ""
)

$ErrorActionPreference = "Stop"

$WorkspaceRoot = (Get-Item $PSScriptRoot).Parent.FullName

# 1. Resolve Version from pubspec.yaml if not provided
if ([string]::IsNullOrWhiteSpace($Version)) {
    $PubspecContent = Get-Content (Join-Path $WorkspaceRoot "pubspec.yaml") -Raw
    if ($PubspecContent -match 'version:\s*([^\s\+]+)') {
        $Version = $matches[1].Trim()
    } else {
        $Version = "0.1.0"
    }
}

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  Resonance Windows Release Packager (v$Version)" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan

# 2. Unified Releases Directory Structure: Releases/v<Version>/Windows
$ReleasesRootDir = Join-Path $WorkspaceRoot "Releases"
$VersionRootDir  = Join-Path $ReleasesRootDir "v$Version"
$WindowsOutputDir = Join-Path $VersionRootDir "Windows"
$BuildDir        = Join-Path $WorkspaceRoot "build\windows\x64\runner\Release"
$ToolsDir        = Join-Path $WorkspaceRoot "windows\tools"

if (-not (Test-Path $WindowsOutputDir)) {
    New-Item -ItemType Directory -Path $WindowsOutputDir -Force | Out-Null
    Write-Host "[Dir] Created new release folder: $WindowsOutputDir" -ForegroundColor Green
} else {
    Write-Host "[Dir] Updating existing release folder: $WindowsOutputDir" -ForegroundColor Yellow
}

# 3. Build Flutter Windows (Release)
Write-Host "`n[1/5] Building Flutter Windows (Release)..." -ForegroundColor Yellow
Set-Location $WorkspaceRoot
flutter build windows --release

if (-not (Test-Path $BuildDir)) {
    Write-Error "Flutter build failed. $BuildDir not found."
}

# 4. Create/Update Portable Folder & Zip Archive
Write-Host "`n[2/5] Creating Portable Release Bundle..." -ForegroundColor Yellow
$PortableDir = Join-Path $WindowsOutputDir "Release_v$Version"
if (Test-Path $PortableDir) {
    Remove-Item -Recurse -Force $PortableDir
}
Copy-Item -Recurse $BuildDir $PortableDir

$PortableZip = Join-Path $WindowsOutputDir "Resonance-v$Version-Windows-Portable.zip"
if (Test-Path $PortableZip) {
    Remove-Item -Force $PortableZip
}
Compress-Archive -Path "$PortableDir\*" -DestinationPath $PortableZip -Force
Write-Host "  -> Portable Zip: $PortableZip" -ForegroundColor Green

# 5. Compile Inno Setup Installer
Write-Host "`n[3/5] Compiling Inno Setup Installer..." -ForegroundColor Yellow
$InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $InnoCompiler)) {
    $InnoCompiler = "C:\Program Files\Inno Setup 6\ISCC.exe"
}

if (Test-Path $InnoCompiler) {
    $InnoScript = Join-Path $WorkspaceRoot "windows\resonance_installer.iss"
    & "$InnoCompiler" "/DMyAppVersion=$Version" "/O$WindowsOutputDir" "$InnoScript"
    Write-Host "  -> Installer generated in: $WindowsOutputDir" -ForegroundColor Green
} else {
    Write-Host "  -> Inno Setup Compiler (ISCC.exe) not found. Skipping installer exe." -ForegroundColor DarkYellow
}

# 6. Automatic Delta Patch Generation (HDiffPatch)
Write-Host "`n[4/5] Checking for Previous Releases to Generate Delta Patch..." -ForegroundColor Yellow
$HDiffzExe = Join-Path $ToolsDir "hdiffz.exe"
$HPatchzExe = Join-Path $ToolsDir "hpatchz.exe"

# Auto-download HDiffPatch tools if not already present
if ((-not (Test-Path $HDiffzExe)) -or (-not (Test-Path $HPatchzExe))) {
    try {
        Write-Host "  -> HDiffPatch tools missing. Auto-downloading latest binaries..." -ForegroundColor Cyan
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ReleaseMeta = Invoke-RestMethod -Uri "https://api.github.com/repos/sisong/HDiffPatch/releases/latest" -Headers @{'User-Agent'='PowerShell'}
        $Asset = $ReleaseMeta.assets | Where-Object { $_.name -like "*windows*.zip" -or $_.name -like "*win32*.zip" -or $_.name -like "*win64*.zip" } | Select-Object -First 1
        if ($Asset) {
            $ZipTmp = Join-Path $ToolsDir "hdiff_tmp.zip"
            Invoke-WebRequest -Uri $Asset.browser_download_url -OutFile $ZipTmp
            $ExtractTmp = Join-Path $ToolsDir "hdiff_extract"
            if (Test-Path $ExtractTmp) { Remove-Item -Recurse -Force $ExtractTmp }
            Expand-Archive -Path $ZipTmp -DestinationPath $ExtractTmp -Force
            Get-ChildItem -Path $ExtractTmp -Recurse -Filter "*.exe" | ForEach-Object {
                Copy-Item $_.FullName -Destination $ToolsDir -Force
            }
            Remove-Item -Recurse -Force $ExtractTmp
            Remove-Item -Force $ZipTmp
            Write-Host "  -> HDiffPatch binaries successfully installed to $ToolsDir" -ForegroundColor Green
        }
    } catch {
        Write-Host "  -> Could not auto-download HDiffPatch: $_" -ForegroundColor DarkYellow
    }
}

$PatchFile = ""
$PatchHash = ""
$PatchSizeBytes = 0

# Auto-detect previous release directory if not explicitly provided
if ([string]::IsNullOrWhiteSpace($PreviousVersion)) {
    $OlderReleases = Get-ChildItem -Path $ReleasesRootDir -Directory | Where-Object { 
        $_.Name -ne "v$Version" -and (Test-Path (Join-Path $_.FullName "Windows\Release_$($_.Name)"))
    } | Sort-Object LastWriteTime -Descending

    if ($OlderReleases.Count -gt 0) {
        $PrevDir = $OlderReleases[0]
        $PreviousVersion = $PrevDir.Name.Replace("v", "")
        $PreviousReleasePath = Join-Path $PrevDir.FullName "Windows\Release_$($PrevDir.Name)"
        Write-Host "  -> Auto-detected previous release: v$PreviousVersion at $PreviousReleasePath" -ForegroundColor Cyan
    }
} else {
    $PreviousReleasePath = Join-Path $ReleasesRootDir "v$PreviousVersion\Windows\Release_v$PreviousVersion"
}

if ((Test-Path $HDiffzExe) -and ($PreviousReleasePath) -and (Test-Path $PreviousReleasePath)) {
    $PatchName = "Resonance-v$PreviousVersion-to-v$Version-delta.patch"
    $PatchFile = Join-Path $WindowsOutputDir $PatchName
    if (Test-Path $PatchFile) { Remove-Item -Force $PatchFile }

    Write-Host "  -> Generating binary delta patch against v$PreviousVersion..."
    & "$HDiffzExe" -f -s-64 -c-zstd "$PreviousReleasePath" "$PortableDir" "$PatchFile"

    if (Test-Path $PatchFile) {
        $PatchSizeBytes = (Get-Item $PatchFile).Length
        $PatchHash = (Get-FileHash -Path $PatchFile -Algorithm SHA256).Hash.ToLower()
        $PatchSizeMB = [math]::Round($PatchSizeBytes / 1MB, 2)
        Write-Host "  -> Delta patch generated: $PatchName ($PatchSizeMB MB)" -ForegroundColor Green
    }
} else {
    Write-Host "  -> No previous release found or hdiffz.exe missing. Skipping delta patch." -ForegroundColor Gray
}

# 7. Generate Manifest JSON
Write-Host "`n[5/5] Generating Manifest (manifest.json)..." -ForegroundColor Yellow
$ManifestFile = Join-Path $WindowsOutputDir "manifest.json"
$ZipHash = (Get-FileHash -Path $PortableZip -Algorithm SHA256).Hash.ToLower()
$ZipSizeBytes = (Get-Item $PortableZip).Length

$Manifest = @{
    platform = "windows"
    version = $Version
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    portable_zip = @{
        name = "Resonance-v$Version-Windows-Portable.zip"
        size_bytes = $ZipSizeBytes
        sha256 = $ZipHash
    }
}

$InstallerExe = Join-Path $WindowsOutputDir "Resonance-v$Version-Windows.exe"
if (Test-Path $InstallerExe) {
    $Manifest["installer"] = @{
        name = "Resonance-v$Version-Windows.exe"
        size_bytes = (Get-Item $InstallerExe).Length
        sha256 = (Get-FileHash -Path $InstallerExe -Algorithm SHA256).Hash.ToLower()
    }
}

if ($PatchSizeBytes -gt 0) {
    $Manifest["delta_patch"] = @{
        name = "Resonance-v$PreviousVersion-to-v$Version-delta.patch"
        from_version = $PreviousVersion
        to_version = $Version
        size_bytes = $PatchSizeBytes
        sha256 = $PatchHash
    }
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8
Write-Host "  -> Manifest saved: $ManifestFile" -ForegroundColor Green

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "  Windows Release Package Ready: $WindowsOutputDir" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
