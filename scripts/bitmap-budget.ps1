# How many baked bitmaps can the ink face carry? One command on the home PC.
#
#   powershell -NoProfile -ExecutionPolicy Bypass -File scripts\bitmap-budget.ps1
#       [-Counts "0,50,100,200,400"] [-NoPull] [-SimSeconds 300]
#
# For each count it generates that many real-sized planes (copies of the ink
# face's baked *_cut.png, each made unique: scripts/gen_budget_bitmaps.py),
# builds watch-faces/bitmap-budget-probe for the fr265, notes whether
# monkeyc accepts it and the PRG size, then runs it in the simulator and
# reads the probe's log lines: every bitmap loaded and dropped (the install
# budget), then as many as possible HELD at once (the graphics-pool budget).
# It stops climbing at the first count that fails to build or load.
# Writes common/home-verify/<stamp>_bitmap-budget.md; never commits.
#
# The simulator is not the watch. For the watch's own answer:
#   ... bitmap-budget.ps1 -Watch [-WatchCount N]
#       copies the biggest count that passed in the simulator (or N) to the
#       plugged-in watch as bitmap-budget-fr265.prg with an empty log file.
#       Unplug, pick "Bitmap Budget" as the watch face, wait for DONE, plug
#       back in, then:
#   ... bitmap-budget.ps1 -ReadWatch
#       copies the log off the watch and writes the watch's report.
#   Afterwards pick the ink face again; the probe can be deleted from
#   GARMIN/Apps (bitmap-budget-fr265.prg) in Explorer while plugged in.

param(
    [string]$Counts = "0,50,100,200,400",
    [int]$SimSeconds = 300,
    [switch]$NoPull,
    [switch]$Watch,
    [int]$WatchCount = 0,
    [switch]$ReadWatch,
    [string]$DeviceName = "Forerunner 265"
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$probeDir = Join-Path $repo "watch-faces\bitmap-budget-probe"
$work = Join-Path $repo "bin\bitmap-budget"
$reportDir = Join-Path $repo "common\home-verify"
$stamp = Get-Date -Format "yyyy-MM-dd_HHmm"
New-Item -ItemType Directory -Force -Path $work, $reportDir | Out-Null
$prgName = "bitmap-budget-fr265.prg"
$logName = "bitmap-budget-fr265.txt"

function Invoke-Native([scriptblock]$Block) {
    $ErrorActionPreference = "Continue"
    & $Block 2>&1 | ForEach-Object { "$_" }
}

function Clean([string]$s) {
    $s = $s.Replace($repo + "\", "").Replace($repo, "<repo>").Replace($env:USERPROFILE, "~")
    return ($s -replace '[A-Za-z]:\\Users\\[^\\\s]+', '~')
}

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

# The probe's log lines -> one summary object.
function Read-BudgetLog([string[]]$lines) {
    $r = [ordered]@{ Start = $null; Done = $null; Loads = 0; LoadFails = @(); Holds = 0; HoldFail = $null; HoldHeap = @() }
    foreach ($l in $lines) {
        $f = $l.Trim() -split ','
        switch ($f[0]) {
            "BUDGET_START" { $r.Start = $f }
            "BUDGET_LOAD" { $r.Loads += 1; if ($f[2] -eq "0") { $r.LoadFails += , $l.Trim() } }
            "BUDGET_HOLD" {
                if ($f[3] -eq "1") { $r.Holds = [int]$f[1]; $r.HoldHeap += , [int]$f[2] } else { $r.HoldFail = $l.Trim() }
            }
            "BUDGET_DONE" { $r.Done = $f }
        }
    }
    return $r
}

function Get-Watch {
    $shell = New-Object -ComObject Shell.Application
    $device = $shell.Namespace(17).Items() | Where-Object Name -eq $DeviceName | Select-Object -First 1
    if (-not $device) { throw "$DeviceName is not connected." }
    $storage = $device.GetFolder.Items() | Where-Object Name -eq "Internal Storage" | Select-Object -First 1
    $garmin = $storage.GetFolder.Items() | Where-Object Name -eq "GARMIN" | Select-Object -First 1
    $apps = $garmin.GetFolder.Items() | Where-Object Name -eq "Apps" | Select-Object -First 1
    if (-not $apps) { throw "GARMIN/Apps was not found." }
    $logs = $apps.GetFolder.Items() | Where-Object Name -eq "LOGS" | Select-Object -First 1
    return @{ Shell = $shell; Apps = $apps; Logs = $logs }
}

function Find-Item($folder, [string]$name) {
    return $folder.GetFolder.Items() |
        Where-Object { $_.ExtendedProperty("System.FileName") -ieq $name } | Select-Object -First 1
}

$statePath = Join-Path $work "last-run.json"

# ---- read the watch's log ------------------------------------------------------
if ($ReadWatch) {
    $w = Get-Watch
    if (-not $w.Logs) { throw "GARMIN/Apps/LOGS was not found." }
    $item = Find-Item $w.Logs $logName
    if (-not $item) { throw "$logName is not on the watch; run -Watch first." }
    $dest = Join-Path $work "watch-log"
    Remove-Item -LiteralPath $dest -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $dest | Out-Null
    $w.Shell.Namespace($dest).CopyHere($item, 16)
    $copy = Join-Path $dest $logName
    for ($i = 0; $i -lt 80 -and -not (Test-Path -LiteralPath $copy); $i += 1) { Start-Sleep -Milliseconds 250 }
    if (-not (Test-Path -LiteralPath $copy)) { throw "Could not copy $logName off the watch." }
    # Garmin rotates an app log at about 5 KB into .BAK, so a 200-plane run
    # spans both files: read the .BAK first. The watch restarts a face (an
    # activity, a face switch) and the probe starts over, so only the lines
    # from the last BUDGET_START describe one whole run.
    $bakName = [System.IO.Path]::ChangeExtension($logName, ".bak")
    $bakItem = Find-Item $w.Logs $bakName
    $all = @()
    if ($bakItem) {
        $w.Shell.Namespace($dest).CopyHere($bakItem, 16)
        $bakCopy = Join-Path $dest $bakName
        for ($i = 0; $i -lt 80 -and -not (Test-Path -LiteralPath $bakCopy); $i += 1) { Start-Sleep -Milliseconds 250 }
        if (Test-Path -LiteralPath $bakCopy) { $all += @(Get-Content -LiteralPath $bakCopy) }
    }
    $all += @(Get-Content -LiteralPath $copy)
    $starts = @(for ($i = 0; $i -lt $all.Count; $i += 1) { if ($all[$i] -like "BUDGET_START,*") { $i } })
    $runLines = if ($starts.Count) { $all[$starts[-1]..($all.Count - 1)] } else { $all }
    $r = Read-BudgetLog $runLines
    $count = if (Test-Path -LiteralPath $statePath) { (Get-Content -LiteralPath $statePath | ConvertFrom-Json).WatchCount } else { "?" }
    $report = Join-Path $reportDir "$($stamp)_bitmap-budget-watch.md"
    $out = New-Object System.Collections.Generic.List[string]
    $out.Add("# Bitmap budget on the watch $stamp")
    $out.Add("")
    $out.Add("Written by ``scripts/bitmap-budget.ps1 -ReadWatch``. The probe ran on the FR265 itself with $count generated planes (copies of the ink face's baked cutouts).")
    $out.Add("")
    if (-not $r.Start) {
        $out.Add("**The log is empty.** The probe never ran as a watch face, or the watch did not write the log (it only writes to a log file that existed before the app started). Pick Bitmap Budget as the face, wait for DONE, and read again.")
    } else {
        $out.Add("- Heap at start: $($r.Start[3]) of $($r.Start[2]) bytes")
        if ($starts.Count -gt 1) { $out.Add("- The probe started $($starts.Count) times (the watch restarted the face); the last run is reported") }
        $ms = @($runLines | Where-Object { $_ -like "BUDGET_LOAD,*,1,*" } | ForEach-Object { [int](($_ -split ',')[3]) } | Sort-Object)
        if ($ms.Count) { $out.Add("- Load time per plane: fastest $($ms[0]) ms, median $($ms[[int]($ms.Count / 2)]) ms, slowest $($ms[-1]) ms") }
        if ($r.HoldHeap.Count -ge 2) { $out.Add("- App heap per held plane: $([int](($r.HoldHeap[-1] - $r.HoldHeap[0]) / ($r.HoldHeap.Count - 1))) bytes (the pixels live in the graphics pool, not the app heap)") }
        if ($r.Done) {
            $out.Add("- Sweep (load, draw, drop each): **$($r.Done[2]) of $($r.Done[1]) loaded**, $($r.Done[3]) failed; slowest $($r.Done[4]) ms, total $($r.Done[5]) ms")
            $out.Add("- Held at once: **$($r.Done[6])**$(if ($r.HoldFail) { " (the next one failed: ``$($r.HoldFail)``)" } else { ' (the probe stops at 48)' })")
        } else {
            $out.Add("- **No BUDGET_DONE line**: the probe stopped partway ($($r.Loads) loads logged, $($r.Holds) held). The watch may have killed it; the last lines are below.")
        }
        foreach ($f in ($r.LoadFails | Select-Object -First 10)) { $out.Add("- Failed load: ``$f``") }
        $out.Add("")
        $out.Add("Last log lines:")
        $out.Add("")
        $out.Add('```')
        foreach ($l in (Get-Content -LiteralPath $copy | Select-Object -Last 8)) { $out.Add($l) }
        $out.Add('```')
    }
    $out | Set-Content -LiteralPath $report -Encoding Ascii
    Write-Host "[report] $(Clean $report)"
    Write-Host "[next]   pick the ink face again on the watch; review the report, then: git add common\home-verify & git commit"
    exit 0
}

# ---- copy one build to the watch ------------------------------------------------
if ($Watch) {
    $state = if (Test-Path -LiteralPath $statePath) { Get-Content -LiteralPath $statePath | ConvertFrom-Json } else { $null }
    $count = if ($WatchCount -gt 0) { $WatchCount } elseif ($state) { [int]$state.BestCount } else { 0 }
    if ($count -le 0) { throw "No passing simulator count recorded; run without -Watch first, or pass -WatchCount N." }
    $prg = Join-Path $work "budget-$count.prg"
    if (-not (Test-Path -LiteralPath $prg)) { throw "$(Clean $prg) is missing; rerun the simulator pass with -Counts $count." }
    $w = Get-Watch
    if (Find-Item $w.Apps $prgName) { throw "$prgName is already on the watch. Delete it in Explorer (GARMIN/Apps) first, then rerun." }
    $stage = Join-Path $work "stage"
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $stage | Out-Null
    Copy-Item -LiteralPath $prg -Destination (Join-Path $stage $prgName)
    $len = (Get-Item -LiteralPath (Join-Path $stage $prgName)).Length
    Write-Host "[copy] $prgName ($len bytes, $count planes) to the watch; large builds take a while"
    $w.Apps.GetFolder.CopyHere((Join-Path $stage $prgName), 16)
    $copied = $null
    for ($i = 0; $i -lt 2400; $i += 1) {
        Start-Sleep -Milliseconds 250
        $copied = Find-Item $w.Apps $prgName
        if ($copied -and [uint64]$copied.ExtendedProperty("System.Size") -eq [uint64]$len) { break }
    }
    if (-not $copied -or [uint64]$copied.ExtendedProperty("System.Size") -ne [uint64]$len) { throw "$prgName did not arrive whole on the watch." }
    if ($w.Logs -and -not (Find-Item $w.Logs $logName)) {
        $tmp = Join-Path $stage $logName
        [System.IO.File]::WriteAllText($tmp, "")
        $w.Logs.GetFolder.CopyHere($tmp, 16)
        Start-Sleep -Seconds 2
    }
    $o = if ($state) { $state } else { [pscustomobject]@{ BestCount = $count } }
    $o | Add-Member -NotePropertyName WatchCount -NotePropertyValue $count -Force
    $o | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding Ascii
    Write-Host "[staged] $prgName with an empty $logName."
    Write-Host "[next]   leave USB mode, let the watch finish installing, pick 'Bitmap Budget' as the watch face,"
    Write-Host "         wait for DONE on the screen, plug back in and run: scripts\bitmap-budget.ps1 -ReadWatch"
    exit 0
}

# ---- the simulator pass ----------------------------------------------------------
if (-not $NoPull) { Invoke-Native { git -C $repo pull --ff-only } | Out-Null }
$head = git -C $repo log -1 --format="%h %s"
$sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
$sdk = Get-ChildItem -Path $sdkRoot -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $sdk) { throw "No Connect IQ SDK under $sdkRoot." }
$monkeyc = Join-Path $sdk.FullName "bin\monkeyc.bat"
$monkeydo = Join-Path $sdk.FullName "bin\monkeydo.bat"
$key = if ($env:MONKEYC_DEVELOPER_KEY) { $env:MONKEYC_DEVELOPER_KEY } else { Join-Path $env:USERPROFILE "MonkeyC\developer_key" }
if (-not (Test-Path -LiteralPath $key)) { throw "Developer key not found; set MONKEYC_DEVELOPER_KEY." }
$py = Find-PillowPython
if (-not $py) { throw "No Python with Pillow found (.venv, py -3.10..3.13, python)." }
$pyExe = $py[0]; $pyArgs = @($py | Select-Object -Skip 1)

# what the device file declares (memory limits and the like), for context
$compilerJson = Join-Path $env:APPDATA "Garmin\ConnectIQ\Devices\fr265\compiler.json"
$limits = New-Object System.Collections.Generic.List[string]
function Walk($node, [string]$path) {
    if ($node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $node.PSObject.Properties) { Walk $p.Value ($(if ($path) { "$path.$($p.Name)" } else { $p.Name })) }
    } elseif ($node -is [System.Array]) {
        for ($i = 0; $i -lt $node.Count; $i += 1) { Walk $node[$i] "$path[$i]" }
    } elseif ($path -match '(?i)memory|size|limit|bitmap|pool|resource') {
        $limits.Add("$path = $node")
    }
}
if (Test-Path -LiteralPath $compilerJson) { Walk (Get-Content -LiteralPath $compilerJson -Raw | ConvertFrom-Json) "" }

# the simulator, started if needed (left open, as home-verify leaves it)
$sim = Get-Process simulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0
if (-not $sim) {
    Write-Host "[sim] starting the simulator"
    Start-Process (Join-Path $sdk.FullName "bin\connectiq.bat")
    for ($i = 0; $i -lt 60 -and -not $sim; $i += 1) {
        Start-Sleep -Seconds 1
        $sim = Get-Process simulator -ErrorAction SilentlyContinue | Where-Object MainWindowHandle -ne 0
    }
}

$rows = New-Object System.Collections.Generic.List[string]
$notes = New-Object System.Collections.Generic.List[string]
$best = 0
$bestPng = 0
foreach ($n in @($Counts -split ',' | ForEach-Object { [int]$_.Trim() })) {
    Write-Host "[gen] $n planes"
    $gen = Invoke-Native { & $pyExe @pyArgs (Join-Path $PSScriptRoot "gen_budget_bitmaps.py") $n } | Select-Object -Last 1
    $pngBytes = if ($gen -match '(\d+) PNG bytes') { [int64]$Matches[1] } else { 0 }
    $prg = Join-Path $work "budget-$n.prg"
    Remove-Item -LiteralPath $prg -ErrorAction SilentlyContinue
    Write-Host "[build] $n planes"
    $t0 = Get-Date
    $out = Invoke-Native { & $monkeyc -o $prg -f (Join-Path $probeDir "monkey.jungle") -y $key -d fr265 -w -l 2 }
    $buildS = [int]((Get-Date) - $t0).TotalSeconds
    $built = ($LASTEXITCODE -eq 0) -and (Test-Path -LiteralPath $prg)
    if (-not $built) {
        $rows.Add("| $n | $pngBytes | **build FAILED** ($buildS s) | | | | |")
        $errs = @($out | Where-Object { $_ -match '^ERROR' } | ForEach-Object { Clean $_ } | Select-Object -First 8)
        if (-not $errs.Count) { $errs = @($out | Select-Object -Last 6 | ForEach-Object { Clean $_ }) }
        $notes.Add("### Build output at $n planes"); $notes.Add(""); $notes.Add('```')
        foreach ($e in $errs) { $notes.Add($e) }
        $notes.Add('```'); $notes.Add("")
        break
    }
    $prgBytes = (Get-Item -LiteralPath $prg).Length
    if (-not $sim) {
        $rows.Add("| $n | $pngBytes | OK ($buildS s) | $prgBytes | no simulator | | |")
        continue
    }
    Write-Host "[sim] running $n planes (up to $SimSeconds s)"
    $log = Join-Path $work "budget-$n.log"
    Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
    $md = Start-Process cmd.exe -ArgumentList "/c", "`"`"$monkeydo`" `"$prg`" fr265 > `"$log`" 2>&1`"" -WindowStyle Hidden -PassThru
    $deadline = (Get-Date).AddSeconds($SimSeconds)
    $lines = @()
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds 2
        if (Test-Path -LiteralPath $log) {
            $lines = @(Get-Content -LiteralPath $log -ErrorAction SilentlyContinue)
            if ($lines | Where-Object { $_ -match '^BUDGET_DONE' }) { break }
            if ($md.HasExited) { break }
        }
    }
    Invoke-Native { & taskkill.exe /PID $md.Id /T /F } | Out-Null
    $r = Read-BudgetLog $lines
    if ($r.Done) {
        $loaded = [int]$r.Done[2]; $failedN = [int]$r.Done[3]
        $heapDelta = if ($r.HoldHeap.Count -ge 2) { [int](($r.HoldHeap[-1] - $r.HoldHeap[0]) / ($r.HoldHeap.Count - 1)) } else { "" }
        $rows.Add("| $n | $pngBytes | OK ($buildS s) | $prgBytes | $loaded/$n loaded, slowest $($r.Done[4]) ms | $($r.Done[6])$(if ($r.HoldFail) { ' (then failed)' }) | $heapDelta |")
        foreach ($f in ($r.LoadFails | Select-Object -First 5)) { $notes.Add("- $n planes, failed load: ``$f``") }
        if ($r.HoldFail) { $notes.Add("- $n planes, hold stopped: ``$($r.HoldFail)``") }
        if ($failedN -eq 0) { $best = $n; $bestPng = $pngBytes } else { break }
    } else {
        $tail = @($lines | Select-Object -Last 6 | ForEach-Object { Clean $_ })
        $rows.Add("| $n | $pngBytes | OK ($buildS s) | $prgBytes | **no result** ($($r.Loads) loads logged) | $($r.Holds) | |")
        $notes.Add("### Simulator output at $n planes (no BUDGET_DONE within $SimSeconds s)"); $notes.Add(""); $notes.Add('```')
        foreach ($l in $tail) { $notes.Add($l) }
        $notes.Add('```'); $notes.Add("")
        break
    }
}

[pscustomobject]@{ BestCount = $best } | ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding Ascii

# the ink face as committed, for scale
$inkPlanes = @(Get-ChildItem -Path (Join-Path $repo "watch-faces\japanese-ink-heartrate\resources\drawables") -Filter *.png)
$inkCut = @($inkPlanes | Where-Object Name -like "*_cut*")
$avg = if ($inkCut.Count) { [int](($inkCut | Measure-Object Length -Sum).Sum / $inkCut.Count) } else { 0 }

$report = Join-Path $reportDir "$($stamp)_bitmap-budget.md"
$o = New-Object System.Collections.Generic.List[string]
$o.Add("# Bitmap budget $stamp (simulator)")
$o.Add("")
$o.Add("Written by ``scripts/bitmap-budget.ps1``. Commit: ``$head``. SDK: ``$($sdk.Name)``.")
$o.Add("")
$o.Add("Each count is that many generated planes, copies of the ink face's baked cutouts (average $avg bytes as PNG), in a throwaway fr265 watch face. **Loaded** = each one loaded, drawn and dropped, as the face does with its masses. **Held** = how many stayed loaded at once before one failed (the probe stops at 48). **Heap/held** = app heap bytes per held bitmap.")
$o.Add("")
$o.Add("| Planes | PNG bytes | Build | PRG bytes | Loaded (sweep) | Held | Heap/held |")
$o.Add("|---|---|---|---|---|---|---|")
foreach ($r in $rows) { $o.Add($r) }
$o.Add("")
if ($best -gt 0) {
    $o.Add("**Answer (simulator): at least $best planes, about $([int]($bestPng / 1024)) KB of PNG, built and loaded without a failure.** The ink face ships $($inkCut.Count) cutouts plus its fixed planes today. The watch's own answer: ``bitmap-budget.ps1 -Watch``, then ``-ReadWatch``.")
} else {
    $o.Add("**No count above zero passed.** See the notes below.")
}
$o.Add("")
if ($notes.Count) { $o.Add("## Notes"); $o.Add(""); foreach ($l in $notes) { $o.Add($l) }; $o.Add("") }
$o.Add("## fr265 compiler.json fields (memory, size, limit, bitmap, pool, resource)")
$o.Add("")
if ($limits.Count) { $o.Add('```'); foreach ($l in $limits) { $o.Add($l) }; $o.Add('```') } else { $o.Add("None found (or no compiler.json).") }
$o | Set-Content -LiteralPath $report -Encoding Ascii
Write-Host ""
Write-Host "[report] $(Clean $report)"
Write-Host "[next]   review it, then: git add common\home-verify & git commit"
if ($best -gt 0) { Write-Host "[watch]  for the watch's own answer: scripts\bitmap-budget.ps1 -Watch" }
