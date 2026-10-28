# Parsing for Friend's log export, dot-sourced by read-friend.ps1 and
# test-friend-export.ps1. Format 3 exports carry a header line per section;
# format 4 drops them to fit Garmin's ~5 KB log file, so the columns live here.
# Format 5 (Friend 0.6.0) appends the six rr_* beat-interval columns to session
# rows; rows stored by an older build are shorter and parse with those blank.

$FriendColumns = @{
    snap = "epoch,steps,calories,moderate,vigorous,stress,hr4h_min,hr4h_avg,hr4h_max,body_battery,distance_cm,floors,respiration,time_to_recovery_h,spo2,pressure_pa,stress_age_s"
    session3 = "start_epoch,end_epoch,duration_s,hr4h_min,hr4h_avg,hr4h_max,hr_min,hr_avg,hr_max,motion_avg,motion_peak,moving_pct,steps_start,steps_end,stress_start,stress_end,bb_start,bb_end,chapters,last_chapter_s,lifetime_chapters,exit_reason,last_input_s,inputs,battery_start,battery_end,mem_peak_kb,hides,rr_count,rr_changes,rr_min_ms,rr_max_ms,rr_walk_count,rr_walk_changes"
    chapter3 = "start_epoch,end_epoch,duration_s,partial,baseline_hr,hr_min,hr_avg,hr_max,hr_delta_peak,motion_avg,motion_peak,moving_pct,steps_start,steps_end,reason"
}

# The newest complete export in the log, or $null.
function Get-FriendExportBlock([string[]]$Lines) {
    $begin = -1
    $end = -1
    for ($i = 0; $i -lt $Lines.Count; $i += 1) {
        if ($Lines[$i] -like "FRIEND_EXPORT_BEGIN,*") { $begin = $i; $end = -1 }
        elseif ($begin -ge 0 -and $Lines[$i] -eq "FRIEND_EXPORT_END") { $end = $i }
    }
    if ($begin -lt 0 -or $end -le $begin) { return $null }
    return $Lines[$begin..$end]
}

function Get-FriendSectionLines([string[]]$Block, [string]$Name) {
    $sectionBegin = -1
    $sectionEnd = -1
    for ($i = 0; $i -lt $Block.Count; $i += 1) {
        if ($Block[$i] -like "FRIEND_${Name}_BEGIN,*") { $sectionBegin = $i }
        elseif ($Block[$i] -eq "FRIEND_${Name}_END") { $sectionEnd = $i }
    }
    if ($sectionBegin -ge 0 -and $sectionEnd -gt ($sectionBegin + 1)) {
        return $Block[($sectionBegin + 1)..($sectionEnd - 1)]
    }
    return @()
}

# A CSV section; uses its own header line when it has one (format 3).
function Read-FriendCsvSection([string[]]$Block, [string]$Name) {
    $lines = @(Get-FriendSectionLines $Block $Name)
    if ($lines.Count -eq 0) { return @() }
    if ($lines[0] -match '^[a-z_]') {
        if ($lines.Count -lt 2) { return @() }
        return @($lines | ConvertFrom-Csv)
    }
    return @($lines | ConvertFrom-Csv -Header ($FriendColumns[$Name] -split ","))
}

function ConvertFrom-FriendBase36([string]$Text) {
    if ($Text -match '^z+$') { return -1 }
    $value = 0
    foreach ($char in $Text.ToCharArray()) {
        $value = $value * 36 + "0123456789abcdefghijklmnopqrstuvwxyz".IndexOf($char)
    }
    return $value
}

# Format 4 compact live rows; see exportCompactLive in WristDiaryView.mc.
function ConvertFrom-FriendLive4([string[]]$Lines) {
    $session = -1
    $epoch = 0
    $steps = -1
    foreach ($line in $Lines) {
        if ($line -like "S,*") {
            $parts = $line -split ","
            $session = [long]$parts[1]
            $epoch = [long]$parts[2]
            $steps = [long]$parts[3]
            continue
        }
        if ($line.Length -ne 22) { continue }
        $epoch += ConvertFrom-FriendBase36 $line.Substring(0, 2)
        $stepsDelta = ConvertFrom-FriendBase36 $line.Substring(15, 2)
        $rowSteps = -1
        if ($stepsDelta -ge 0 -and $steps -ge 0) {
            $steps += $stepsDelta
            $rowSteps = $steps
        }
        [pscustomobject]@{
            epoch = $epoch
            session_epoch = $session
            elapsed_s = $epoch - $session
            hr_min = ConvertFrom-FriendBase36 $line.Substring(2, 2)
            hr_avg = ConvertFrom-FriendBase36 $line.Substring(4, 2)
            hr_max = ConvertFrom-FriendBase36 $line.Substring(6, 2)
            motion_avg = ConvertFrom-FriendBase36 $line.Substring(8, 2)
            motion_peak = ConvertFrom-FriendBase36 $line.Substring(10, 3)
            moving_pct = ConvertFrom-FriendBase36 $line.Substring(13, 2)
            steps = $rowSteps
            stress = ConvertFrom-FriendBase36 $line.Substring(17, 2)
            body_battery = ConvertFrom-FriendBase36 $line.Substring(19, 2)
            chapter_state = ConvertFrom-FriendBase36 $line.Substring(21, 1)
        }
    }
}

# Adds rows to an archive CSV, keeping the first copy of each key.
function Add-FriendArchive([string]$Path, [object[]]$Rows, [string]$Key) {
    if ($Rows.Count -eq 0) { return 0 }
    $existing = @()
    if (Test-Path -LiteralPath $Path) { $existing = @(Import-Csv -LiteralPath $Path) }
    $seen = @{}
    foreach ($row in $existing) { $seen[[string]$row.$Key] = $true }
    $added = @($Rows | Where-Object { -not $seen.ContainsKey([string]$_.$Key) })
    if ($added.Count -eq 0) { return 0 }
    # Rows from older formats lack newer columns; write the union so none is dropped.
    $all = @($existing) + $added
    $columns = [System.Collections.Generic.List[string]]::new()
    foreach ($row in $all) {
        foreach ($name in $row.PSObject.Properties.Name) {
            if (-not $columns.Contains($name)) { $columns.Add($name) }
        }
    }
    $all | Select-Object -Property $columns | Sort-Object { [long]$_.$Key } |
        Export-Csv -LiteralPath $Path -NoTypeInformation
    return $added.Count
}
