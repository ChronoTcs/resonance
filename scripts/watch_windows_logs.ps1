param(
    [string]$LogFile = "resonance_session.log"
)

$ErrorActionPreference = "Continue"

if (-not (Test-Path $LogFile)) {
    Write-Output "LOG_FILE_NOT_FOUND"
    exit 1
}

# Check Windows process
$proc = Get-Process -Name 'resonance' -ErrorAction SilentlyContinue | Select-Object -First 1
$procId = if ($proc) { $proc.Id } else { $null }
$procMemoryMB = if ($proc) { [math]::Round($proc.WorkingSet64 / 1MB, 2) } else { 0 }
$procCpu = if ($proc) { [math]::Round($proc.CPU, 2) } else { 0 }

# Read session logs
$fileItem = Get-Item $LogFile
$fileSize = $fileItem.Length

$rawLogs = Get-Content -Path $LogFile -ErrorAction SilentlyContinue
$lineCount = if ($rawLogs) { $rawLogs.Count } else { 0 }

# Scan for actual errors & exceptions (ignoring flutter pub resolution lines at top)
$errorMatches = $rawLogs | Where-Object {
    ($_ -match "Exception" -or $_ -match "Error:" -or $_ -match "Unhandled" -or $_ -match "FATAL" -or $_ -match "\[ERROR\]" -or $_ -match "Crash") -and
    ($_ -notmatch "available\)") -and # pub package version available info
    ($_ -notmatch "FileNotFoundException:.*art_.*\.(jpg|png)") -and
    ($_ -notmatch "Failed to heal metadata") # auto-heal benign network retry
}

# Subsystem activity
$nowPlayingMatches = $rawLogs | Where-Object { $_ -match '\[DiscordRPC\] Dispatching presence: "(.*?)" by "(.*?)"' }
$latestNowPlaying = if ($nowPlayingMatches) { [string]$nowPlayingMatches[-1] } else { $null }

$recentErrorsClean = if ($errorMatches) { @($errorMatches | Select-Object -Last 5 | ForEach-Object { [string]$_ }) } else { @() }

$discordDispatches = ($rawLogs | Where-Object { $_ -match '\[DiscordRPC\] Dispatching presence' } | Measure-Object).Count
$gaplessHits = ($rawLogs | Where-Object { $_ -match '\[Gapless\]' } | Measure-Object).Count
$cacheHits = ($rawLogs | Where-Object { $_ -match '\[StreamResolution\] Cache hit' -or $_ -match '\[RateLimitDefender\] Local Cache Hit' -or $_ -match '\[StreamCacheTracker\]' } | Measure-Object).Count
$taskbarHits = ($rawLogs | Where-Object { $_ -match '\[WindowsTaskbar\]' } | Measure-Object).Count
$smtcHits = ($rawLogs | Where-Object { $_ -match '\[WindowsSystemMedia\]' } | Measure-Object).Count
$poTokenHits = ($rawLogs | Where-Object { $_ -match '\[WindowsPoTokenService\]' } | Measure-Object).Count

[PSCustomObject]@{
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    FileSize = $fileSize
    LineCount = $lineCount
    ProcessId = $procId
    ProcessMemoryMB = $procMemoryMB
    ProcessCpuSec = $procCpu
    NewErrorsCount = ($errorMatches | Measure-Object).Count
    RecentErrors = $recentErrorsClean
    LatestNowPlaying = $latestNowPlaying
    DiscordDispatches = $discordDispatches
    GaplessEvents = $gaplessHits
    CacheEvents = $cacheHits
    TaskbarEvents = $taskbarHits
    SMTCEvents = $smtcHits
    PoTokenEvents = $poTokenHits
} | ConvertTo-Json -Depth 4

