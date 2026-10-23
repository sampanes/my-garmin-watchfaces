$ErrorActionPreference = "Stop"

# Property tests for the PROPOSED pet economy (garmin-pet/12-pet-state-and-economy.md).
# Host-side only: these guard the behavior contract before any Monkey C exists.
. (Join-Path $PSScriptRoot "pet-model.ps1")

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function New-Chapter([long]$End, [int]$Minutes, [int]$HrDelta = 15, [int]$Partial = 0) {
    $baseline = 70
    $avg = $baseline + $HrDelta
    if ($HrDelta -lt 0) { $baseline = -1; $avg = -1 }
    return [pscustomobject]@{
        start_epoch = $End - $Minutes * 60
        end_epoch   = $End
        duration_s  = $Minutes * 60
        partial     = $Partial
        baseline_hr = $baseline
        hr_avg      = $avg
        reason      = 3
    }
}

$day = 86400
$hour = 3600
$born = 1793606400          # an arbitrary epoch; tests use a zero UTC offset
$noon = $born + 12 * $hour

# --- Mood never leaves [floor, max], for any start mood, warmth and gap.
foreach ($startMood in @(0, 20, 35, 60, 100, 150)) {
    foreach ($warm in @(0, 20, 60, 100)) {
        foreach ($gap in @(0, $hour, $day, (2 * $day), (3 * $day), (30 * $day), (90 * $day), (400 * $day))) {
            $s = New-PetState $born 0
            $s.mood = $startMood
            $s.warm = $warm
            $s.lastActiveDay = Get-PetDay $born 0
            $m = Get-PetMood $s ($born + $gap)
            Assert-True ($m.Mood -ge $PetConfig.MoodFloor) "Mood fell below floor (start=$startMood warm=$warm gap=$gap mood=$($m.Mood))"
            Assert-True ($m.Mood -le $PetConfig.MoodMax) "Mood exceeded max (start=$startMood gap=$gap)"
        }
    }
}

# --- No death after a 90-day gap: progress is intact and effort still pays.
$s = New-PetState $born 0
$s.xp = 2500
$s.evos = 1
$s.tsEvo = $born + 20 * $day
$s.lastActiveDay = Get-PetDay ($born + 30 * $day) 0
$s.tsOpen = $born + 30 * $day
$s.tsSettle = $s.tsOpen
$stageBefore = Get-Stage $s.xp $s.born $s.tsOpen $s.evos $s.tsEvo
$returnAt = $s.tsOpen + 90 * $day
$opened = Invoke-PetOpen $s $returnAt
$stageAfter = Get-Stage $opened.State.xp $opened.State.born $returnAt $opened.State.evos $opened.State.tsEvo
Assert-Equal $opened.State.xp 2500 "A long gap must never remove XP"
Assert-Equal $opened.State.evos 1 "A long gap must never undo an evolution"
Assert-True ($stageAfter.Band -ge $stageBefore.Band) "A long gap must never lower the stage"
Assert-True ($opened.Mood -ge $PetConfig.MoodFloor) "Mood after 90 days must be at or above the floor"
$afterChapter = Invoke-PetChapter $opened.State (New-Chapter ($returnAt + 30 * 60) 25)
Assert-True ($afterChapter.Points -gt 0) "Effort after a 90-day gap must still earn credit"

# --- Warm reunion after a long gap; no reunion for an ordinary next-day open.
foreach ($gap in @((2 * $day), (7 * $day), (90 * $day))) {
    $s = New-PetState $born 0
    $s.mood = $PetConfig.MoodFloor
    $r = Get-PetMood $s ($born + $gap)
    Assert-True $r.Reunion "Gap of $gap s should be a reunion"
    Assert-True ($r.Mood -ge $PetConfig.ReunionMood) "Reunion mood should be at least $($PetConfig.ReunionMood) (got $($r.Mood))"
}
$r = Get-PetMood (New-PetState $born 0) ($born + 20 * $hour)
Assert-True (-not $r.Reunion) "A 20-hour gap is not a reunion"

# --- The 48-hour pause: drift stops counting, so 2 days away equals 90 days away.
$s = New-PetState $born 0
$s.mood = 95
$at48 = (Get-PetMood $s ($born + 2 * $day)).RawMood
$at90d = (Get-PetMood $s ($born + 90 * $day)).RawMood
Assert-Equal $at90d $at48 "Mood drift must pause after 48 hours away"

# --- Clock moving backward never throws or punishes.
$s = New-PetState $born 0
$s.mood = 80
$back = Get-PetMood $s ($born - 5 * $hour)
Assert-Equal $back.Mood 80 "A backward clock must leave mood unchanged"

# --- Binge vs spread: binge earns less per chapter, never zero.
$bingeState = New-PetState $born 0
$bingePoints = @()
foreach ($k in 0..2) {
    $res = Invoke-PetChapter $bingeState (New-Chapter ($noon + $k * 3 * $hour) 40)
    $bingeState = $res.State
    $bingePoints += $res.Points
}
$spreadState = New-PetState $born 0
$spreadPoints = @()
foreach ($k in 0..2) {
    $res = Invoke-PetChapter $spreadState (New-Chapter ($noon + $k * $day) 40)
    $spreadState = $res.State
    $spreadPoints += $res.Points
}
$bingeTotal = ($bingePoints | Measure-Object -Sum).Sum
$spreadTotal = ($spreadPoints | Measure-Object -Sum).Sum
Assert-True ($bingeTotal -lt $spreadTotal) "Binge day must earn less than the same chapters spread out ($bingeTotal vs $spreadTotal)"
foreach ($p in $bingePoints) { Assert-True ($p -ge 1) "Every binge chapter must earn at least 1" }

$grind = New-PetState $born 0
for ($k = 0; $k -lt 20; $k += 1) {
    $res = Invoke-PetChapter $grind (New-Chapter ($noon + $k * 1800) 60 25)
    $grind = $res.State
    Assert-True ($res.Points -ge 1) "Chapter $($k + 1) of a 20-chapter day must still earn"
}
$tiny = Invoke-PetChapter (New-PetState $born 0) ([pscustomobject]@{
    start_epoch = $noon - 20; end_epoch = $noon; duration_s = 20; partial = 0; baseline_hr = -1; hr_avg = -1; reason = 1 })
Assert-Equal $tiny.Points 1 "A 20-second chapter earns the 1-point minimum"
Assert-Equal $tiny.Bonus 0 "A 20-second chapter must not claim the daily-first bonus"

# --- A chapter crossing 03:00 belongs to the evening in which it started.
$midnight = [long]([Math]::Floor($born / [double]$day) * $day)
$offset = -7 * $hour
$localMidnight = $midnight - $offset
$crossing = [pscustomobject]@{
    start_epoch = $localMidnight + 2 * $hour + 55 * 60
    end_epoch = $localMidnight + 3 * $hour + 5 * 60
    duration_s = 10 * 60
    partial = 0
    baseline_hr = 70
    hr_avg = 85
    reason = 3
}
$crossingCredit = Get-ChapterCredit $crossing (New-PetState $localMidnight $offset) $offset
Assert-Equal $crossingCredit.Ledger.dayIdx (Get-PetDay $crossing.start_epoch $offset) "A 03:00-crossing chapter must use its start day"
$crossingResult = Invoke-PetChapter (New-PetState $localMidnight $offset) $crossing
$afterBoundary = New-Chapter ($localMidnight + 3 * $hour + 20 * 60) 10
$nextResult = Invoke-PetChapter $crossingResult.State $afterBoundary
Assert-Equal $nextResult.Bonus $PetConfig.FirstOfDayBonus "The first post-03:00 chapter must receive the new day's bonus"

# --- Splitting a session into chapters does not change its credit.
$one = Invoke-PetChapter (New-PetState $born 0) (New-Chapter $noon 60)
$split = New-PetState $born 0
$splitTotal = 0
foreach ($k in 0..1) {
    $res = Invoke-PetChapter $split (New-Chapter ($noon + $k * 2400) 30)
    $split = $res.State
    $splitTotal += $res.Points
}
Assert-True ([Math]::Abs($splitTotal - $one.Points) -le 1) "Split session must earn the same as one chapter ($splitTotal vs $($one.Points))"

# --- Missing HR and a Back-ended chapter are never penalized.
$noHr = Invoke-PetChapter (New-PetState $born 0) (New-Chapter $noon 25 -1)
Assert-True ($noHr.Points -gt 0) "Missing HR must still earn"
Assert-Equal $noHr.Level 1.0 "Missing HR earns the base level"
$full = Invoke-PetChapter (New-PetState $born 0) (New-Chapter $noon 25 15 0)
$partial = Invoke-PetChapter (New-PetState $born 0) (New-Chapter $noon 25 15 1)
Assert-Equal $partial.Points $full.Points "A Back-ended chapter earns the same as a complete one"

# --- A chapter is credited once.
$s = New-PetState $born 0
$c = New-Chapter $noon 25
$first = Invoke-PetChapter $s $c
$again = Invoke-PetChapter $first.State $c
Assert-Equal $again.State.xp $first.State.xp "The same chapter must not be credited twice"

# --- Momentum: one missed day never shatters it, shields cover more, floor holds.
$s = New-PetState $born 0
$s.warm = 80
$s.shields = 0
$s.lastActiveDay = 100
Assert-Equal (Get-Momentum $s 102).Warm 80 "One missed day with no shields must keep warmth"
$s.shields = 1
$m = Get-Momentum $s 103
Assert-Equal $m.Warm 80 "Two missed days with one shield must keep warmth"
Assert-Equal $m.Shields 0 "The shield is spent"
$s.shields = 0
Assert-Equal (Get-Momentum $s 103).Warm (80 - $PetConfig.WarmDecayPerDay) "Two missed days with no shields drift one step"
Assert-Equal (Get-Momentum $s 400).Warm $PetConfig.WarmFloor "A long gap rests at the warmth floor, not below"
$back = Update-Momentum $s 400
Assert-Equal $back.warm ($PetConfig.WarmFloor + $PetConfig.ComebackGain) "Coming back after a gap gets the comeback gain"

# --- Momentum never multiplies credit.
$cold = New-PetState $born 0
$cold.warm = 20
$hot = New-PetState $born 0
$hot.warm = 100
$hot.shields = 2
$coldPts = (Invoke-PetChapter $cold (New-Chapter $noon 25)).Points
$hotPts = (Invoke-PetChapter $hot (New-Chapter $noon 25)).Points
Assert-Equal $hotPts $coldPts "Warmth must not change chapter credit"

# --- Stage thresholds are strictly increasing, and stage never drops as XP rises.
$previous = -1
for ($n = 0; $n -le 60; $n += 1) {
    $t = Get-BandThreshold $n
    Assert-True ($t -gt $previous) "Band $n threshold $t must exceed band $($n - 1) threshold $previous"
    $previous = $t
}
$late = $born + 400 * $day
$lastBand = -1
for ($xp = 0; $xp -le 20000; $xp += 50) {
    $evos = [Math]::Floor((Get-Stage $xp $born $late 99 0).XpBand / $PetConfig.EvoEvery)
    $st = Get-Stage $xp $born $late $evos 0
    Assert-True ($st.Band -ge $lastBand) "Stage dropped at xp=$xp"
    $lastBand = $st.Band
}

# --- Evolution gates: an age floor and a deliberate confirm, never a loss.
$young = Get-Stage 5000 $born ($born + 2 * $day) 0
Assert-Equal $young.Band 2 "A 2-day-old pet waits below its first evolution"
$ready = Get-Stage 5000 $born ($born + 10 * $day) 0
Assert-Equal $ready.Band 3 "Past the age floor, the stage stops at the ready evolution"
Assert-True $ready.EvoReady "The first evolution is ready to confirm"
$confirmed = Get-Stage 5000 $born ($born + 10 * $day) 1 ($born + 10 * $day)
Assert-Equal $confirmed.Band 5 "After confirming, banked XP opens the next bands"

Write-Host "[pass] Pet model: mood floor, no death at 90 days, warm reunion, 48 h pause, binge taper never zero, 03:00 start-day credit, split-invariant credit, one-miss grace, warmth never multiplies, monotonic stages, evolution gates"
