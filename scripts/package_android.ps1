<#
.SYNOPSIS
    Resonance Android Release Packager
    Builds Universal & Split-ABI APKs and AppBundle (.aab).
    Saves outputs into unified: Releases/v<Version>/Android/

.PARAMETER Version
    Optional version string. If omitted, automatically parsed from pubspec.yaml.

.PARAMETER BuildAppBundle
    Switch to also build Android App Bundle (.aab) for Google Play. Default is true.
#>

param(
    [string]$Version = "",
    [switch]$BuildAppBundle = $true
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

Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Resonance Android Release Packager (v$Version)" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green

# 2. Unified Releases Directory Structure: Releases/v<Version>/Android
$ReleasesRootDir  = Join-Path $WorkspaceRoot "Releases"
$VersionRootDir   = Join-Path $ReleasesRootDir "v$Version"
$AndroidOutputDir = Join-Path $VersionRootDir "Android"
$ApkBuildDir      = Join-Path $WorkspaceRoot "build\app\outputs\flutter-apk"
$BundleBuildDir   = Join-Path $WorkspaceRoot "build\app\outputs\bundle\release"

if (-not (Test-Path $AndroidOutputDir)) {
    New-Item -ItemType Directory -Path $AndroidOutputDir -Force | Out-Null
    Write-Host "[Dir] Created new release folder: $AndroidOutputDir" -ForegroundColor Green
} else {
    Write-Host "[Dir] Updating existing release folder: $AndroidOutputDir" -ForegroundColor Yellow
}

Set-Location $WorkspaceRoot

# 3. Build Split-ABI APKs (Smaller footprint per device architecture)
Write-Host "`n[1/4] Building Split-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)..." -ForegroundColor Yellow
flutter build apk --release --split-per-abi

$Abis = @(
    @{ SourceName = "app-arm64-v8a-release.apk";   DestName = "Resonance-v$Version-Android-arm64-v8a.apk" },
    @{ SourceName = "app-armeabi-v7a-release.apk"; DestName = "Resonance-v$Version-Android-armeabi-v7a.apk" },
    @{ SourceName = "app-x86_64-release.apk";      DestName = "Resonance-v$Version-Android-x86_64.apk" }
)

$Artifacts = @()

foreach ($abi in $Abis) {
    $src = Join-Path $ApkBuildDir $abi.SourceName
    $dest = Join-Path $AndroidOutputDir $abi.DestName
    if (Test-Path $src) {
        Copy-Item -Path $src -Destination $dest -Force
        $sizeMB = [math]::Round((Get-Item $dest).Length / 1MB, 2)
        $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
        Write-Host "  -> Generated: $($abi.DestName) ($sizeMB MB)" -ForegroundColor Green
        $Artifacts += @{
            name = $abi.DestName
            size_bytes = (Get-Item $dest).Length
            sha256 = $hash
        }
    }
}

# 4. Build Universal APK (Single APK that works on any device)
Write-Host "`n[2/4] Building Universal Release APK..." -ForegroundColor Yellow
flutter build apk --release

$UniversalSrc = Join-Path $ApkBuildDir "app-release.apk"
$UniversalDest = Join-Path $AndroidOutputDir "Resonance-v$Version-Android-Universal.apk"
if (Test-Path $UniversalSrc) {
    Copy-Item -Path $UniversalSrc -Destination $UniversalDest -Force
    $univSizeMB = [math]::Round((Get-Item $UniversalDest).Length / 1MB, 2)
    $univHash = (Get-FileHash -Path $UniversalDest -Algorithm SHA256).Hash.ToLower()
    Write-Host "  -> Generated: Resonance-v$Version-Android-Universal.apk ($univSizeMB MB)" -ForegroundColor Green
    $Artifacts += @{
        name = "Resonance-v$Version-Android-Universal.apk"
        size_bytes = (Get-Item $UniversalDest).Length
        sha256 = $univHash
    }
}

# 5. Build Android App Bundle (.aab)
if ($BuildAppBundle) {
    Write-Host "`n[3/4] Building Android App Bundle (.aab)..." -ForegroundColor Yellow
    try {
        flutter build appbundle --release
        $BundleSrc = Join-Path $BundleBuildDir "app-release.aab"
        $BundleDest = Join-Path $AndroidOutputDir "Resonance-v$Version-Android.aab"
        if (Test-Path $BundleSrc) {
            Copy-Item -Path $BundleSrc -Destination $BundleDest -Force
            $bundleSizeMB = [math]::Round((Get-Item $BundleDest).Length / 1MB, 2)
            $bundleHash = (Get-FileHash -Path $BundleDest -Algorithm SHA256).Hash.ToLower()
            Write-Host "  -> Generated: Resonance-v$Version-Android.aab ($bundleSizeMB MB)" -ForegroundColor Green
            $Artifacts += @{
                name = "Resonance-v$Version-Android.aab"
                size_bytes = (Get-Item $BundleDest).Length
                sha256 = $bundleHash
            }
        }
    } catch {
        Write-Host "  -> AppBundle build skipped or failed: $_" -ForegroundColor DarkYellow
    }
}

# 6. Generate Manifest JSON
Write-Host "`n[4/4] Generating Android Manifest (manifest.json)..." -ForegroundColor Yellow
$ManifestFile = Join-Path $AndroidOutputDir "manifest.json"

$Manifest = @{
    platform = "android"
    version = $Version
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    artifacts = $Artifacts
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8
Write-Host "  -> Manifest saved: $ManifestFile" -ForegroundColor Green

Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "  Android Release Package Ready: $AndroidOutputDir" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
