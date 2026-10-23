# Host-side model of the PROPOSED pet state and effort economy in
# garmin-pet/12-pet-state-and-economy.md. Dot-source this file; it only defines
# functions and the $PetConfig table. Every number in $PetConfig is PROPOSED and
# mirrors the spec. The functions are pure: they return new state objects and
# never read the clock, so tests and the pacing sim can replay any timeline.
# The Connect IQ build remains the authority for the device implementation.

$PetConfig = @{
    DayStartHour      = 3        # a local "day" runs 03:00 to 03:00
    # Mood (weather)
    MoodFloor         = 35
    MoodMax           = 100
    MoodStart         = 60
    MoodHalfLifeSec   = 86400    # 24 h half-life toward the resting target
    MoodPauseSec      = 172800   # drift stops counting after 48 h away
    ReunionGapSec     = 172800   # an open after 48 h away is a reunion
    ReunionMood       = 70       # reunion lifts mood to at least this
    MoodTargetBase    = 40       # resting target = 40 + warm / 5 (40..60)
    MoodTargetWarmDiv = 5
    ChapterMoodBump   = 15
    # Effort credit
    FirstOfDayBonus   = 10
    ReunionBonus      = 10       # extra on the first bonus-paying chapter after a reunion
    BonusMinMinutes   = 5        # effort minutes a chapter needs to pay the daily-first bonus
    TaperFullMin      = 30       # first 30 effort minutes a day at full rate
    TaperHalfMin      = 60       # 30..60 at half rate, beyond 60 at quarter rate
    TaperRates        = @(1.0, 0.5, 0.25)
    HardDelta         = 20       # hr_avg - baseline_hr at or above: level 1.5
    SteadyDelta       = 10       # at or above: level 1.25, else 1.0
    MinChapterPoints  = 1
    # Momentum (expression only; never read by the credit function)
    WarmStart         = 20
    WarmFloor         = 20
    WarmMax           = 100
    WarmGain          = 15
    ComebackGain      = 25
    ComebackGapDays   = 3
    WarmDecayPerDay   = 8
    GraceDays         = 1
    ShieldEvery       = 5        # one shield per 5 active days
    ShieldMax         = 2
    # Stages
    QuadraticBands    = 9        # bands 1..9 use 60n^2 + 40n
    LateBandStep      = 1100     # each band after 9 costs a flat 1100
    EvoEvery          = 3        # bands 3, 6, 9, ... are evolutions
    FirstEvoMinAgeDays = 7
    LaterEvoMinGapDays = 30
    BandNames         = @('Hatchling', 'Sprout', 'Trainee', 'Athlete', 'Veteran', 'Ace', 'Legend', 'Hero', 'Mythic')
}

function Round-Half([double]$Value) {
    return [int][Math]::Floor($Value + 0.5)
}

function Get-PetDay([long]$Epoch, [int]$OffsetSec) {
    return [int][Math]::Floor(($Epoch + $OffsetSec - $PetConfig.DayStartHour * 3600) / 86400.0)
}

function New-PetState([long]$BornEpoch, [int]$OffsetSec) {
    return @{
        v             = 1
        born          = $BornEpoch
        tz            = $OffsetSec
        mood          = $PetConfig.MoodStart
        tsSettle      = $BornEpoch
        tsOpen        = $BornEpoch
        xp            = 0
        evos          = 0
        tsEvo         = $BornEpoch
        warm          = $PetConfig.WarmStart
        shields       = 0
        lastActiveDay = -1
        activeDays    = 0
        dayIdx        = -1
        dayMin        = 0.0
        dayBonus      = $false
        reunionOwed   = $false
        lastChEnd     = 0
        chTotal       = 0
    }
}

function Copy-PetState($State) {
    return $State.Clone()
}

# ---------------------------------------------------------------- momentum
# Warm and shields are stored as of the last active day. The current values are
# derived from the number of missed days, so reading them never changes state.
function Get-Momentum($State, [int]$Today) {
    if ($State.lastActiveDay -lt 0 -or $Today -le $State.lastActiveDay) {
        return @{ Warm = [Math]::Max($PetConfig.WarmFloor, $State.warm); Shields = $State.shields; Missed = 0 }
    }
    $missed = $Today - $State.lastActiveDay - 1
    $billable = [Math]::Max(0, $missed - $PetConfig.GraceDays)
    $spend = [Math]::Min($State.shields, $billable)
    $decayDays = $billable - $spend
    $warm = [Math]::Max($PetConfig.WarmFloor, $State.warm - $PetConfig.WarmDecayPerDay * $decayDays)
    return @{ Warm = $warm; Shields = $State.shields - $spend; Missed = $missed }
}

# Call when a credited chapter lands on $Today. Only the first one per day counts.
function Update-Momentum($State, [int]$Today) {
    $s = Copy-PetState $State
    if ($s.lastActiveDay -ge 0 -and $Today -le $s.lastActiveDay) { return $s }
    $current = Get-Momentum $s $Today
    $gain = $PetConfig.WarmGain
    if ($s.lastActiveDay -ge 0 -and $current.Missed -ge $PetConfig.ComebackGapDays) {
        $gain = $PetConfig.ComebackGain
    }
    $s.warm = [Math]::Min($PetConfig.WarmMax, $current.Warm + $gain)
    $s.shields = $current.Shields
    $s.activeDays += 1
    if (($s.activeDays % $PetConfig.ShieldEvery) -eq 0 -and $s.shields -lt $PetConfig.ShieldMax) {
        $s.shields += 1
    }
    $s.lastActiveDay = $Today
    return $s
}

function Get-WarmName([int]$Warm) {
    if ($Warm -ge 90) { return 'in the zone' }
    if ($Warm -ge 70) { return 'warmed up' }
    if ($Warm -ge 40) { return 'loose' }
    return 'rusty but fine'
}

# -------------------------------------------------------------------- mood
# Mood is weather: settled from timestamps on open, never ticked.
function Get-PetMood($State, [long]$Now) {
    $elapsed = [Math]::Max(0, $Now - $State.tsSettle)
    $effective = [Math]::Min($elapsed, $PetConfig.MoodPauseSec)
    $warm = (Get-Momentum $State (Get-PetDay $Now $State.tz)).Warm
    $target = $PetConfig.MoodTargetBase + $warm / $PetConfig.MoodTargetWarmDiv
    $start = [Math]::Max($PetConfig.MoodFloor, [Math]::Min($PetConfig.MoodMax, [double]$State.mood))
    $raw = $target + ($start - $target) * [Math]::Pow(0.5, $effective / [double]$PetConfig.MoodHalfLifeSec)
    $raw = [Math]::Max($PetConfig.MoodFloor, [Math]::Min($PetConfig.MoodMax, $raw))
    $away = [Math]::Max(0, $Now - $State.tsOpen)
    $reunion = $away -ge $PetConfig.ReunionGapSec
    $mood = $raw
    if ($reunion) { $mood = [Math]::Max($mood, $PetConfig.ReunionMood) }
    $mood = Round-Half $mood
    return @{ Mood = $mood; RawMood = (Round-Half $raw); Reunion = $reunion; AwaySec = $away; Weather = (Get-WeatherName $mood) }
}

function Get-WeatherName([int]$Mood) {
    if ($Mood -ge 85) { return 'radiant' }
    if ($Mood -ge 70) { return 'sunny' }
    if ($Mood -ge 50) { return 'fair' }
    return 'misty'
}

function Invoke-PetOpen($State, [long]$Now) {
    $s = Copy-PetState $State
    $r = Get-PetMood $s $Now
    $s.mood = $r.Mood
    $s.tsSettle = [Math]::Max($s.tsSettle, $Now)
    $s.tsOpen = [Math]::Max($s.tsOpen, $Now)
    if ($r.Reunion) { $s.reunionOwed = $true }
    return @{ State = $s; Reunion = $r.Reunion; Mood = $r.Mood; Weather = $r.Weather }
}

# ------------------------------------------------------------ effort credit
function Get-EffortLevel($Chapter) {
    if ($Chapter.hr_avg -lt 0 -or $Chapter.baseline_hr -lt 0) { return 1.0 }
    $delta = $Chapter.hr_avg - $Chapter.baseline_hr
    if ($delta -ge $PetConfig.HardDelta) { return 1.5 }
    if ($delta -ge $PetConfig.SteadyDelta) { return 1.25 }
    return 1.0
}

function Get-TaperedPoints([double]$From, [double]$To) {
    $edges = @(0.0, [double]$PetConfig.TaperFullMin, [double]$PetConfig.TaperHalfMin, [double]::MaxValue)
    $sum = 0.0
    for ($i = 0; $i -lt 3; $i += 1) {
        $lo = [Math]::Max($From, $edges[$i])
        $hi = [Math]::Min($To, $edges[$i + 1])
        if ($hi -gt $lo) { $sum += ($hi - $lo) * $PetConfig.TaperRates[$i] }
    }
    return $sum
}

# Pure: chapter + the day ledger before it -> points and the ledger after it.
# Takes no momentum, mood or stage input on purpose: nothing multiplies effort.
function Get-ChapterCredit($Chapter, $Ledger, [int]$OffsetSec, [bool]$ReunionOwed = $false) {
    # A chapter belongs to the local 03:00-to-03:00 day in which it started,
    # even when it crosses the boundary before it closes.
    $day = Get-PetDay $Chapter.start_epoch $OffsetSec
    $before = 0.0
    $bonusPaid = $false
    if ($Ledger.dayIdx -eq $day) {
        $before = [double]$Ledger.dayMin
        $bonusPaid = [bool]$Ledger.dayBonus
    }
    $level = Get-EffortLevel $Chapter
    $minutes = [Math]::Max(0, $Chapter.duration_s) / 60.0 * $level
    $raw = Get-TaperedPoints $before ($before + $minutes)
    $bonus = 0
    $reunionUsed = $false
    if (-not $bonusPaid -and $minutes -ge $PetConfig.BonusMinMinutes) {
        $bonus = $PetConfig.FirstOfDayBonus
        if ($ReunionOwed) { $bonus += $PetConfig.ReunionBonus; $reunionUsed = $true }
        $bonusPaid = $true
    }
    $points = [Math]::Max($PetConfig.MinChapterPoints, (Round-Half ($raw + $bonus)))
    return @{
        Points      = $points
        Level       = $level
        Bonus       = $bonus
        ReunionUsed = $reunionUsed
        Ledger      = @{ dayIdx = $day; dayMin = $before + $minutes; dayBonus = $bonusPaid }
    }
}

# Applies one finished chapter row. Idempotent on end_epoch.
function Invoke-PetChapter($State, $Chapter) {
    $s = Copy-PetState $State
    if ($Chapter.end_epoch -le $s.lastChEnd) { return @{ State = $s; Points = 0; Duplicate = $true } }
    $settled = Get-PetMood $s $Chapter.end_epoch
    $s.mood = [Math]::Min($PetConfig.MoodMax, $settled.RawMood + $PetConfig.ChapterMoodBump)
    $s.tsSettle = [Math]::Max($s.tsSettle, $Chapter.end_epoch)
    $credit = Get-ChapterCredit $Chapter $s $s.tz $s.reunionOwed
    $s.xp += $credit.Points
    $s.dayIdx = $credit.Ledger.dayIdx
    $s.dayMin = $credit.Ledger.dayMin
    $s.dayBonus = $credit.Ledger.dayBonus
    if ($credit.ReunionUsed) { $s.reunionOwed = $false }
    $s = Update-Momentum $s $credit.Ledger.dayIdx
    $s.lastChEnd = $Chapter.end_epoch
    $s.chTotal += 1
    return @{ State = $s; Points = $credit.Points; Level = $credit.Level; Bonus = $credit.Bonus; Duplicate = $false }
}

# ------------------------------------------------------------------ stages
function Get-BandThreshold([int]$Band) {
    if ($Band -le 0) { return 0 }
    $q = $PetConfig.QuadraticBands
    if ($Band -le $q) { return 60 * $Band * $Band + 40 * $Band }
    return (60 * $q * $q + 40 * $q) + ($Band - $q) * $PetConfig.LateBandStep
}

function Get-BandName([int]$Band) {
    $names = $PetConfig.BandNames
    if ($Band -lt $names.Count) { return $names[$Band] }
    return "Mythic $($Band - $names.Count + 2)"
}

function Test-EvoBand([int]$Band) {
    return ($Band -gt 0) -and (($Band % $PetConfig.EvoEvery) -eq 0)
}

# Stage from lifetime XP plus the evolution gates (age and a deliberate confirm).
function Get-Stage([long]$Xp, [long]$BornEpoch, [long]$Now, [int]$EvosConfirmed, [long]$LastEvoEpoch = 0) {
    $xpBand = 0
    while ((Get-BandThreshold ($xpBand + 1)) -le $Xp) { $xpBand += 1 }

    $nextEvo = $PetConfig.EvoEvery * ($EvosConfirmed + 1)
    if ($EvosConfirmed -eq 0) {
        $ageOk = ($Now - $BornEpoch) -ge ($PetConfig.FirstEvoMinAgeDays * 86400)
    } else {
        $ageOk = ($Now - $LastEvoEpoch) -ge ($PetConfig.LaterEvoMinGapDays * 86400)
    }

    $band = $xpBand
    $evoReady = $false
    if ($xpBand -ge $nextEvo) {
        if ($ageOk) { $band = $nextEvo; $evoReady = $true }
        else { $band = $nextEvo - 1 }
    }
    $life = 'adult'
    if ($band -eq 0) { $life = 'baby' } elseif ($band -lt $PetConfig.EvoEvery) { $life = 'child' }
    return @{
        Band          = $band
        Name          = (Get-BandName $band)
        Life          = $life
        EvoReady      = $evoReady
        XpBand        = $xpBand
        NextThreshold = (Get-BandThreshold ($band + 1))
    }
}

# Sit-down confirm of a ready evolution (the branch pick itself is Layer A, not modeled).
function Invoke-PetEvolve($State, [long]$Now) {
    $stage = Get-Stage $State.xp $State.born $Now $State.evos $State.tsEvo
    $s = Copy-PetState $State
    if ($stage.EvoReady) { $s.evos += 1; $s.tsEvo = $Now }
    return $s
}
