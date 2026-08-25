param(
    [string]$DeviceName = "Forerunner 265",
    [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$prg = Join-Path $repo "bin\friend\friend-fr265.prg"
$viewSource = Join-Path $repo "garmin-pet\probes\wrist-diary\source\WristDiaryView.mc"
$versionMatch = Select-String -LiteralPath $viewSource -Pattern 'const APP_VERSION = "([0-9]+\.[0-9]+\.[0-9]+)";' | Select-Object -First 1
if (-not $versionMatch) { throw "Could not read Friend APP_VERSION from $viewSource" }
$friendVersion = $versionMatch.Matches[0].Groups[1].Value

if (-not $SkipBuild) { & (Join-Path $PSScriptRoot "build-friend.ps1") }
if (-not (Test-Path -LiteralPath $prg)) { throw "Friend build was not found at $prg" }

$shell = New-Object -ComObject Shell.Application
$thisPc = $shell.Namespace(17)
$device = $thisPc.Items() | Where-Object Name -eq $DeviceName | Select-Object -First 1
if (-not $device) { throw "$DeviceName is not connected." }
$storage = $device.GetFolder.Items() | Where-Object Name -eq "Internal Storage" | Select-Object -First 1
$garmin = $storage.GetFolder.Items() | Where-Object Name -eq "GARMIN" | Select-Object -First 1
$apps = $garmin.GetFolder.Items() | Where-Object Name -eq "Apps" | Select-Object -First 1
$logs = $apps.GetFolder.Items() | Where-Object Name -eq "LOGS" | Select-Object -First 1
if (-not $apps -or -not $logs) { throw "GARMIN/Apps or GARMIN/Apps/LOGS was not found." }

# Friend deliberately keeps Wrist Diary's UUID, and Garmin consequently keeps
# routing System.println output to the original sideload basename.
$tempLog = Join-Path ([System.IO.Path]::GetTempPath()) "wrist-diary-fr265.txt"
[System.IO.File]::WriteAllText($tempLog, "")
$apps.GetFolder.CopyHere($prg, 16)
$logs.GetFolder.CopyHere($tempLog, 16)

Start-Sleep -Seconds 5
Write-Host "[installed] Friend v$friendVersion replaces the Wrist Diary app identity on $DeviceName."
Write-Host "[next] On the watch itself, use its button/control to leave USB mode."
Write-Host "[next] Let the watch finish syncing/updating the staged app before unplugging or opening Friend."
