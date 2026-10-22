param(
    [string]$DeviceName = "Forerunner 265"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $repo "bin\friend\downloads\$stamp"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$shell = New-Object -ComObject Shell.Application
$thisPc = $shell.Namespace(17)
$device = $thisPc.Items() | Where-Object Name -eq $DeviceName | Select-Object -First 1
if (-not $device) { throw "$DeviceName is not connected." }
$storage = $device.GetFolder.Items() | Where-Object Name -eq "Internal Storage" | Select-Object -First 1
$garmin = $storage.GetFolder.Items() | Where-Object Name -eq "GARMIN" | Select-Object -First 1
$apps = $garmin.GetFolder.Items() | Where-Object Name -eq "Apps" | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object Name -eq "LOGS" | Select-Object -First 1
if (-not $logs) { throw "GARMIN/Apps/LOGS was not found." }

$logBases = @("wrist-diary-fr265", "friend-fr265")
$destination = $shell.Namespace($outDir)
$selectedBase = $null
foreach ($base in $logBases) {
    $txtItem = $logs.GetFolder.Items() |
        Where-Object { $_.ExtendedProperty("System.FileName") -ieq ($base + ".txt") } |
        Select-Object -First 1
    if ($txtItem -and $txtItem.ExtendedProperty("System.Size") -gt 0) {
        $selectedBase = $base
        break
    }
}
if (-not $selectedBase) { $selectedBase = $logBases[0] }

foreach ($extension in @("bak", "txt")) {
    $name = $selectedBase + "." + $extension
    $item = $logs.GetFolder.Items() |
        Where-Object { $_.ExtendedProperty("System.FileName") -ieq $name } |
        Select-Object -First 1
    if ($item) { $destination.CopyHere($item, 16) }
}

# Garmin's own crash log. Friend has no entry unless it crashed; .BAK is the
# copy Garmin has already uploaded.
foreach ($name in @("CIQ_LOG.YML", "CIQ_LOG.BAK")) {
    $item = $logs.GetFolder.Items() |
        Where-Object { $_.ExtendedProperty("System.FileName") -ieq $name } |
        Select-Object -First 1
    if ($item) { $destination.CopyHere($item, 16) }
}

$txtPath = Join-Path $outDir ($selectedBase + ".txt")
for ($i = 0; $i -lt 20 -and -not (Test-Path -LiteralPath $txtPath); $i += 1) {
    Start-Sleep -Milliseconds 500
}
if (-not (Test-Path -LiteralPath $txtPath)) {
    throw "Friend's log was not found. Open Friend once, press START, then reconnect."
}

. (Join-Path $PSScriptRoot "friend-export.ps1")

$allLines = @()
$bakPath = Join-Path $outDir ($selectedBase + ".bak")
if (Test-Path -LiteralPath $bakPath) { $allLines += Get-Content -LiteralPath $bakPath }
$allLines += Get-Content -LiteralPath $txtPath

$block = Get-FriendExportBlock $allLines
if (-not $block) {
    throw "No complete Friend export was found. Open Friend, press START, and reconnect."
}
$exportMarker = $block[0] -split ","
$schemaVersion = if ($exportMarker.Count -ge 2) { $exportMarker[1] } else { "unknown" }
$appVersion = if ($exportMarker.Count -ge 3) { $exportMarker[2] } else { "0.1.0-unlabelled" }
$deviceLine = @($block | Where-Object { $_ -like "FRIEND_DEVICE,*" }) | Select-Object -First 1
$deviceParts = if ($deviceLine) { $deviceLine -split "," } else { @() }
[pscustomobject]@{
    app_version = $appVersion
    schema_version = $schemaVersion
    retrieved_at = (Get-Date).ToString("o")
    device = $DeviceName
    part_number = if ($deviceParts.Count -ge 2) { $deviceParts[1] } else { $null }
    firmware = if ($deviceParts.Count -ge 3) { $deviceParts[2] } else { $null }
    connect_iq = if ($deviceParts.Count -ge 4) { $deviceParts[3] } else { $null }
    tones_on = if ($deviceParts.Count -ge 5) { $deviceParts[4] } else { $null }
    vibrate_on = if ($deviceParts.Count -ge 6) { $deviceParts[5] } else { $null }
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outDir "export-metadata.json")

$snapshots = @(Read-FriendCsvSection $block "snap")
$sessions = @(Read-FriendCsvSection $block "session3")
if ($sessions.Count -eq 0) { $sessions = @(Read-FriendCsvSection $block "session") }
$chapters = @(Read-FriendCsvSection $block "chapter3")
$live = @(ConvertFrom-FriendLive4 (Get-FriendSectionLines $block "live4"))
if ($live.Count -eq 0) { $live = @(Read-FriendCsvSection $block "live3") }
if ($live.Count -eq 0) { $live = @(Read-FriendCsvSection $block "live") }
$snapshots | Export-Csv (Join-Path $outDir "snapshots.csv") -NoTypeInformation
$sessions | Export-Csv (Join-Path $outDir "sessions.csv") -NoTypeInformation
$chapters | Export-Csv (Join-Path $outDir "chapters.csv") -NoTypeInformation
$live | Export-Csv (Join-Path $outDir "live.csv") -NoTypeInformation

# Each export only carries the newest records, so every read also grows a
# permanent archive; repeated reads add up to the whole history.
$archiveDir = Join-Path $repo "binriendrchive"
New-Item -ItemType Directory -Force -Path $archiveDir | Out-Null
$newRows = @(
    Add-FriendArchive (Join-Path $archiveDir "snapshots.csv") $snapshots "epoch"
    Add-FriendArchive (Join-Path $archiveDir "sessions.csv") $sessions "start_epoch"
    Add-FriendArchive (Join-Path $archiveDir "chapters.csv") $chapters "start_epoch"
    Add-FriendArchive (Join-Path $archiveDir "live.csv") $live "epoch"
)

Write-Host "[copied] $outDir"
Write-Host "[export] Friend v$appVersion schema=$schemaVersion"
Write-Host "[records] snapshots=$($snapshots.Count) sessions=$($sessions.Count) chapters=$($chapters.Count) live=$($live.Count)"
Write-Host "[archive] $archiveDir added snapshots=$($newRows[0]) sessions=$($newRows[1]) chapters=$($newRows[2]) live=$($newRows[3])"
if ($snapshots.Count -gt 0) {
    Write-Host "`nLatest check-in"
    $snapshots[-1] | Format-List
}
if ($sessions.Count -gt 0) {
    Write-Host "`nRecent sessions"
    # exit_reason: 1 Back, 2 the watch closed it, 0 or blank = before v0.4.0.
    $sessions | Select-Object -Last 8 start_epoch,duration_s,exit_reason,
        @{ Name = "idle_s"; Expression = {
            if ($_.last_input_s -and [int]$_.last_input_s -ge 0) {
                [int]$_.duration_s - [int]$_.last_input_s
            } }
        },
        inputs,hides,battery_start,battery_end,mem_peak_kb,hr4h_avg,hr_avg,hr_max,
        motion_avg,moving_pct,steps_start,steps_end |
        Format-Table -AutoSize
}
if ($chapters.Count -gt 0) {
    Write-Host "`nRecent effort chapters"
    $chapters | Select-Object -Last 12 start_epoch,duration_s,partial,baseline_hr,
        hr_avg,hr_max,hr_delta_peak,motion_avg,moving_pct,steps_start,steps_end,reason |
        Format-Table -AutoSize
}
