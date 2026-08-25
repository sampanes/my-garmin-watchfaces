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

$txtPath = Join-Path $outDir ($selectedBase + ".txt")
for ($i = 0; $i -lt 20 -and -not (Test-Path -LiteralPath $txtPath); $i += 1) {
    Start-Sleep -Milliseconds 500
}
if (-not (Test-Path -LiteralPath $txtPath)) {
    throw "Friend's log was not found. Open Friend once, press Select, then reconnect."
}

$allLines = @()
$bakPath = Join-Path $outDir ($selectedBase + ".bak")
if (Test-Path -LiteralPath $bakPath) { $allLines += Get-Content -LiteralPath $bakPath }
$allLines += Get-Content -LiteralPath $txtPath

$begin = -1
$end = -1
for ($i = 0; $i -lt $allLines.Count; $i += 1) {
    if ($allLines[$i] -like "FRIEND_EXPORT_BEGIN,*") { $begin = $i; $end = -1 }
    elseif ($begin -ge 0 -and $allLines[$i] -eq "FRIEND_EXPORT_END") { $end = $i }
}
if ($begin -lt 0 -or $end -le $begin) {
    throw "No complete Friend export was found. Open Friend, press Select, and reconnect."
}

$block = $allLines[$begin..$end]
$exportMarker = $block[0] -split ","
$schemaVersion = if ($exportMarker.Count -ge 2) { $exportMarker[1] } else { "unknown" }
$appVersion = if ($exportMarker.Count -ge 3) { $exportMarker[2] } else { "0.1.0-unlabelled" }
[pscustomobject]@{
    app_version = $appVersion
    schema_version = $schemaVersion
    retrieved_at = (Get-Date).ToString("o")
    device = $DeviceName
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outDir "export-metadata.json")

function Read-FriendSection([string]$Name) {
    $sectionBegin = -1
    $sectionEnd = -1
    for ($i = 0; $i -lt $block.Count; $i += 1) {
        if ($block[$i] -like "FRIEND_${Name}_BEGIN,*") { $sectionBegin = $i }
        elseif ($block[$i] -eq "FRIEND_${Name}_END") { $sectionEnd = $i }
    }
    if ($sectionBegin -ge 0 -and $sectionEnd -gt ($sectionBegin + 1)) {
        return @($block[($sectionBegin + 1)..($sectionEnd - 1)] | ConvertFrom-Csv)
    }
    return @()
}

$snapshots = @(Read-FriendSection "snap")
$sessions = @(Read-FriendSection "session3")
if ($sessions.Count -eq 0) { $sessions = @(Read-FriendSection "session") }
$chapters = @(Read-FriendSection "chapter3")
$live = @(Read-FriendSection "live3")
if ($live.Count -eq 0) { $live = @(Read-FriendSection "live") }
$snapshots | Export-Csv (Join-Path $outDir "snapshots.csv") -NoTypeInformation
$sessions | Export-Csv (Join-Path $outDir "sessions.csv") -NoTypeInformation
$chapters | Export-Csv (Join-Path $outDir "chapters.csv") -NoTypeInformation
$live | Export-Csv (Join-Path $outDir "live.csv") -NoTypeInformation

Write-Host "[copied] $outDir"
Write-Host "[export] Friend v$appVersion schema=$schemaVersion"
Write-Host "[records] snapshots=$($snapshots.Count) sessions=$($sessions.Count) chapters=$($chapters.Count) live=$($live.Count)"
if ($snapshots.Count -gt 0) {
    Write-Host "`nLatest check-in"
    $snapshots[-1] | Format-List
}
if ($sessions.Count -gt 0) {
    Write-Host "`nRecent sessions"
    $sessions | Select-Object -Last 8 start_epoch,duration_s,hr4h_avg,hr_avg,hr_max,
        motion_avg,motion_peak,moving_pct,steps_start,steps_end | Format-Table -AutoSize
}
if ($chapters.Count -gt 0) {
    Write-Host "`nRecent effort chapters"
    $chapters | Select-Object -Last 12 start_epoch,duration_s,partial,baseline_hr,
        hr_avg,hr_max,hr_delta_peak,motion_avg,moving_pct,steps_start,steps_end,reason |
        Format-Table -AutoSize
}
