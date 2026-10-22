$ErrorActionPreference = "Stop"

# 120-day pacing sim for the PROPOSED economy in garmin-pet/12-pet-state-and-economy.md.
# Three synthetic users on the same deterministic random stream. Prints days-to-each-stage
# and a weekly mood summary. Host-side only; no device code involved.
. (Join-Path $PSScriptRoot "pet-model.ps1")

$Days = 120
$Offset = -7 * 3600                      # local time UTC-7
$Day0 = [DateTimeOffset]::new(2026, 11, 2, 0, 0, 0, [TimeSpan]::FromHours(-7)).ToUnixTimeSeconds()   # a Monday
$Hour = 3600

# Small LCG so every run prints the same table.
$script:Seed = 12345
function Get-Rand([int]$Lo, [int]$Hi) {
    $script:Seed = ($script:Seed * 1103515245 + 12345) % 2147483648
    return $Lo + [int]($script:Seed % ($Hi - $Lo + 1))
}

# Each schedule returns the day's sessions: open hour plus chapter minutes.
$Users = [ordered]@{
    'Daily'      = { param($dow) @(@{ Hour = 18; Minutes = (Get-Rand 20 30) }) }
    '3x/week'    = { param($dow) if ($dow -in 1, 3, 5) { @(@{ Hour = 18; Minutes = 45 }) } else { @() } }
    'Weekend'    = { param($dow) if ($dow -in 0, 6) { @(
                        @{ Hour = 9;  Minutes = (Get-Rand 35 45) },
                        @{ Hour = 13; Minutes = (Get-Rand 35 45) },
                        @{ Hour = 17; Minutes = (Get-Rand 35 45) }) } else { @() } }
}

$results = [ordered]@{}
foreach ($name in $Users.Keys) {
    $script:Seed = 12345
    $state = New-PetState ($Day0 + 7 * $Hour) $Offset
    $firstDay = @{}
    $evoDays = @()
    $weekly = @()
    $noonMoods = @()
    $minutes = 0
    for ($d = 0; $d -lt $Days; $d += 1) {
        $dayStart = $Day0 + $d * 86400
        $dow = [int][DateTimeOffset]::FromUnixTimeSeconds($dayStart - $Offset).DayOfWeek
        $sessions = @(& $Users[$name] $dow)
        $noonDone = $false
        foreach ($session in $sessions) {
            $openAt = $dayStart + $session.Hour * $Hour
            if (-not $noonDone -and $openAt -gt $dayStart + 12 * $Hour) {
                $noonMoods += (Get-PetMood $state ($dayStart + 12 * $Hour)).Mood
                $noonDone = $true
            }
            $opened = Invoke-PetOpen $state $openAt
            $state = $opened.State
            # The sim confirms a ready evolution at the next sit-down open.
            $stage = Get-Stage $state.xp $state.born $openAt $state.evos $state.tsEvo
            if ($stage.EvoReady) {
                $state = Invoke-PetEvolve $state $openAt
                $evoDays += ($d + 1)
            }
            $hrDelta = Get-Rand 8 24
            $end = $openAt + 120 + $session.Minutes * 60
            $chapter = [pscustomobject]@{
                start_epoch = $end - $session.Minutes * 60
                end_epoch   = $end
                duration_s  = $session.Minutes * 60
                partial     = 0
                baseline_hr = 68
                hr_avg      = 68 + $hrDelta
                reason      = 3
            }
            $state = (Invoke-PetChapter $state $chapter).State
            $minutes += $session.Minutes
            $stage = Get-Stage $state.xp $state.born $end $state.evos $state.tsEvo
            for ($b = 1; $b -le $stage.Band; $b += 1) {
                if (-not $firstDay.ContainsKey($b)) { $firstDay[$b] = $d + 1 }
            }
        }
        if (-not $noonDone) { $noonMoods += (Get-PetMood $state ($dayStart + 12 * $Hour)).Mood }
        if ((($d + 1) % 7) -eq 0 -or $d -eq $Days - 1) {
            $endOfWeek = $dayStart + 86399
            $mom = Get-Momentum $state (Get-PetDay $endOfWeek $Offset)
            $measure = $noonMoods | Measure-Object -Average -Minimum
            $weekly += [pscustomobject]@{
                Avg = [int][Math]::Round($measure.Average); Min = [int]$measure.Minimum
                Warm = $mom.Warm; Shields = $mom.Shields
            }
            $noonMoods = @()
        }
    }
    $results[$name] = [pscustomobject]@{
        FirstDay = $firstDay; EvoDays = $evoDays; Weekly = $weekly
        Xp = $state.xp; Chapters = $state.chTotal; Minutes = $minutes
        Stage = (Get-Stage $state.xp $state.born ($Day0 + $Days * 86400) $state.evos $state.tsEvo)
    }
}

$names = @($results.Keys)
Write-Host "Days to reach each stage (day 1 = first day; '-' = not within $Days days)"
Write-Host ""
Write-Host ("| Band | Name      | XP needed | {0,-9} | {1,-9} | {2,-9} |" -f $names[0], $names[1], $names[2])
Write-Host  "|------|-----------|-----------|-----------|-----------|-----------|"
for ($b = 1; $b -le 9; $b += 1) {
    $cells = foreach ($n in $names) {
        if ($results[$n].FirstDay.ContainsKey($b)) { "day $($results[$n].FirstDay[$b])" } else { '-' }
    }
    $label = Get-BandName $b
    if (Test-EvoBand $b) { $label = "$label*" }
    Write-Host ("| {0,4} | {1,-9} | {2,9} | {3,-9} | {4,-9} | {5,-9} |" -f $b, $label, (Get-BandThreshold $b), $cells[0], $cells[1], $cells[2])
}
Write-Host ""
Write-Host "* evolution band: needs the age gate plus a sit-down confirm (the sim confirms at the next open)."
Write-Host ""
Write-Host "| After $Days days | XP | Chapters | Active min | XP per active min | Stage |"
Write-Host "|----------------|----|----------|------------|-------------------|-------|"
foreach ($n in $names) {
    $r = $results[$n]
    Write-Host ("| {0} | {1} | {2} | {3} | {4:N2} | {5} {6} |" -f $n, $r.Xp, $r.Chapters, $r.Minutes, ($r.Xp / [double]$r.Minutes), $r.Stage.Band, $r.Stage.Name)
}
Write-Host ""
Write-Host "Weekly mood at a noon look (avg/min), warmth and shields at week end"
Write-Host ""
Write-Host ("| Week | {0,-22} | {1,-22} | {2,-22} |" -f "$($names[0]) mood warm sh", "$($names[1]) mood warm sh", "$($names[2]) mood warm sh")
Write-Host  "|------|------------------------|------------------------|------------------------|"
$weeks = $results[$names[0]].Weekly.Count
for ($w = 0; $w -lt $weeks; $w += 1) {
    $cells = foreach ($n in $names) {
        $x = $results[$n].Weekly[$w]
        "{0,3}/{1,-3} {2,4} {3,2}" -f $x.Avg, $x.Min, $x.Warm, $x.Shields
    }
    $label = "$($w + 1)"
    if ($w -eq $weeks - 1 -and ($Days % 7) -ne 0) { $label = "$($w + 1)*" }
    Write-Host ("| {0,4} | {1,-22} | {2,-22} | {3,-22} |" -f $label, $cells[0], $cells[1], $cells[2])
}
if (($Days % 7) -ne 0) { Write-Host ""; Write-Host "* partial week ($($Days % 7) day)." }
