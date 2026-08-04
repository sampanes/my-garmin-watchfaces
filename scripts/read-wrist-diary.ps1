param(
    [string]$DeviceName = "Forerunner 265"
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outDir = Join-Path $repo "bin\wrist-diary\downloads\$stamp"
$download = Join-Path $outDir "wrist-diary-fr265.txt"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$shell = New-Object -ComObject Shell.Application
$thisPc = $shell.Namespace(17)
$device = $thisPc.Items() |
    Where-Object Name -eq $DeviceName |
    Select-Object -First 1
if (-not $device) { throw "$DeviceName is not connected." }

$storage = $device.GetFolder.Items() |
    Where-Object Name -eq "Internal Storage" |
    Select-Object -First 1
$garmin = $storage.GetFolder.Items() |
    Where-Object Name -eq "GARMIN" |
    Select-Object -First 1
$apps = $garmin.GetFolder.Items() |
    Where-Object Name -eq "Apps" |
    Select-Object -First 1
$logs = $apps.GetFolder.Items() |
    Where-Object Name -eq "LOGS" |
    Select-Object -First 1
if (-not $logs) { throw "GARMIN/Apps/LOGS was not found." }

$logItem = $logs.GetFolder.Items() |
    Where-Object { $_.ExtendedProperty("System.FileName") -ieq "wrist-diary-fr265.txt" } |
    Select-Object -First 1
if (-not $logItem) { throw "The Wrist Diary log was not found on the watch." }

$destination = $shell.Namespace($outDir)
$destination.CopyHere($logItem, 16)
for ($i = 0; $i -lt 20 -and -not (Test-Path -LiteralPath $download); $i += 1) {
    Start-Sleep -Milliseconds 500
}
if (-not (Test-Path -LiteralPath $download)) {
    throw "The watch log did not finish copying to $download."
}

$lines = Get-Content -LiteralPath $download
$begin = -1
$end = -1
for ($i = 0; $i -lt $lines.Count; $i += 1) {
    if ($lines[$i] -like "WRIST_DIARY_BEGIN,*") {
        $begin = $i
        $end = -1
    } elseif ($begin -ge 0 -and $lines[$i] -eq "WRIST_DIARY_END") {
        $end = $i
    }
}

Write-Host "[copied] $download"
if ($begin -lt 0 -or $end -le ($begin + 2)) {
    Write-Host "[empty] Launch Wrist Diary on the watch once, then run this command again."
    exit 0
}

$csv = $lines[($begin + 1)..($end - 1)] | ConvertFrom-Csv
$csv | Select-Object epoch,steps,calories,moderate,vigorous,stress,
    hr_latest,hr_min,hr_avg,hr_max,body_battery,distance_cm,floors |
    Format-Table -AutoSize
