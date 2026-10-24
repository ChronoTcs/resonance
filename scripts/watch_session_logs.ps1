param(
    [string]$DeviceId = "10.58.54.48:5555",
    [string]$LogFile = "resonance_session.log"
)

$ErrorActionPreference = "Continue"

# Check device connectivity
$devices = adb devices
if ($devices -notmatch $DeviceId) {
    adb connect $DeviceId | Out-Null
    Start-Sleep -Seconds 1
}

# Find Resonance PID if active
$pidStr = adb -s $DeviceId shell "pidof com.chronostudio.resonance"
$pidClean = if ($pidStr) { $pidStr.Trim() } else { $null }

# Dump current logcat from device
$rawLogs = adb -s $DeviceId shell "logcat -d -v time"
if (-not $rawLogs) {
    Write-Output "NO_NEW_LOGS"
    exit 0
}

# Append new logs to session log file
$rawLogs | Add-Content -Path $LogFile -Encoding utf8

# Clear device logcat buffer so subsequent checks only capture new delta
adb -s $DeviceId logcat -c 2>$null

# Error analysis specifically for Resonance app & audio/discord services
$errorMatches = $rawLogs | Where-Object {
    ($_ -match "com.chronostudio.resonance" -or ($pidClean -and $_ -match "\(\s*$pidClean\s*\)")) -and
    ($_ -match " E/" -or $_ -match "Exception" -or $_ -match "Fatal" -or $_ -match "Crash" -or $_ -match "DEAD_OBJECT") -and
    ($_ -notmatch "FileNotFoundException:.*art_.*\.(jpg|png)") -and # standard initial art fetch miss before caching
    ($_ -notmatch "gralloc4" -and $_ -notmatch "GraphicBufferAllocator" -and $_ -notmatch "AHardwareBuffer") # MTK GPU surface probe
}

# Fast streaming file stats
$fileItem = Get-Item $LogFile
$fileSize = $fileItem.Length
$lineCount = 0
$reader = [System.IO.File]::OpenText($LogFile)
try {
    while ($reader.ReadLine() -ne $null) { $lineCount++ }
} finally {
    $reader.Close()
}


# Subsystem activity
$nowPlaying = ($rawLogs | Where-Object { $_ -match 'Dispatching presence: "(.*?)" by "(.*?)"' } | Select-Object -Last 1)
$gaplessHits = ($rawLogs | Where-Object { $_ -match '\[Gapless\]' } | Measure-Object).Count
$cacheHits = ($rawLogs | Where-Object { $_ -match '\[MediaCache\]' -or $_ -match '\[RateLimitDefender\]' } | Measure-Object).Count
$discordFrames = ($rawLogs | Where-Object { $_ -match 'Received frame from Discord' } | Measure-Object).Count

[PSCustomObject]@{
    Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    FileSize = $fileSize
    LineCount = $lineCount
    AppPid = $pidClean
    NewErrorsCount = ($errorMatches | Measure-Object).Count
    RecentErrors = ($errorMatches | Select-Object -Last 5)
    LatestNowPlaying = $nowPlaying
    GaplessEvents = $gaplessHits
    CacheEvents = $cacheHits
    DiscordAcks = $discordFrames
} | ConvertTo-Json -Depth 4

