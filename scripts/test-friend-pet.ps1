$ErrorActionPreference = "Stop"

# Holds Friend's on-watch pet economy (FriendPet.mc) against the host model of
# garmin-pet/12-pet-state-and-economy.md (pet-model.ps1).
#
# 1. Every tuning constant in FriendPet.mc is read out of the source and
#    compared with $PetConfig, so the watch, the model and the doc cannot drift.
# 2. FriendPet.mc does its credit math in whole numbers (effort minutes x100,
#    points x100). The functions below repeat that integer math step for step
#    and replay random timelines through both it and the model.
# The Connect IQ compiler remains the authority for the device implementation.
. (Join-Path $PSScriptRoot "pet-model.ps1")

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) { throw "$Message (expected=$Expected actual=$Actual)" }
}
function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

# ------------------------------------------------- 1. constants in the source
$source = Get-Content -Raw (Join-Path $PSScriptRoot "..\garmin-pet\probes\wrist-diary\source\FriendPet.mc")
$watch = @{}
foreach ($m in [regex]::Matches($source, 'const\s+([A-Z_0-9]+)\s*=\s*(-?\d+);')) {
    $watch[$m.Groups[1].Value] = [int]$m.Groups[2].Value
}
$pairs = [ordered]@{
    DAY_START_HOUR    = $PetConfig.DayStartHour
    MOOD_FLOOR        = $PetConfig.MoodFloor
    MOOD_MAX          = $PetConfig.MoodMax
    MOOD_START        = $PetConfig.MoodStart
    MOOD_PAUSE        = $PetConfig.MoodPauseSec
    REUNION_GAP       = $PetConfig.ReunionGapSec
    REUNION_MOOD      = $PetConfig.ReunionMood
    MOOD_TARGET_BASE  = $PetConfig.MoodTargetBase
    CHAPTER_MOOD_BUMP = $PetConfig.ChapterMoodBump
    FIRST_BONUS       = $PetConfig.FirstOfDayBonus
    REUNION_BONUS     = $PetConfig.ReunionBonus
    BONUS_MIN_MINUTES = $PetConfig.BonusMinMinutes
    TAPER_FULL        = $PetConfig.TaperFullMin * 100
    TAPER_HALF        = $PetConfig.TaperHalfMin * 100
    HARD_DELTA        = $PetConfig.HardDelta
    STEADY_DELTA      = $PetConfig.SteadyDelta
    WARM_START        = $PetConfig.WarmStart
    WARM_FLOOR        = $PetConfig.WarmFloor
    WARM_MAX          = $PetConfig.WarmMax
    WARM_GAIN         = $PetConfig.WarmGain
    COMEBACK_GAIN     = $PetConfig.ComebackGain
    COMEBACK_GAP_DAYS = $PetConfig.ComebackGapDays
    WARM_DECAY        = $PetConfig.WarmDecayPerDay
    GRACE_DAYS        = $PetConfig.GraceDays
    SHIELD_EVERY      = $PetConfig.ShieldEvery
    SHIELD_MAX        = $PetConfig.ShieldMax
    EVO_EVERY         = $PetConfig.EvoEvery
    FIRST_EVO_AGE     = $PetConfig.FirstEvoMinAgeDays * 86400
    LATER_EVO_GAP     = $PetConfig.LaterEvoMinGapDays * 86400
}
foreach ($name in $pairs.Keys) {
    Assert-True $watch.ContainsKey($name) "FriendPet.mc has no constant $name"
    Assert-Equal $watch[$name] $pairs[$name] "FriendPet.mc $name differs from `$PetConfig"
}
Assert-True ($PetConfig.MoodHalfLifeSec -eq 86400) "FriendPet.mc hard-codes a 24 h mood half-life"
Assert-True ($PetConfig.MoodTargetWarmDiv -eq 5) "FriendPet.mc hard-codes warmth / 5 in the mood target"
Assert-True (($PetConfig.TaperRates -join ",") -eq "1,0.5,0.25") "FriendPet.mc hard-codes the 1 / 0.5 / 0.25 taper"
# The stored array's layout is part of the export; an index must never be reused.
$indexes = @($watch.Keys | Where-Object { $_ -like "P_*" } | ForEach-Object { $watch[$_] } | Sort-Object)
Assert-Equal $indexes.Count $watch["SIZE"] "Every slot of the pet array has exactly one name"
Assert-Equal (($indexes | Select-Object -Unique).Count) $indexes.Count "No two pet fields share an index"
Assert-Equal $indexes[-1] ($watch["SIZE"] - 1) "The pet array has no gap at the end"

# --------------------------------------- 2. the watch's integer math, repeated
function IDiv([long]$A, [long]$B) { return [long][Math]::Truncate($A / $B) }

function New-WatchPet([long]$Born, [int]$Offset) {
    return @{
        born = $Born; tz = $Offset; mood = $PetConfig.MoodStart; tsSettle = $Born; tsOpen = $Born
        xp = 0; evos = 0; tsEvo = $Born; warm = $PetConfig.WarmStart; shields = 0
        lastActiveDay = -1; activeDays = 0; dayIdx = -1; dayMin = 0; dayBonus = 0
        reunionOwed = 0; lastChEnd = 0; chTotal = 0
        owedPoints = 0; owedBand = 0; owedFlames = 0; owedSeconds = 0; owedFlags = 0
    }
}

function Get-WatchDay([long]$Epoch, [int]$Offset) {
    return [int](IDiv ($Epoch + $Offset - $PetConfig.DayStartHour * 3600) 86400)
}

function Get-WatchMomentum($S, [int]$Today) {
    $warm = [Math]::Max($PetConfig.WarmFloor, $S.warm)
    if ($S.lastActiveDay -lt 0 -or $Today -le $S.lastActiveDay) { return @($warm, $S.shields, 0) }
    $missed = $Today - $S.lastActiveDay - 1
    $billable = [Math]::Max(0, $missed - $PetConfig.GraceDays)
    $spend = [Math]::Min($S.shields, $billable)
    $warm = [Math]::Max($PetConfig.WarmFloor, $S.warm - $PetConfig.WarmDecayPerDay * ($billable - $spend))
    return @($warm, ($S.shields - $spend), $missed)
}

function Set-WatchActiveDay($S, [int]$Today) {
    if ($S.lastActiveDay -ge 0 -and $Today -le $S.lastActiveDay) { return }
    $current = Get-WatchMomentum $S $Today
    $gain = $PetConfig.WarmGain
    if ($S.lastActiveDay -ge 0 -and $current[2] -ge $PetConfig.ComebackGapDays) { $gain = $PetConfig.ComebackGain }
    $S.warm = [Math]::Min($PetConfig.WarmMax, $current[0] + $gain)
    $S.shields = $current[1]
    $S.activeDays += 1
    if (($S.activeDays % $PetConfig.ShieldEvery) -eq 0 -and $S.shields -lt $PetConfig.ShieldMax) { $S.shields += 1 }
    $S.lastActiveDay = $Today
}

# [mood, mood before a reunion lift, reunion]. Single-precision, as on the watch.
function Get-WatchMood($S, [long]$Now) {
    $elapsed = [Math]::Min([Math]::Max(0, $Now - $S.tsSettle), $PetConfig.MoodPauseSec)
    $warm = (Get-WatchMomentum $S (Get-WatchDay $Now $S.tz))[0]
    [single]$target = $PetConfig.MoodTargetBase + [single]$warm / [single]5.0
    $start = [Math]::Min($PetConfig.MoodMax, [Math]::Max($PetConfig.MoodFloor, $S.mood))
    [single]$factor = [Math]::Pow(0.5, [single]$elapsed / [single]86400.0)
    [single]$raw = $target + ([single]$start - $target) * $factor
    if ($raw -lt $PetConfig.MoodFloor) { $raw = $PetConfig.MoodFloor }
    if ($raw -gt $PetConfig.MoodMax) { $raw = $PetConfig.MoodMax }
    $rawMood = [int][Math]::Truncate($raw + [single]0.5)
    $mood = $rawMood
    $reunion = if (($Now - $S.tsOpen) -ge $PetConfig.ReunionGapSec) { 1 } else { 0 }
    if ($reunion -eq 1 -and $mood -lt $PetConfig.ReunionMood) { $mood = $PetConfig.ReunionMood }
    return @($mood, $rawMood, $reunion)
}

function Invoke-WatchOpen($S, [long]$Now) {
    $settled = Get-WatchMood $S $Now
    $S.mood = $settled[0]
    if ($Now -gt $S.tsSettle) { $S.tsSettle = $Now }
    if ($Now -gt $S.tsOpen) { $S.tsOpen = $Now }
    if ($settled[2] -eq 1) { $S.reunionOwed = 1 }
    return ($settled[2] -eq 1)
}

function Get-WatchLevel([int]$Baseline, [int]$HrAvg) {
    if ($HrAvg -lt 0 -or $Baseline -lt 0) { return 100 }
    $delta = $HrAvg - $Baseline
    if ($delta -ge $PetConfig.HardDelta) { return 150 }
    if ($delta -ge $PetConfig.SteadyDelta) { return 125 }
    return 100
}

function Get-WatchOverlap([long]$Before, [long]$After, [long]$Low, [long]$High) {
    $a = [Math]::Max($Before, $Low)
    $b = [Math]::Min($After, $High)
    if ($b -gt $a) { return $b - $a }
    return 0
}

function Get-WatchTapered([long]$Before, [long]$After) {
    $full = $PetConfig.TaperFullMin * 100
    $half = $PetConfig.TaperHalfMin * 100
    return (Get-WatchOverlap $Before $After 0 $full) +
           (IDiv (Get-WatchOverlap $Before $After $full $half) 2) +
           (IDiv (Get-WatchOverlap $Before $After $half 2000000000) 4)
}

# [points, level x100, bonus, reunion used, day, day minutes x100 after, bonus paid]
function Get-WatchCredit($S, [long]$Start, [int]$Duration, [int]$Baseline, [int]$HrAvg) {
    $day = Get-WatchDay $Start $S.tz
    $before = 0
    $bonusPaid = 0
    if ($S.dayIdx -eq $day) { $before = $S.dayMin; $bonusPaid = $S.dayBonus }
    $level = Get-WatchLevel $Baseline $HrAvg
    $minutes = IDiv ([Math]::Max(0, $Duration) * $level) 60
    $centi = Get-WatchTapered $before ($before + $minutes)
    $bonus = 0
    $reunionUsed = 0
    if ($bonusPaid -eq 0 -and $minutes -ge $PetConfig.BonusMinMinutes * 100) {
        $bonus = $PetConfig.FirstOfDayBonus
        if ($S.reunionOwed -eq 1) { $bonus += $PetConfig.ReunionBonus; $reunionUsed = 1 }
        $bonusPaid = 1
    }
    $points = [Math]::Max(1, (IDiv ($centi + $bonus * 100 + 50) 100))
    return @($points, $level, $bonus, $reunionUsed, $day, ($before + $minutes), $bonusPaid)
}

function Get-WatchXpBand($S) {
    $reached = 0
    while ((Get-BandThreshold ($reached + 1)) -le $S.xp) { $reached += 1 }
    return $reached
}

# The watch keeps the pet one band below an evolution until the wearer picks a form.
function Get-WatchBand($S) {
    $reached = Get-WatchXpBand $S
    $gate = $PetConfig.EvoEvery * ($S.evos + 1)
    if ($reached -ge $gate) { return $gate - 1 }
    return $reached
}

function Test-WatchEvoReady($S, [long]$Now) {
    if ((Get-WatchXpBand $S) -lt $PetConfig.EvoEvery * ($S.evos + 1)) { return $false }
    if ($S.evos -eq 0) { return ($Now - $S.born) -ge ($PetConfig.FirstEvoMinAgeDays * 86400) }
    return ($Now - $S.tsEvo) -ge ($PetConfig.LaterEvoMinGapDays * 86400)
}

function Invoke-WatchChapter($S, $Chapter) {
    if ($Chapter.end_epoch -le $S.lastChEnd) { return 0 }
    $bandBefore = Get-WatchBand $S
    $settled = Get-WatchMood $S $Chapter.end_epoch
    $S.mood = [Math]::Min($PetConfig.MoodMax, $settled[1] + $PetConfig.ChapterMoodBump)
    if ($Chapter.end_epoch -gt $S.tsSettle) { $S.tsSettle = $Chapter.end_epoch }
    $credit = Get-WatchCredit $S $Chapter.start_epoch $Chapter.duration_s $Chapter.baseline_hr $Chapter.hr_avg
    $S.xp += $credit[0]
    $S.dayIdx = $credit[4]
    $S.dayMin = $credit[5]
    $S.dayBonus = $credit[6]
    if ($credit[3] -eq 1) { $S.reunionOwed = 0 }
    Set-WatchActiveDay $S $credit[4]
    $S.lastChEnd = $Chapter.end_epoch
    $S.chTotal += 1
    if ($S.owedPoints -eq 0) { $S.owedBand = $bandBefore; $S.owedFlames = 0; $S.owedSeconds = 0; $S.owedFlags = 0 }
    $S.owedPoints += $credit[0]
    $S.owedSeconds += [Math]::Max(0, $Chapter.duration_s)
    $lit = if ($credit[1] -ge 150) { 3 } elseif ($credit[1] -ge 125) { 2 } else { 1 }
    if ($lit -gt $S.owedFlames) { $S.owedFlames = $lit }
    return $credit[0]
}

# ------------------------------------------------ random timelines, both ways
$script:Seed = 20261110
function Get-Rand([int]$Lo, [int]$Hi) {
    $script:Seed = ($script:Seed * 1103515245 + 12345) % 2147483648
    return $Lo + [int]($script:Seed % ($Hi - $Lo + 1))
}

$offset = -7 * 3600
$born = 1793606400
$worstChapter = 0
$worstMood = 0
$chapters = 0
foreach ($run in 1..12) {
    $model = New-PetState $born $offset
    $pet = New-WatchPet $born $offset
    $clock = $born + 3600
    foreach ($step in 1..60) {
        # A visit after a gap of minutes, hours or (sometimes) days, then a chapter.
        $roll = Get-Rand 0 9
        if ($roll -le 3) { $gap = Get-Rand 300 7200 }
        elseif ($roll -le 7) { $gap = Get-Rand 14400 100000 }
        elseif ($roll -eq 8) { $gap = Get-Rand 180000 400000 }
        else { $gap = Get-Rand 400000 2000000 }
        $clock += $gap
        $opened = Invoke-PetOpen $model $clock
        $model = $opened.State
        $reunion = Invoke-WatchOpen $pet $clock
        # A reunion sits on a hard 48 h edge; both sides see the same gap, so they agree.
        Assert-Equal $reunion $opened.Reunion "Reunion on open (run $run step $step)"
        Assert-True ([Math]::Abs($pet.mood - $opened.Mood) -le 1) "Mood on open differs by more than 1 (run $run step ${step}: watch $($pet.mood), model $($opened.Mood))"
        $worstMood = [Math]::Max($worstMood, [Math]::Abs($pet.mood - $opened.Mood))
        $pet.mood = $opened.Mood     # one shared mood, so a one-point rounding gap cannot compound

        $duration = Get-Rand 20 7200
        if ((Get-Rand 0 4) -eq 0) { $duration = Get-Rand 20 400 }
        $baseline = Get-Rand 55 85
        $hrAvg = $baseline + (Get-Rand -8 55)
        if ((Get-Rand 0 9) -eq 0) { $baseline = -1 }
        $clock += 60 + $duration
        $chapter = [pscustomobject]@{
            start_epoch = $clock - $duration; end_epoch = $clock; duration_s = $duration
            partial = 0; baseline_hr = $baseline; hr_avg = $hrAvg; reason = 3
        }
        $before = $model.xp
        $model = (Invoke-PetChapter $model $chapter).State
        $earnedModel = $model.xp - $before
        $earnedWatch = Invoke-WatchChapter $pet $chapter
        $chapters += 1
        $diff = [Math]::Abs($earnedWatch - $earnedModel)
        $worstChapter = [Math]::Max($worstChapter, $diff)
        Assert-True ($diff -le 1) "A chapter's credit differs by more than 1 (run $run step ${step}: watch $earnedWatch, model $earnedModel)"
        $pet.xp = $model.xp          # one shared total, for the same reason
        Assert-True ([Math]::Abs($pet.mood - $model.mood) -le 1) "Mood after a chapter differs by more than 1"
        $pet.mood = $model.mood
        Assert-Equal $pet.warm $model.warm "Warmth (run $run step $step)"
        Assert-Equal $pet.shields $model.shields "Shields (run $run step $step)"
        Assert-Equal $pet.activeDays $model.activeDays "Active days (run $run step $step)"
        Assert-Equal $pet.dayIdx $model.dayIdx "Day index (run $run step $step)"
        Assert-Equal $pet.dayBonus ([int]$model.dayBonus) "Daily-first bonus flag (run $run step $step)"
        Assert-Equal $pet.reunionOwed ([int]$model.reunionOwed) "Reunion owed (run $run step $step)"
        # Each chapter truncates under 0.01 of a minute; a day holds a handful.
        Assert-True ([Math]::Abs($pet.dayMin / 100.0 - $model.dayMin) -lt 0.25) "The day's effort minutes drifted"

        # Stage: identical, except that the watch waits one band below a ready evolution.
        $stage = Get-Stage $model.xp $model.born $clock $model.evos $model.tsEvo
        $ready = Test-WatchEvoReady $pet $clock
        Assert-Equal $ready $stage.EvoReady "Evolution ready (run $run step $step)"
        $expectedBand = if ($stage.EvoReady) { $stage.Band - 1 } else { $stage.Band }
        Assert-Equal (Get-WatchBand $pet) $expectedBand "Displayed band (run $run step $step)"
        if ($ready -and (Get-Rand 0 2) -eq 0) {
            $model = Invoke-PetEvolve $model $clock
            $pet.evos += 1
            $pet.tsEvo = $clock
        }
    }
}

# ------------------------------------------------------------ fixed behaviors
# The same chapter offered twice is credited once.
$pet = New-WatchPet $born $offset
$one = [pscustomobject]@{ start_epoch = $born + 3600; end_epoch = $born + 5400; duration_s = 1800; partial = 0; baseline_hr = 65; hr_avg = 90; reason = 3 }
$first = Invoke-WatchChapter $pet $one
Assert-True ($first -gt 0) "A first chapter earns points"
Assert-Equal (Invoke-WatchChapter $pet $one) 0 "A repeated chapter earns nothing"
Assert-Equal $pet.chTotal 1 "A repeated chapter is not counted"

# The effort level follows the retuned thresholds (15 and 30 over the baseline).
Assert-Equal (Get-WatchLevel 67 81) 100 "+14 is easy"
Assert-Equal (Get-WatchLevel 67 82) 125 "+15 is steady"
Assert-Equal (Get-WatchLevel 67 96) 125 "+29 is steady"
Assert-Equal (Get-WatchLevel 67 97) 150 "+30 is hard"
Assert-Equal (Get-WatchLevel -1 97) 100 "No baseline is easy, never zero"

# A reward that nobody saw keeps adding up, and remembers the band it started from.
$pet = New-WatchPet $born $offset
$t = $born + 3600
foreach ($n in 1..4) {
    $t += 86400
    $null = Invoke-WatchChapter $pet ([pscustomobject]@{ start_epoch = $t - 2400; end_epoch = $t; duration_s = 2400; partial = 0; baseline_hr = 65; hr_avg = 85; reason = 3 })
}
Assert-Equal $pet.owedPoints $pet.xp "Owed points add up across unseen chapters"
Assert-Equal $pet.owedBand 0 "The owed reward remembers the band before its first chapter"
Assert-True ((Get-WatchBand $pet) -ge 1) "Four daily 40-minute chapters reach Sprout"
Assert-Equal $pet.owedSeconds 9600 "Owed seconds add up"

# Hatching replays stored chapters; the pet never shows an evolved band it has not chosen.
$pet = New-WatchPet $born $offset
$pet.xp = 5000
Assert-Equal (Get-WatchBand $pet) 2 "Banked XP waits one band below the first evolution"
$pet.evos = 1
Assert-Equal (Get-WatchBand $pet) 5 "After one evolution it waits below the second"
$pet.evos = 2
Assert-Equal (Get-WatchBand $pet) 8 "After two it shows everything the XP covers below the third"

Write-Host "[pass] Friend pet: $($pairs.Count) constants match `$PetConfig, $($watch['SIZE'])-slot layout, $chapters random chapters within $worstChapter point of the model (mood within $worstMood), repeat credit, effort levels, owed reward, evolution wait"
