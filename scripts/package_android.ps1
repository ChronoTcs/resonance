<#
.SYNOPSIS
    Resonance Android Release Packager
    Builds Universal & Split-ABI APKs and AppBundle (.aab).
    Matches Proposal B naming used in .github/workflows/release.yml.
    Saves outputs into unified: Releases/v<Version>/Android/

.PARAMETER Version
    Optional version string. If omitted, automatically parsed from pubspec.yaml.

.PARAMETER BuildNumber
    Optional build number. If omitted, automatically parsed from pubspec.yaml.

.PARAMETER BuildAppBundle
    Switch to also build Android App Bundle (.aab) for Google Play. Default is false.

.PARAMETER TargetAbi
    Optional target architecture to build only a single APK (e.g. "arm64", "arm64-v8a", "android-arm64", "arm", "x64").
    If specified, builds only the requested architecture and skips all other ABIs.
#>

param(
    [string]$Version = "",
    [int]$BuildNumber = 0,
    [switch]$BuildAppBundle = $false,
    [string]$TargetAbi = ""
)

$ErrorActionPreference = "Stop"

$WorkspaceRoot = (Get-Item $PSScriptRoot).Parent.FullName

# 1. Resolve Version and Build Number from pubspec.yaml if not provided
$PubspecContent = Get-Content (Join-Path $WorkspaceRoot "pubspec.yaml") -Raw
$ParsedBaseVersion = "0.1.0"
$ParsedBuildNumber = 1

if ($PubspecContent -match 'version:\s*([^\s]+)') {
    $RawVersionString = $matches[1].Trim()
    if ($RawVersionString -match '^([^\+]+)\+(\d+)$') {
        $ParsedBaseVersion = $matches[1]
        $ParsedBuildNumber = [int]$matches[2]
    } else {
        $ParsedBaseVersion = $RawVersionString
        $ParsedBuildNumber = 1
    }
}

$BaseVersion = if (-not [string]::IsNullOrWhiteSpace($Version)) {
    if ($Version -match '^([^\+]+)\+(\d+)$') {
        if ($BuildNumber -le 0) { $BuildNumber = [int]$matches[2] }
        $matches[1]
    } else {
        $Version
    }
} else {
    $ParsedBaseVersion
}

if ($BuildNumber -le 0) {
    $BuildNumber = $ParsedBuildNumber
}

$FullVersion = "$BaseVersion+$BuildNumber"
$SafeVersion = if ($BuildNumber -gt 0) { "$BaseVersion.$BuildNumber" } else { $BaseVersion }

Write-Host "=====================================================" -ForegroundColor Green
Write-Host "  Resonance Android Release Packager (v$SafeVersion)" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green

# 2. Unified Releases Directory Structure: Releases/v<Version>/Android
$ReleasesRootDir  = Join-Path $WorkspaceRoot "Releases"
$VersionRootDir   = Join-Path $ReleasesRootDir "v$BaseVersion"
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

# 3. Build Android Release Artifacts
$Artifacts = @()

if (-not [string]::IsNullOrWhiteSpace($TargetAbi)) {
    $NormalizedAbi = $TargetAbi.Trim().ToLower()
    $TargetPlatform = ""
    $DestName = ""

    switch -Wildcard ($NormalizedAbi) {
        "*arm64*" {
            $TargetPlatform = "android-arm64"
            $DestName = "Resonance-v$SafeVersion-Android-64bit-arm64.apk"
            break
        }
        "*v7*" {
            $TargetPlatform = "android-arm"
            $DestName = "Resonance-v$SafeVersion-Android-32bit-v7a.apk"
            break
        }
        "*arm*" {
            $TargetPlatform = "android-arm"
            $DestName = "Resonance-v$SafeVersion-Android-32bit-v7a.apk"
            break
        }
        "*x64*" {
            $TargetPlatform = "android-x64"
            $DestName = "Resonance-v$SafeVersion-Android-x86_64.apk"
            break
        }
        "*x86*" {
            $TargetPlatform = "android-x64"
            $DestName = "Resonance-v$SafeVersion-Android-x86_64.apk"
            break
        }
        "universal" {
            $TargetPlatform = "universal"
            $DestName = "Resonance-v$SafeVersion-Android-Universal.apk"
            break
        }
        default {
            throw "Unknown TargetAbi '$TargetAbi'. Supported values: arm64, arm, x64, universal"
        }
    }

    Write-Host "`n[Target ABI] Single architecture build requested: $TargetAbi -> $TargetPlatform" -ForegroundColor Cyan
    Write-Host "[1/2] Building APK for target platform: $TargetPlatform..." -ForegroundColor Yellow

    # Clean intermediate apks to ensure we pick up the newly generated binary
    if (Test-Path $ApkBuildDir) {
        Remove-Item -Path "$ApkBuildDir\*.apk" -Force -ErrorAction SilentlyContinue
    }

    if ($TargetPlatform -eq "universal") {
        flutter build apk --release
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed with exit code $LASTEXITCODE" }
        $SingleApk = Get-ChildItem -Path $ApkBuildDir -Filter "app-release.apk" | Select-Object -First 1
    } else {
        flutter build apk --release --split-per-abi
        if ($LASTEXITCODE -ne 0) { throw "flutter build apk --split-per-abi failed with exit code $LASTEXITCODE" }
        $AbiPattern = switch -Wildcard ($TargetPlatform) {
            "*arm64*" { "*arm64-v8a*"; break }
            "*arm*"   { "*armeabi-v7a*"; break }
            "*x64*"   { "*x86_64*"; break }
            default   { "*$TargetPlatform*"; break }
        }
        $SingleApk = Get-ChildItem -Path $ApkBuildDir -Filter "*.apk" | Where-Object { $_.Name -like $AbiPattern } | Select-Object -First 1
    }

    if (-not $SingleApk) {
        throw "Could not find built APK in $ApkBuildDir"
    }

    $dest = Join-Path $AndroidOutputDir $DestName
    Copy-Item -Path $SingleApk.FullName -Destination $dest -Force
    $sizeMB = [math]::Round((Get-Item $dest).Length / 1MB, 2)
    $hash = (Get-FileHash -Path $dest -Algorithm SHA256).Hash.ToLower()
    Write-Host "  -> Generated: $DestName ($sizeMB MB)" -ForegroundColor Green

    $Artifacts += @{
        name = $DestName
        size_bytes = (Get-Item $dest).Length
        sha256 = $hash
    }
} else {
    # 3. Build Split-ABI APKs (Smaller footprint per device architecture)
    Write-Host "`n[1/4] Building Split-ABI APKs (arm64-v8a, armeabi-v7a, x86_64)..." -ForegroundColor Yellow
    flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk --split-per-abi failed with exit code $LASTEXITCODE" }

    # Proposal B Naming matching .github/workflows/release.yml
    $Abis = @(
        @{ SourceName = "app-arm64-v8a-release.apk";   DestName = "Resonance-v$SafeVersion-Android-64bit-arm64.apk" },
        @{ SourceName = "app-armeabi-v7a-release.apk"; DestName = "Resonance-v$SafeVersion-Android-32bit-v7a.apk" },
        @{ SourceName = "app-x86_64-release.apk";      DestName = "Resonance-v$SafeVersion-Android-x86_64.apk" }
    )

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

    # 4. Build Universal APK (Single APK fallback for all architectures)
    Write-Host "`n[2/4] Building Universal Release APK..." -ForegroundColor Yellow
    flutter build apk --release
    if ($LASTEXITCODE -ne 0) { throw "flutter build apk (universal) failed with exit code $LASTEXITCODE" }

    $UniversalSrc = Join-Path $ApkBuildDir "app-release.apk"
    $UniversalDest = Join-Path $AndroidOutputDir "Resonance-v$SafeVersion-Android-Universal.apk"
    if (Test-Path $UniversalSrc) {
        Copy-Item -Path $UniversalSrc -Destination $UniversalDest -Force
        $univSizeMB = [math]::Round((Get-Item $UniversalDest).Length / 1MB, 2)
        $univHash = (Get-FileHash -Path $UniversalDest -Algorithm SHA256).Hash.ToLower()
        Write-Host "  -> Generated: Resonance-v$SafeVersion-Android-Universal.apk ($univSizeMB MB)" -ForegroundColor Green
        $Artifacts += @{
            name = "Resonance-v$SafeVersion-Android-Universal.apk"
            size_bytes = (Get-Item $UniversalDest).Length
            sha256 = $univHash
        }
    }

    # 5. Build Android App Bundle (.aab) - Optional
    if ($BuildAppBundle) {
        Write-Host "`n[3/4] Building Android App Bundle (.aab)..." -ForegroundColor Yellow
        try {
            flutter build appbundle --release
            $BundleSrc = Join-Path $BundleBuildDir "app-release.aab"
            $BundleDest = Join-Path $AndroidOutputDir "Resonance-v$SafeVersion-Android.aab"
            if (Test-Path $BundleSrc) {
                Copy-Item -Path $BundleSrc -Destination $BundleDest -Force
                $bundleSizeMB = [math]::Round((Get-Item $BundleDest).Length / 1MB, 2)
                $bundleHash = (Get-FileHash -Path $BundleDest -Algorithm SHA256).Hash.ToLower()
                Write-Host "  -> Generated: Resonance-v$SafeVersion-Android.aab ($bundleSizeMB MB)" -ForegroundColor Green
                $Artifacts += @{
                    name = "Resonance-v$SafeVersion-Android.aab"
                    size_bytes = (Get-Item $BundleDest).Length
                    sha256 = $bundleHash
                }
            }
        } catch {
            Write-Host "  -> AppBundle build skipped or failed: $_" -ForegroundColor DarkYellow
        }
    } else {
        Write-Host "`n[3/4] Skipping Android App Bundle (.aab) - Pass -BuildAppBundle to enable." -ForegroundColor Gray
    }
}

# 6. Generate or Update Manifest JSON
Write-Host "`n[Manifest] Generating Android Manifest (manifest.json)..." -ForegroundColor Yellow
$ManifestFile = Join-Path $AndroidOutputDir "manifest.json"

if (Test-Path $ManifestFile) {
    try {
        $ExistingJson = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json
        if ($ExistingJson.artifacts) {
            $ExistingArtifacts = @($ExistingJson.artifacts | Where-Object { 
                $currName = $_.name
                -not ($Artifacts | Where-Object { $_.name -eq $currName })
            })
            $Artifacts = $ExistingArtifacts + $Artifacts
        }
    } catch {
        # Ignore parse error, overwrite
    }
}

$Manifest = @{
    platform = "android"
    version = $BaseVersion
    build_number = $BuildNumber
    full_version = $FullVersion
    generated_at = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
    artifacts = $Artifacts
}

$Manifest | ConvertTo-Json -Depth 5 | Set-Content -Path $ManifestFile -Encoding UTF8
Write-Host "  -> Manifest saved: $ManifestFile" -ForegroundColor Green

Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "  Android Release Package Ready: $AndroidOutputDir" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green
$global:LASTEXITCODE = 0
