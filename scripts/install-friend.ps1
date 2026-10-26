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
if (-not $apps) { throw "GARMIN/Apps was not found." }

$prgInfo = Get-Item -LiteralPath $prg
$prgName = $prgInfo.Name
$existing = $apps.GetFolder.Items() |
    Where-Object { $_.ExtendedProperty("System.FileName") -ieq $prgName } |
    Select-Object -First 1
if ($existing) {
    $existingSize = [uint64]$existing.ExtendedProperty("System.Size")
    if ($existingSize -ne [uint64]$prgInfo.Length) {
        throw "$prgName already exists on the watch with a different size. Back it up and remove it explicitly before replacement."
    }
    Write-Host "[staged] $prgName was already present with the expected size."
} else {
    $apps.GetFolder.CopyHere($prg, 16)
    $copied = $null
    for ($i = 0; $i -lt 80; $i += 1) {
        Start-Sleep -Milliseconds 250
        $copied = $apps.GetFolder.Items() |
            Where-Object { $_.ExtendedProperty("System.FileName") -ieq $prgName } |
            Select-Object -First 1
        if ($copied -and [uint64]$copied.ExtendedProperty("System.Size") -eq [uint64]$prgInfo.Length) {
            break
        }
    }
    if (-not $copied) { throw "$prgName did not appear in GARMIN/Apps after the copy." }
    $copiedSize = [uint64]$copied.ExtendedProperty("System.Size")
    if ($copiedSize -ne [uint64]$prgInfo.Length) {
        throw "$prgName was copied with the wrong size (expected $($prgInfo.Length), got $copiedSize)."
    }
    Write-Host "[verified] $prgName staged at $copiedSize bytes."
}

Write-Host "[installed] Friend v$friendVersion replaces the Wrist Diary app identity on $DeviceName."
Write-Host "[next] On the watch itself, use its button/control to leave USB mode."
Write-Host "[next] Let the watch finish syncing/updating the staged app before unplugging or opening Friend."
