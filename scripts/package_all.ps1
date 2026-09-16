<#
.SYNOPSIS
    Resonance Master Multi-Platform Release Packager
    Builds and packages Windows, Android, or all platform releases matching the GitHub Actions release pipeline.

.PARAMETER Platform
    Target platform to package: 'All' (default), 'Windows', or 'Android'.

.PARAMETER Version
    Optional target version string (e.g. "0.1.9-beta" or "0.1.9-beta+14").
    If omitted, automatically parsed from pubspec.yaml.

.PARAMETER PreviousVersion
    Optional previous version for Windows delta patch generation (e.g. "0.1.8-beta" or "0.1.8-beta.13").

.PARAMETER SkipPythonEngine
    Switch to skip compiling Python downloader engine (Windows).

.PARAMETER SkipInstaller
    Switch to skip compiling Inno Setup Windows installer.

.PARAMETER BuildAppBundle
    Switch to build Android App Bundle (.aab). Default is false (faster local APK build).
#>

param(
    [ValidateSet("All", "Windows", "Android")]
    [string]$Platform = "All",
    [string]$Version = "",
    [string]$PreviousVersion = "",
    [switch]$SkipPythonEngine = $false,
    [switch]$SkipInstaller = $false,
    [switch]$BuildAppBundle = $false
)

$ErrorActionPreference = "Stop"
$PSScriptRootDirectory = $PSScriptRoot
$WorkspaceRoot = (Get-Item $PSScriptRootDirectory).Parent.FullName

# 1. Resolve Version & Build Number from pubspec.yaml
$PubspecContent = Get-Content (Join-Path $WorkspaceRoot "pubspec.yaml") -Raw
$BaseVersion = "0.1.0"
$BuildNumber = 1

if ($PubspecContent -match 'version:\s*([^\s]+)') {
    $RawVersionString = $matches[1].Trim()
    if ($RawVersionString -match '^([^\+]+)\+(\d+)$') {
        $BaseVersion = $matches[1]
        $BuildNumber = [int]$matches[2]
    } else {
        $BaseVersion = $RawVersionString
        $BuildNumber = 1
    }
}

if (-not [string]::IsNullOrWhiteSpace($Version)) {
    if ($Version -match '^([^\+]+)\+(\d+)$') {
        $BaseVersion = $matches[1]
        $BuildNumber = [int]$matches[2]
    } else {
        $BaseVersion = $Version
    }
}

$FullVersion = "$BaseVersion+$BuildNumber"
$SafeVersion = "$BaseVersion.$BuildNumber"

Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "  Resonance Master Multi-Platform Release Packager" -ForegroundColor Magenta
Write-Host "  Target Version : v$BaseVersion (Build $BuildNumber)" -ForegroundColor Cyan
Write-Host "  Platforms      : $Platform" -ForegroundColor Cyan
Write-Host "=====================================================" -ForegroundColor Magenta

$StartTime = Get-Date

# 2. Execute Windows Packaging
if ($Platform -eq "All" -or $Platform -eq "Windows") {
    Write-Host "`n>>> [Platform: Windows] Starting Release Build..." -ForegroundColor Yellow
    $winParams = @{
        Version = $BaseVersion
    }
    if (-not [string]::IsNullOrWhiteSpace($PreviousVersion)) {
        $winParams["PreviousVersion"] = $PreviousVersion
    }
    if ($SkipPythonEngine) {
        $winParams["SkipPythonEngine"] = $true
    }
    if ($SkipInstaller) {
        $winParams["SkipInstaller"] = $true
    }
    $global:LASTEXITCODE = 0
    & "$PSScriptRootDirectory\package_windows.ps1" @winParams
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Windows packaging failed with exit code $LASTEXITCODE"
    }
}

# 3. Execute Android Packaging
if ($Platform -eq "All" -or $Platform -eq "Android") {
    Write-Host "`n>>> [Platform: Android] Starting Release Build..." -ForegroundColor Yellow
    $androidParams = @{
        Version = $BaseVersion
        BuildNumber = $BuildNumber
        BuildAppBundle = $BuildAppBundle
    }
    $global:LASTEXITCODE = 0
    & "$PSScriptRootDirectory\package_android.ps1" @androidParams
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Android packaging failed with exit code $LASTEXITCODE"
    }
}

$Duration = (Get-Date) - $StartTime
$Minutes = [math]::Floor($Duration.TotalMinutes)
$Seconds = $Duration.Seconds

Write-Host "`n=====================================================" -ForegroundColor Green
Write-Host "  All Requested Builds Completed in ${Minutes}m ${Seconds}s!" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Green

# 4. Summary of Generated Release Artifacts
$ReleasesVersionDir = Join-Path $WorkspaceRoot "Releases\v$BaseVersion"
if (Test-Path $ReleasesVersionDir) {
    Write-Host "`nGenerated Release Artifacts in ${ReleasesVersionDir}:" -ForegroundColor Cyan
    Get-ChildItem -Path $ReleasesVersionDir -Recurse -File | Where-Object { 
        $_.Extension -in @(".apk", ".aab", ".exe", ".zip", ".patch", ".json") -and -not ($_.FullName -like "*\snapshots\*")
    } | ForEach-Object {
        $relPath = $_.FullName.Substring($ReleasesVersionDir.Length + 1)
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host ("  [{0,7} MB]  {1}" -f $sizeMB, $relPath) -ForegroundColor White
    }
    Write-Host "`nLocal Testing Quick Guide:" -ForegroundColor DarkCyan
    Write-Host "  • Android APK: Run 'adb install -r Releases\v$BaseVersion\Android\Resonance-v$SafeVersion-Android-64bit-arm64.apk'" -ForegroundColor Gray
    Write-Host "  • Windows App: Run 'Releases\v$BaseVersion\Windows\Resonance-v$BaseVersion-Windows.exe' or unpack Portable.zip" -ForegroundColor Gray
}
