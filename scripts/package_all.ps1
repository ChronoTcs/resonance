<#
.SYNOPSIS
    Resonance Master Release Packager
    Builds and packages both Windows and Android releases into unified Releases/v<Version>/ folder.
#>

param(
    [string]$Version = ""
)

$PSScriptRootDirectory = $PSScriptRoot

Write-Host "=====================================================" -ForegroundColor Magenta
Write-Host "  Resonance Master Multi-Platform Release Packager" -ForegroundColor Magenta
Write-Host "=====================================================" -ForegroundColor Magenta

# 1. Package Windows
& "$PSScriptRootDirectory\package_windows.ps1" -Version $Version

# 2. Package Android
& "$PSScriptRootDirectory\package_android.ps1" -Version $Version

Write-Host "`nAll platform release builds completed successfully!" -ForegroundColor Green
