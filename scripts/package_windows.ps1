<#
.SYNOPSIS
    Resonance Windows Release & Delta Patch Packager
    Builds Python Downloader Engine, Flutter Windows, Inno Setup Installer, Portable Zip, Delta Patch, and Manifest.
    Saves outputs into unified: Releases/v<Version>/Windows/

.PARAMETER Version
    Optional version string. If omitted, automatically parsed from pubspec.yaml.

.PARAMETER PreviousVersion
    Optional previous version to generate a delta patch against (e.g. "0.1.7-beta" or "0.1.7-beta.11").
    If omitted, the script automatically searches the Releases/ folder for the latest older version.

.PARAMETER MaxDeltaReleases
    Maximum number of prior releases to generate delta patches against. Default is 3.

.PARAMETER SkipPythonEngine
    Switch to skip compiling python_engine/build_downloader.py.

.PARAMETER SkipInstaller
    Switch to skip compiling Inno Setup .exe installer.
#>

param(
    [string]$Version = "",
    [string]$PreviousVersion = "",
    [int]$MaxDeltaReleases = 3,
    [switch]$SkipPythonEngine = $false,
    [switch]$SkipInstaller = $false
)

$ErrorActionPreference = "Stop"

$WorkspaceRoot = (Get-Item $PSScriptRoot).Parent.FullName

# 1. Resolve Version & Build Number from pubspec.yaml if not provided
$FullVersion = ""
$BuildNumber = 0
$BaseVersion = "0.1.0"

$PubspecContent = Get-Content (Join-Path $WorkspaceRoot "pubspec.yaml") -Raw
if ($PubspecContent -match 'version:\s*([^\s]+)') {
    $RawVersionString = $matches[1].Trim()
    if ($RawVersionString -match '^([^\+]+)\+(\d+)$') {
        $BaseVersion = $matches[1]
        $BuildNumber = [int]$matches[2]
        $FullVersion = $RawVersionString
    } else {
        $BaseVersion = $RawVersionString
        $FullVersion = $RawVersionString
    }
}

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    if ($Version -match '^([^\+]+)\+(\d+)$') {
        $BaseVersion = $matches[1]
        $BuildNumber = [int]$matches[2]
        $FullVersion = $Version
    } else {
        $BaseVersion = $Version
        $FullVersion = if ($BuildNumber -gt 0) { "$Version+$BuildNumber" } else { $Version }
    }
} else {
    $Version = $BaseVersion
}

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host "  Resonance Windows Release Packager (v$Version - Build $BuildNumber)" -ForegroundColor Cyan
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

# 3. Check & Compile Python Downloader Engine
if (-not $SkipPythonEngine) {
    Write-Host "`n[1/6] Preparing Python Downloader Engine..." -ForegroundColor Yellow
    $PythonEngineDir = Join-Path $WorkspaceRoot "python_engine"
    $DownloaderExe = Join-Path $PythonEngineDir "dist\resonance_downloader.exe"
    $BuildDownloaderScript = Join-Path $PythonEngineDir "build_downloader.py"
    $FfmpegBinDir = Join-Path $PythonEngineDir "bin"

    # Verify FFmpeg & FFprobe binaries (>10MB)
    $FfmpegExe = Join-Path $FfmpegBinDir "ffmpeg.exe"
    $FfprobeExe = Join-Path $FfmpegBinDir "ffprobe.exe"
    if ((-not (Test-Path $FfmpegExe)) -or ((Get-Item $FfmpegExe).Length -lt 10MB)) {
        Write-Warning "python_engine\bin\ffmpeg.exe is missing or under 10MB! Downloads may fail."
    } else {
        $ffSize = [math]::Round((Get-Item $FfmpegExe).Length / 1MB, 1)
        Write-Host "  -> Verified FFmpeg:  $ffSize MB" -ForegroundColor DarkGray
    }
    if ((-not (Test-Path $FfprobeExe)) -or ((Get-Item $FfprobeExe).Length -lt 10MB)) {
        Write-Warning "python_engine\bin\ffprobe.exe is missing or under 10MB! Audio analysis may fail."
    } else {
        $fpSize = [math]::Round((Get-Item $FfprobeExe).Length / 1MB, 1)
        Write-Host "  -> Verified FFprobe: $fpSize MB" -ForegroundColor DarkGray
    }

    # Compile resonance_downloader.exe using PyInstaller
    if (Test-Path $BuildDownloaderScript) {
        $pythonObj = Get-Command python -ErrorAction SilentlyContinue
        $PythonCmd = if ($pythonObj) { $pythonObj.Source } else { $null }
        if ($PythonCmd) {
            Write-Host "  -> Compiling resonance_downloader.exe via PyInstaller..." -ForegroundColor Cyan
            & python "$BuildDownloaderScript"
            if ($LASTEXITCODE -ne 0) { throw "python build_downloader.py failed with code $LASTEXITCODE" }
            if (Test-Path $DownloaderExe) {
                $exeSizeMb = [math]::Round((Get-Item $DownloaderExe).Length / 1MB, 2)
                Write-Host "  -> Successfully compiled: resonance_downloader.exe ($exeSizeMb MB)" -ForegroundColor Green
            } else {
                Write-Warning "resonance_downloader.exe was not created by build_downloader.py!"
            }
        } else {
            Write-Warning "python command not found in PATH. Skipping Python downloader compilation."
        }
    }
} else {
    Write-Host "`n[1/6] Skipping Python Downloader Engine compilation (-SkipPythonEngine specified)." -ForegroundColor Gray
}

# 4. Build Flutter Windows (Release)
Write-Host "`n[2/6] Building Flutter Windows (Release)..." -ForegroundColor Yellow
Set-Location $WorkspaceRoot
$env:CL = "/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS"
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    throw "Flutter build windows failed with exit code $LASTEXITCODE"
}

# Auto-download HDiffPatch tools if not already present
$HDiffzExe = Join-Path $ToolsDir "hdiffz.exe"
$HPatchzExe = Join-Path $ToolsDir "hpatchz.exe"
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

# Bundle tools (hpatchz.exe) directly into the application Release folder
if (Test-Path $ToolsDir) {
    $BuildToolsDir = Join-Path $BuildDir "tools"
    if (-not (Test-Path $BuildToolsDir)) {
        New-Item -ItemType Directory -Path $BuildToolsDir -Force | Out-Null
    }
    Copy-Item -Recurse "$ToolsDir\*" $BuildToolsDir -Force
}

# 5. Create/Update Portable Folder & Zip Archive
Write-Host "`n[3/6] Creating Portable Release Bundle..." -ForegroundColor Yellow
$PortableDir = Join-Path $WindowsOutputDir "Release_v$Version"
if (Test-Path $PortableDir) {
    Remove-Item -Recurse -Force $PortableDir
}
Copy-Item -Recurse $BuildDir $PortableDir

# If build number is specified, preserve build snapshot inside WindowsOutputDir/snapshots for hotfix diffing
if ($BuildNumber -gt 0) {
    $SnapshotsDir = Join-Path $WindowsOutputDir "snapshots"
    if (-not (Test-Path $SnapshotsDir)) {
        New-Item -ItemType Directory -Path $SnapshotsDir -Force | Out-Null
    }
    # Sanitize version string for filesystem/GitHub: replace + with . (+ is illegal in GitHub asset names)
    $SafeFullVersion = $FullVersion -replace '\+', '.'
    $BuildSnapshotDir = Join-Path $SnapshotsDir "Release_v$SafeFullVersion"
    if (Test-Path $BuildSnapshotDir) {
        Remove-Item -Recurse -Force $BuildSnapshotDir
    }
    Copy-Item -Recurse $BuildDir $BuildSnapshotDir
    Write-Host "  -> Preserved build snapshot at: $BuildSnapshotDir" -ForegroundColor DarkCyan
}

$PortableZip = Join-Path $WindowsOutputDir "Resonance-v$Version-Windows-Portable.zip"
if (Test-Path $PortableZip) {
    Remove-Item -Force $PortableZip
}
Compress-Archive -Path "$PortableDir\*" -DestinationPath $PortableZip -Force
Write-Host "  -> Portable Zip: $PortableZip" -ForegroundColor Green

# 6. Compile Inno Setup Installer
if (-not $SkipInstaller) {
    Write-Host "`n[4/6] Compiling Inno Setup Installer..." -ForegroundColor Yellow
    $InnoCompiler = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $InnoCompiler)) {
        $InnoCompiler = "C:\Program Files\Inno Setup 6\ISCC.exe"
    }
    if (-not (Test-Path $InnoCompiler)) {
        $isccObj = Get-Command iscc -ErrorAction SilentlyContinue
        if ($isccObj) { $InnoCompiler = $isccObj.Source }
    }

    if (Test-Path $InnoCompiler) {
        $InnoScript = Join-Path $WorkspaceRoot "windows\resonance_installer.iss"
        & "$InnoCompiler" "/DMyAppVersion=$Version" "/O$WindowsOutputDir" "$InnoScript"
        if ($LASTEXITCODE -ne 0) { throw "Inno Setup compilation failed with exit code $LASTEXITCODE" }
        Write-Host "  -> Installer generated in: $WindowsOutputDir" -ForegroundColor Green
    } else {
        Write-Host "  -> Inno Setup Compiler (ISCC.exe) not found. Skipping installer exe." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "`n[4/6] Skipping Inno Setup Installer (-SkipInstaller specified)." -ForegroundColor Gray
}

# 7. Automatic Multi-Release & Hotfix Delta Patch Generation (HDiffPatch)
Write-Host "`n[5/6] Checking for Previous Releases to Generate Delta Patches..." -ForegroundColor Yellow

$GeneratedPatches = @()

# Helper to parse semantic versions + build numbers for accurate sorting
function Get-SemVerTuple([string]$v) {
    $clean = $v.TrimStart('v', 'V')
    $build = 0
    if ($clean.Contains('+')) {
        $buildPart = $clean.Split('+')[1]
        [int]::TryParse($buildPart, [ref]$build) | Out-Null
    }
    $main = $clean.Split('-')[0].Split('+')[0]
    $parts = $main.Split('.')
    $major = 0
    $minor = 0
    $patch = 0
    if ($parts.Length -gt 0) { [int]::TryParse($parts[0], [ref]$major) | Out-Null }
    if ($parts.Length -gt 1) { [int]::TryParse($parts[1], [ref]$minor) | Out-Null }
    if ($parts.Length -gt 2) { [int]::TryParse($parts[2], [ref]$patch) | Out-Null }
    return ([int64]$major * 100000000) + ([int64]$minor * 100000) + ([int64]$patch * 100) + $build
}

$TargetVersionLabel = if ($BuildNumber -gt 0) { "$Version+$BuildNumber" } else { $Version }
$TargetPrevReleases = @()

if (-not [string]::IsNullOrWhiteSpace($PreviousVersion)) {
    $SpecifiedPath = Join-Path $ReleasesRootDir "v$PreviousVersion\Windows\Release_v$PreviousVersion"
    if (Test-Path $SpecifiedPath) {
        $TargetPrevReleases += @{
            Version = $PreviousVersion
            Path = $SpecifiedPath
        }
    } else {
        Write-Host "  -> Specified PreviousVersion v$PreviousVersion not found at $SpecifiedPath" -ForegroundColor DarkYellow
    }
} else {
    $CurrentTuple = Get-SemVerTuple $TargetVersionLabel
    $DiscoveredCandidates = @()

    # 1. Check local snapshots inside current release folder (for in-place hotfix diffs)
    $SnapshotsDir = Join-Path $WindowsOutputDir "snapshots"
    if (Test-Path $SnapshotsDir) {
        Get-ChildItem -Path $SnapshotsDir -Directory | Where-Object { $_.Name -like "Release_v*" } | ForEach-Object {
            $snapVer = $_.Name.Replace("Release_v", "")
            $snapVerNorm = $snapVer -replace '([\w-]+)\.([0-9]+)$', '$1+$2'
            $snapTuple = Get-SemVerTuple $snapVerNorm
            if ($snapTuple -lt $CurrentTuple) {
                $DiscoveredCandidates += @{
                    Tuple = $snapTuple
                    Version = $snapVer
                    Path = $_.FullName
                }
            }
        }
    }

    # 2. Check older major/minor releases in Releases root
    $AllOlder = Get-ChildItem -Path $ReleasesRootDir -Directory | Where-Object { 
        $_.Name -ne "v$Version" -and (Test-Path (Join-Path $_.FullName "Windows\Release_$($_.Name)"))
    }

    foreach ($dir in $AllOlder) {
        $dirVer = $dir.Name.TrimStart('v', 'V')
        $dirTuple = Get-SemVerTuple $dirVer
        if ($dirTuple -lt $CurrentTuple) {
            $DiscoveredCandidates += @{
                Tuple = $dirTuple
                Version = $dirVer
                Path = (Join-Path $dir.FullName "Windows\Release_$($dir.Name)")
            }
        }
    }

    $SortedCandidates = $DiscoveredCandidates | Sort-Object { $_.Tuple } -Descending
    $Selected = $SortedCandidates | Select-Object -First $MaxDeltaReleases

    foreach ($item in $Selected) {
        $TargetPrevReleases += @{
            Version = $item.Version
            Path = $item.Path
        }
    }
}

if ((Test-Path $HDiffzExe) -and ($TargetPrevReleases.Count -gt 0)) {
    foreach ($prev in $TargetPrevReleases) {
        $prevVer = $prev.Version
        $prevPath = $prev.Path
        # Sanitize: replace + with . for GitHub-safe filenames (+ gets mangled to %2B)
        $SafePrevVer = $prevVer -replace '\+', '.'
        $SafeTargetVer = $TargetVersionLabel -replace '\+', '.'
        $PatchName = "Resonance-v$SafePrevVer-to-v$SafeTargetVer-delta.patch"
        $PatchFile = Join-Path $WindowsOutputDir $PatchName
        if (Test-Path $PatchFile) { Remove-Item -Force $PatchFile }

        Write-Host "  -> Generating binary delta patch: v$prevVer -> v$TargetVersionLabel..." -ForegroundColor Cyan
        & "$HDiffzExe" -f -s-64 -c-zstd "$prevPath" "$PortableDir" "$PatchFile"

        if (Test-Path $PatchFile) {
            $SizeBytes = (Get-Item $PatchFile).Length
            $Hash = (Get-FileHash -Path $PatchFile -Algorithm SHA256).Hash.ToLower()
            $SizeMB = [math]::Round($SizeBytes / 1MB, 2)
            Write-Host "     [OK] Delta patch generated: $PatchName ($SizeMB MB)" -ForegroundColor Green

            $GeneratedPatches += @{
                name = $PatchName
                from_version = $prevVer
                to_version = $TargetVersionLabel
                size_bytes = $SizeBytes
                sha256 = $Hash
            }
        }
    }
} else {
    Write-Host "  -> No previous release found or hdiffz.exe missing. Skipping delta patch." -ForegroundColor Gray
}

# 8. Generate Manifest JSON
Write-Host "`n[6/6] Generating Manifest (manifest.json)..." -ForegroundColor Yellow
$ManifestFile = Join-Path $WindowsOutputDir "manifest.json"
$ZipHash = (Get-FileHash -Path $PortableZip -Algorithm SHA256).Hash.ToLower()
$ZipSizeBytes = (Get-Item $PortableZip).Length

$Manifest = @{
    platform = "windows"
    version = $Version
    build_number = $BuildNumber
    full_version = $TargetVersionLabel
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    portable_zip = @{
        name = "Resonance-v$Version-Windows-Portable.zip"
        size_bytes = $ZipSizeBytes
        sha256 = $ZipHash
    }
}

$InstallerExe = Join-Path $WindowsOutputDir "Resonance-v$Version-Windows.exe"
if (-not (Test-Path $InstallerExe)) {
    $AltInstaller = Join-Path $WindowsOutputDir "Resonance-Setup-v$Version.exe"
    if (Test-Path $AltInstaller) { $InstallerExe = $AltInstaller }
}
if (Test-Path $InstallerExe) {
    $Manifest["installer"] = @{
        name = Split-Path -Leaf $InstallerExe
        size_bytes = (Get-Item $InstallerExe).Length
        sha256 = (Get-FileHash -Path $InstallerExe -Algorithm SHA256).Hash.ToLower()
    }
}

if ($GeneratedPatches.Count -gt 0) {
    $Manifest["delta_patches"] = $GeneratedPatches
    $Manifest["delta_patch"] = $GeneratedPatches[0]
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8
Write-Host "  -> Manifest saved: $ManifestFile" -ForegroundColor Green

Write-Host "`n=====================================================" -ForegroundColor Cyan
Write-Host "  Windows Release Package Ready: $WindowsOutputDir" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Cyan
$global:LASTEXITCODE = 0
