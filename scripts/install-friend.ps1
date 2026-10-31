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
    $same = $existingSize -eq [uint64]$prgInfo.Length
    if ($same) {
        # Equal size is not equal content: two builds can match in size. Copy the
        # watch's PRG to the PC (read-only on the watch) and compare hashes.
        $compareDir = Join-Path ([System.IO.Path]::GetTempPath()) ("friend-prg-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $compareDir | Out-Null
        try {
            $shell.Namespace($compareDir).CopyHere($existing, 16)
            $watchCopy = Join-Path $compareDir $prgName
            for ($i = 0; $i -lt 80 -and -not (Test-Path -LiteralPath $watchCopy); $i += 1) {
                Start-Sleep -Milliseconds 250
            }
            if (-not (Test-Path -LiteralPath $watchCopy)) { throw "Could not copy $prgName off the watch to compare it." }
            $same = (Get-FileHash -LiteralPath $watchCopy).Hash -eq (Get-FileHash -LiteralPath $prg).Hash
        } finally {
            Remove-Item -LiteralPath $compareDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    if (-not $same) {
        throw "A different $prgName is already on the watch. Back it up and remove it explicitly before replacement."
    }
    Write-Host "[staged] $prgName on the watch is already this build (same SHA-256)."
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

# Garmin writes System.println output only to a log file that already exists,
# named after the basename the app was first sideloaded under. A watch that ran
# Wrist Diary keeps wrist-diary-fr265; a fresh install (any watch reset since,
# like the FR265 on 2026-10-26) uses friend-fr265, matching its DATA files.
# Create both so either identity logs. Only when missing: an existing one may
# hold an export not yet read.
$logs = $apps.GetFolder.Items() | Where-Object Name -eq "LOGS" | Select-Object -First 1
if (-not $logs) {
    Write-Warning "GARMIN/Apps/LOGS was not found; Friend's export will not be logged."
} else {
    foreach ($logName in @("friend-fr265.txt", "wrist-diary-fr265.txt")) {
        $logItem = $logs.GetFolder.Items() |
            Where-Object { $_.ExtendedProperty("System.FileName") -ieq $logName } |
            Select-Object -First 1
        if ($logItem) {
            Write-Host "[log] $logName already exists; left as is."
            continue
        }
        $tempLogDir = Join-Path ([System.IO.Path]::GetTempPath()) ("friend-log-" + [guid]::NewGuid())
        New-Item -ItemType Directory -Path $tempLogDir | Out-Null
        $tempLog = Join-Path $tempLogDir $logName
        [System.IO.File]::WriteAllText($tempLog, "")
        $logs.GetFolder.CopyHere($tempLog, 16)
        Start-Sleep -Seconds 2
        Remove-Item -LiteralPath $tempLogDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "[log] Created an empty $logName so Friend's export is kept."
    }
}

Write-Host "[installed] Friend v$friendVersion replaces the Wrist Diary app identity on $DeviceName."
Write-Host "[next] On the watch itself, use its button/control to leave USB mode."
Write-Host "[next] Let the watch finish syncing/updating the staged app before unplugging or opening Friend."
