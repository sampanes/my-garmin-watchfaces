$ErrorActionPreference = "Stop"

# Host-side model of Friend's format 4 export. The encoder below mirrors
# exportCompactLive/base36 in WristDiaryView.mc; the decoder is the real one
# read-friend.ps1 uses. The Connect IQ compiler remains the authority for the
# device implementation.
. (Join-Path $PSScriptRoot "friend-export.ps1")

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

function ConvertTo-Base36([long]$Value, [int]$Width) {
    $limit = [long][Math]::Pow(36, $Width)
    $number = $Value
    if ($number -lt 0) { $number = $limit - 1 }
    elseif ($number -gt $limit - 2) { $number = $limit - 2 }
    $text = ""
    for ($j = 0; $j -lt $Width; $j += 1) {
        $text = "0123456789abcdefghijklmnopqrstuvwxyz"[[int]($number % 36)] + $text
        $number = [Math]::Floor($number / 36)
    }
    return $text
}

function Export-CompactLiveModel([long[][]]$Records) {
    $session = -1
    $lastEpoch = 0
    $lastSteps = -1
    foreach ($record in $Records) {
        $steps = $record[11]
        if ($record[1] -ne $session -or $record[0] - $lastEpoch -gt 1294 -or
            ($steps -ge 0 -and ($lastSteps -lt 0 -or $steps -lt $lastSteps -or
                                $steps - $lastSteps -gt 1294))) {
            $session = $record[1]
            $lastEpoch = $record[0]
            $lastSteps = $steps
            "S,$session,$lastEpoch,$lastSteps"
        }
        $stepsDelta = if ($steps -ge 0) { $steps - $lastSteps } else { -1 }
        (ConvertTo-Base36 ($record[0] - $lastEpoch) 2) +
            (ConvertTo-Base36 $record[4] 2) + (ConvertTo-Base36 $record[5] 2) +
            (ConvertTo-Base36 $record[6] 2) + (ConvertTo-Base36 $record[8] 2) +
            (ConvertTo-Base36 $record[9] 3) + (ConvertTo-Base36 $record[10] 2) +
            (ConvertTo-Base36 $stepsDelta 2) + (ConvertTo-Base36 $record[12] 2) +
            (ConvertTo-Base36 $record[13] 2) + (ConvertTo-Base36 $record[14] 1)
        $lastEpoch = $record[0]
        if ($steps -ge 0) { $lastSteps = $steps }
    }
}

# Synthetic live3 records covering missing HR, a motion peak past 3 digits,
# steps going backwards (midnight), and missing stress. No watch export data.
$records = [long[][]]@(
    @(1700000040, 1700000000, 40, 100, 90, 100, 110, 25, 300, 1200, 80, 500, -1, 60, 1),
    @(1700000060, 1700000000, 60, -1, -1, -1, -1, -1, 275, 1500, 65, 510, 20, 55, 0),
    @(1700000080, 1700000000, 80, 145, 135, 145, 155, 45, 450, 25000, 90, 750, 75, 50, 1),
    @(1700000100, 1700000000, 100, 115, 105, 115, 125, 35, 225, 1800, 55, 5, 40, -1, 1),
    @(1700004280, 1700004000, 280, 130, 120, 130, 140, 40, 350, 6000, 70, 900, -1, 45, 1),
    @(1700004300, 1700004000, 300, 95, 85, 95, 105, 20, 125, 700, 35, 920, 15, 40, 1),
    @(1700004320, 1700004000, 320, 105, 95, 105, 115, 30, 175, 900, 45, 950, 25, 35, 0)
)
$lines = @(Export-CompactLiveModel $records)
foreach ($line in $lines) {
    if ($line -notlike "S,*") { Assert-Equal $line.Length 22 "Every compact row is 22 characters" }
}
$decoded = @(ConvertFrom-FriendLive4 $lines)
Assert-Equal $decoded.Count $records.Count "Every record decodes"
for ($i = 0; $i -lt $records.Count; $i += 1) {
    $r = $records[$i]
    $d = $decoded[$i]
    Assert-Equal $d.epoch $r[0] "epoch row $i"
    Assert-Equal $d.session_epoch $r[1] "session row $i"
    Assert-Equal $d.hr_min $r[4] "hr_min row $i"
    Assert-Equal $d.hr_avg $r[5] "hr_avg row $i"
    Assert-Equal $d.hr_max $r[6] "hr_max row $i"
    Assert-Equal $d.motion_avg $r[8] "motion_avg row $i"
    Assert-Equal $d.motion_peak $r[9] "motion_peak row $i"
    Assert-Equal $d.moving_pct $r[10] "moving_pct row $i"
    Assert-Equal $d.steps $r[11] "steps row $i"
    Assert-Equal $d.stress $r[12] "stress row $i"
    Assert-Equal $d.body_battery $r[13] "body_battery row $i"
    Assert-Equal $d.chapter_state $r[14] "chapter_state row $i"
}

# Size: a full export at the device's export counts with realistic magnitudes
# must stay under the ~5 KB Garmin log file, with room for a few later lines.
$exportLines = @("FRIEND_EXPORT_BEGIN,4,0.4.0", "FRIEND_DEVICE,000-TEST00-00,00.00,0.0.0,1,1")
$exportLines += "FRIEND_snap_BEGIN,4"
$exportLines += @(1..4 | ForEach-Object { "1700010000,10000,900,20,8,40,50,60,70,80,900000,10,15,65,95,100000,120" })
$exportLines += @("FRIEND_snap_END", "FRIEND_session3_BEGIN,8")
$exportLines += @(1..8 | ForEach-Object {
    "1700000000,1700001800,12000,50,70,90,60,100,130,200,15000,55,10000,11000,95,100,65,90,10,1800,100,1,1700,12,90,85,250,3"
})
$exportLines += @("FRIEND_session3_END", "FRIEND_chapter3_BEGIN,10")
$exportLines += @(1..10 | ForEach-Object {
    "1700000001,1700001800,1799,1,70,60,100,130,65,200,15000,55,10000,11000,2"
})
$exportLines += @("FRIEND_chapter3_END", "FRIEND_live4_BEGIN,35")
$session = 1700000000
$many = [System.Collections.Generic.List[long[]]]::new()
for ($i = 0; $i -lt 35; $i += 1) {
    if ($i % 15 -eq 0) { $session += 4000 }   # three sessions in the window
    $many.Add([long[]]@(($session + 20 * $i), $session, 0, 120, 110, 120, 140, 50,
                        900, 24600, 100, (10000 + $i * 30), 99, 99, 1))
}
$exportLines += @(Export-CompactLiveModel $many.ToArray())
$exportLines += @("FRIEND_live4_END", "FRIEND_EXPORT_END")
$bytes = ($exportLines | ForEach-Object { $_.Length + 1 } | Measure-Object -Sum).Sum
if ($bytes -gt 4800) { throw "Format 4 export is $bytes bytes; must stay under 4800" }

# Conservative high-width case: every live row came from a separate short
# session, so every row needs its own S base line. This was over 7 KB at 90 rows.
$highSnapshot = "1700010000,200000,20000,1440,1440,100,250,250,250,100,10000000,1000,99,999,100,110000,604800"
$highSession = "1700000000,1700020000,20000,250,250,250,250,250,250,20000,96000,100,100000,200000,100,100,100,100,60,20000,100000,2,20000,1000,100,100,768,100"
$highChapter = "1700000001,1700020000,19999,1,250,250,250,250,250,20000,96000,100,100000,200000,3"
$worstPrefix = @("FRIEND_EXPORT_BEGIN,4,0.4.0", "FRIEND_DEVICE,000-TEST00-00,99.99,9.9.9,1,1", "FRIEND_snap_BEGIN,4")
$worstPrefix += @(1..4 | ForEach-Object { $highSnapshot })
$worstPrefix += @("FRIEND_snap_END", "FRIEND_session3_BEGIN,8")
$worstPrefix += @(1..8 | ForEach-Object { $highSession })
$worstPrefix += @("FRIEND_session3_END", "FRIEND_chapter3_BEGIN,10")
$worstPrefix += @(1..10 | ForEach-Object { $highChapter })
$worstPrefix += @("FRIEND_chapter3_END", "FRIEND_live4_BEGIN,35")
$worstRecords = [System.Collections.Generic.List[long[]]]::new()
for ($i = 0; $i -lt 35; $i += 1) {
    $shortSession = 1700000000 + $i * 30
    $worstRecords.Add([long[]]@(($shortSession + 20), $shortSession, 20,
        250, 250, 250, 250, 250, 20000, 96000, 100, 200000, 100, 100, 1))
}
$worstLive = @(Export-CompactLiveModel $worstRecords.ToArray())
Assert-Equal @($worstLive | Where-Object { $_ -like "S,*" }).Count 35 "Each short session needs a base line"
$worstLines = $worstPrefix + $worstLive + @("FRIEND_live4_END", "FRIEND_EXPORT_END")
$worstBytes = ($worstLines | ForEach-Object { $_.Length + 1 } | Measure-Object -Sum).Sum
if ($worstBytes -gt 4800) { throw "Worst-case format 4 export is $worstBytes bytes; must stay under 4800" }

# The reader parses the same block end to end, without headers.
$block = Get-FriendExportBlock (@("junk") + $exportLines + @("FRIEND_EXIT,1,60,40,3"))
Assert-Equal (@(Read-FriendCsvSection $block "session3")[0].hides) "3" "Session columns come from the reader"
Assert-Equal @(ConvertFrom-FriendLive4 (Get-FriendSectionLines $block "live4")).Count 35 "All live rows parse"

# Format 3 sections still parse through their own header lines.
$old = @("FRIEND_EXPORT_BEGIN,3,0.3.1", "FRIEND_session3_BEGIN,1",
         "start_epoch,end_epoch,duration_s", "1700004000,1700004750,750",
         "FRIEND_session3_END", "FRIEND_EXPORT_END")
Assert-Equal (@(Read-FriendCsvSection (Get-FriendExportBlock $old) "session3")[0].duration_s) "750" "Format 3 headers"

# The archive keeps the union of columns across formats and skips duplicates.
$archive = Join-Path ([System.IO.Path]::GetTempPath()) ("friend-archive-test-" + [guid]::NewGuid() + ".csv")
try {
    $null = Add-FriendArchive $archive @([pscustomobject]@{ start_epoch = 2; duration_s = 750 }) "start_epoch"
    $added = Add-FriendArchive $archive @(
        [pscustomobject]@{ start_epoch = 2; duration_s = 750; hides = 1 },
        [pscustomobject]@{ start_epoch = 1; duration_s = 100; hides = 3 }) "start_epoch"
    Assert-Equal $added 1 "Archive skips a row it already has"
    $rows = @(Import-Csv $archive)
    Assert-Equal $rows.Count 2 "Archive holds both sessions"
    Assert-Equal $rows[0].hides "3" "Archive keeps columns added by newer formats"
} finally {
    Remove-Item -LiteralPath $archive -ErrorAction SilentlyContinue
}

Write-Host "[pass] Friend export: compact round trip, $bytes-byte full export, $worstBytes-byte worst case, headerless parse, format 3, archive"
