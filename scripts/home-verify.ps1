# One command for everything only the home PC (SDK, simulator) can check.
# Writes a dated report under common/home-verify/ that a machine with no
# Garmin tooling can read: what compiled, every warning, PRG sizes, the
# offline tests, and the ink face in the simulator beside compose_preview.py.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\home-verify.ps1
#       [-NoPull] [-SkipSim] [-SkipTests]
#
# It never commits. Review the report, then commit it like any other change.
#
# Processes: the simulator is started if it is not running and left open
# (stop it with: taskkill /IM simulator.exe). The monkeydo push it starts is
# recorded in bin\home-verify\monkeydo.pid and killed after the screenshot;
# a leftover one from an interrupted run is killed at the next start.

param(
    [switch]$NoPull,
    [switch]$SkipSim,
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
$work = Join-Path $repo "bin\home-verify"
$reportDir = Join-Path $repo "common\home-verify"
$report = Join-Path $reportDir "$($stamp)_home-verify.md"
$sheetName = "$($stamp)_ink-sim-vs-preview.png"
New-Item -ItemType Directory -Force -Path $work, $reportDir | Out-Null
if (Test-Path -LiteralPath $report) { throw "$report already exists; wait a minute and rerun." }

$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
$sdk = Get-ChildItem -Path $sdkRoot -Directory -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $sdk) { throw "No Connect IQ SDK under $sdkRoot." }
$monkeyc = Join-Path $sdk.FullName "bin\monkeyc.bat"
$key = if ($env:MONKEYC_DEVELOPER_KEY) { $env:MONKEYC_DEVELOPER_KEY } else { Join-Path $env:USERPROFILE "MonkeyC\developer_key" }
if (-not (Test-Path -LiteralPath $key)) { throw "Developer key not found; set MONKEYC_DEVELOPER_KEY." }
$devicesDir = Join-Path $env:APPDATA "Garmin\ConnectIQ\Devices"

# Everything that reaches the report goes through here: no local paths.
function Clean([string]$s) {
    $s = $s.Replace($repo + "\", "").Replace($repo, "<repo>")
    $s = $s.Replace($sdk.FullName, "<sdk>").Replace($env:USERPROFILE, "~")
    return ($s -replace '[A-Za-z]:\\Users\\[^\\\s]+', '~')
}

# Native tools write to stderr; under "Stop", PowerShell 5.1 turns the first
# stderr line into a terminating error. Run them with the default here and
# read $LASTEXITCODE afterwards.
function Invoke-Native([scriptblock]$Block) {
    $ErrorActionPreference = "Continue"
    & $Block 2>&1 | ForEach-Object { "$_" }
}

$lines = New-Object System.Collections.Generic.List[string]
function Add([string]$s = "") { $lines.Add($s) }
$failed = 0

# ---- git -------------------------------------------------------------------
if (-not $NoPull) {
    Invoke-Native { git -C $repo pull --ff-only } | Out-Null
    $pullNote = if ($LASTEXITCODE -eq 0) { "pulled (fast-forward only)" } else { "pull refused, verified the local tree as it is" }
} else {
    $pullNote = "not pulled (-NoPull)"
}
$head = git -C $repo log -1 --format="%h %s"
$dirty = @(git -C $repo status --porcelain | Where-Object { $_ -notmatch '^\?\? common/home-verify/' })

Add "# Home verify $stamp"
Add ""
Add "Written by ``scripts/home-verify.ps1`` on the PC with the Connect IQ SDK."
Add "Read [COMPILER_FACTS](../language/COMPILER_FACTS.md) for what earlier runs proved."
Add ""
Add "- Commit: ``$head`` ($pullNote)"
Add ("- Working tree: " + $(if ($dirty.Count) { "$($dirty.Count) uncommitted change(s): " + (($dirty | ForEach-Object { $_.Substring(3) }) -join ", ") } else { "clean" }))
Add "- SDK: ``$($sdk.Name)``"
Add ""

# ---- builds ------------------------------------------------------------------
# Every project with a manifest, for every product whose device files exist.
$projects = @(
    @{ Name = "japanese-ink-heartrate"; Dir = "watch-faces\japanese-ink-heartrate" },
    @{ Name = "friend (wrist-diary)"; Dir = "garmin-pet\probes\wrist-diary" },
    @{ Name = "pet-hardware-probe"; Dir = "garmin-pet\probes\hardware" }
)
Add "## Builds (``monkeyc -w -l 2``)"
Add ""
Add "| Project | Device | Result | Warnings | PRG bytes |"
Add "|---|---|---|---|---|"
$warnBlocks = New-Object System.Collections.Generic.List[string]
$inkPrg = $null
foreach ($p in $projects) {
    $dir = Join-Path $repo $p.Dir
    [xml]$manifest = Get-Content -LiteralPath (Join-Path $dir "manifest.xml")
    foreach ($dev in @($manifest.manifest.application.products.product.id)) {
        if (-not (Test-Path -LiteralPath (Join-Path $devicesDir $dev))) {
            Add "| $($p.Name) | $dev | skipped: device files not installed | | |"
            continue
        }
        $slug = ($p.Dir -split '\\')[-1]
        $prg = Join-Path $work "$slug-$dev.prg"
        Remove-Item -LiteralPath $prg -ErrorAction SilentlyContinue
        Write-Host "[build] $($p.Name) $dev"
        $out = Invoke-Native { & $monkeyc -o $prg -f (Join-Path $dir "monkey.jungle") -y $key -d $dev -w -l 2 }
        $ok = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $prg)
        $warn = @($out | Where-Object { $_ -match '^WARNING' } | ForEach-Object { Clean $_ } | Sort-Object -Unique)
        $err = @($out | Where-Object { $_ -match '^ERROR' } | ForEach-Object { Clean $_ })
        $size = if ($ok) { (Get-Item -LiteralPath $prg).Length } else { "" }
        Add "| $($p.Name) | $dev | $(if ($ok) { 'OK' } else { '**FAILED**' }) | $($warn.Count) | $size |"
        if (-not $ok) { $failed += 1 }
        if ($ok -and $slug -eq "japanese-ink-heartrate" -and $dev -eq "fr265") { $inkPrg = $prg }
        if ($err.Count -or $warn.Count) {
            $warnBlocks.Add("### $($p.Name) / $dev")
            $warnBlocks.Add("")
            $warnBlocks.Add('```')
            foreach ($l in $err + $warn) { $warnBlocks.Add($l) }
            $warnBlocks.Add('```')
            $warnBlocks.Add("")
        }
    }
}
Add ""

# ---- offline tests -------------------------------------------------------------
if (-not $SkipTests) {
    Add "## Offline tests"
    Add ""
    Add "| Test | Result | Last line |"
    Add "|---|---|---|"
    $tests = @(Get-ChildItem -Path (Join-Path $repo "scripts") -Filter "test-*.ps1" | ForEach-Object { @{ Name = $_.Name; Args = @("-File", $_.FullName) } })
    $tests += @{ Name = "watch-tools.ps1 test"; Args = @("-File", (Join-Path $repo "scripts\watch-tools.ps1"), "test") }
    foreach ($t in $tests) {
        Write-Host "[test] $($t.Name)"
        $out = Invoke-Native { & powershell.exe -NoProfile -ExecutionPolicy Bypass @($t.Args) }
        $code = $LASTEXITCODE
        $last = Clean ((@($out | Where-Object { $_.Trim() }) | Select-Object -Last 1) -replace '\|', '/')
        Add "| $($t.Name) | $(if ($code -eq 0) { 'pass' } else { "**FAIL ($code)**" }) | $last |"
        if ($code -ne 0) { $failed += 1 }
    }
    Add ""
}

# ---- simulator vs compose_preview.py ------------------------------------------
function Find-PillowPython {
    $candidates = @(
        @((Join-Path $repo ".venv\Scripts\python.exe")),
        @("py", "-3.13"), @("py", "-3.12"), @("py", "-3.11"), @("py", "-3.10"), @("python")
    )
    foreach ($c in $candidates) {
        try {
            $exe = $c[0]; $rest = @($c | Select-Object -Skip 1)
            Invoke-Native { & $exe @rest -c "import PIL" } | Out-Null
            if ($LASTEXITCODE -eq 0) { return , $c }
        } catch { }
    }
    return $null
}

if (-not $SkipSim) {
    Add "## Japanese Ink: simulator beside compose_preview.py"
    Add ""
    $py = Find-PillowPython
    if (-not $inkPrg) {
        Add "Skipped: the fr265 ink face did not build."
    } elseif (-not $py) {
        Add "Skipped: no Python with Pillow found (.venv, py -3.10..3.13, python)."
    } else {
        $pyExe = $py[0]; $pyArgs = @($py | Select-Object -Skip 1)

        $sim = Get-Process simulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0
        if (-not $sim) {
            Write-Host "[sim] starting the simulator"
            Start-Process (Join-Path $sdk.FullName "bin\connectiq.bat")
            for ($i = 0; $i -lt 60 -and -not $sim; $i += 1) {
                Start-Sleep -Seconds 1
                $sim = Get-Process simulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0
            }
        }

        $pidFile = Join-Path $work "monkeydo.pid"
        if (Test-Path -LiteralPath $pidFile) {
            $old = Get-Content -LiteralPath $pidFile
            if (Get-Process -Id $old -ErrorAction SilentlyContinue) { Invoke-Native { & taskkill.exe /PID $old /T /F } | Out-Null }
            Remove-Item -LiteralPath $pidFile
        }

        $simPng = Join-Path $work "$stamp-sim.png"
        $prevPng = Join-Path $work "$stamp-preview.png"
        Remove-Item -LiteralPath $simPng, $prevPng -ErrorAction SilentlyContinue
        $captured = $false
        if ($sim) {
            Write-Host "[sim] pushing the ink face"
            $md = Start-Process cmd.exe -ArgumentList "/c", "`"$(Join-Path $sdk.FullName 'bin\monkeydo.bat')`" `"$inkPrg`" fr265" -WindowStyle Hidden -PassThru
            Set-Content -LiteralPath $pidFile -Value $md.Id
            Start-Sleep -Seconds 10
            try {
                & (Join-Path $PSScriptRoot "save-sim-capture.ps1") -OutputPath $simPng | Out-Null
                $captured = Test-Path -LiteralPath $simPng
            } catch {
                Add "Capture failed: $(Clean $_.Exception.Message)"
            }
            Invoke-Native { & taskkill.exe /PID $md.Id /T /F } | Out-Null
            Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
        } else {
            Add "Skipped: the simulator window did not appear within 60 s."
        }

        if ($captured) {
            $when = Get-Date
            # The simulator feeds its own HR history (a level line near
            # 80 bpm as of 2026-10-30), so the preview gets a flat 80 window.
            $csv = Join-Path $work "flat80.csv"
            $end = 1800000000
            $rows = @("epoch,hr_avg,hr_max")
            for ($t = $end - 14400; $t -le $end; $t += 300) { $rows += "$t,80,80" }
            Set-Content -LiteralPath $csv -Value $rows -Encoding Ascii
            $night = ($when.Hour -ge 21) -or ($when.Hour -lt 6)
            $pvArgs = @((Join-Path $PSScriptRoot "compose_preview.py"), $prevPng, "--data", $csv, "--time", $when.ToString("HH:mm"))
            if ($night) { $pvArgs += "--night" }
            Invoke-Native { & $pyExe @pyArgs @pvArgs } | Out-Null
            $sheet = Join-Path $reportDir $sheetName
            $stats = Invoke-Native { & $pyExe @pyArgs (Join-Path $PSScriptRoot "sim_vs_preview.py") $simPng $prevPng $sheet } | Select-Object -Last 1
            Add "![simulator | preview | difference x4]($sheetName)"
            Add ""
            Add "- Left: the simulator at $($when.ToString('HH:mm')) after a fresh push. Middle: ``compose_preview.py --data <flat 80 bpm> --time $($when.ToString('HH:mm'))$(if ($night) { ' --night' })``. Right: the difference inside the circle, brightened 4x."
            Add "- $stats (inside the circle; a smoke number, the data is not identical)."
            Add "- The preview assumes the simulator's 12-hour clock and default night window (21-6)."
        } elseif (-not ($lines | Where-Object { $_ -like "Skipped*" -or $_ -like "Capture failed*" })) {
            Add "Capture produced no file."
        }
    }
    Add ""
}

# ---- warnings ------------------------------------------------------------------
Add "## Compiler output (errors first, then unique warnings)"
Add ""
if ($warnBlocks.Count) { foreach ($l in $warnBlocks) { Add $l } } else { Add "None."; Add "" }

$lines | Set-Content -LiteralPath $report -Encoding Ascii
Write-Host ""
Write-Host "[report] $(Clean $report)"
if (Test-Path -LiteralPath (Join-Path $reportDir $sheetName)) { Write-Host "[sheet]  $(Clean (Join-Path $reportDir $sheetName))" }
Write-Host "[next]   review it, then: git add common\home-verify & git commit"
if ($failed) { Write-Host "[!] $failed build(s)/test(s) failed"; exit 1 }
Write-Host "[OK] all builds and tests passed"
