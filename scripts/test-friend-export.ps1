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

# Real live3 records from the 2026-10-16 export, plus edge cases: missing HR,
# a motion peak past 3 digits, steps going backwards (midnight), missing stress.
$records = [long[][]]@(
    @(1792169101, 1792169060, 40, 102, 98, 101, 102, 32, 407, 3049, 95, 1075, -1, 74, 1),
    @(1792169121, 1792169060, 60, -1, -1, -1, -1, -1, 388, 3332, 78, 1079, 21, 48, 0),
    @(1792169141, 1792169060, 80, 120, 117, 119, 121, 50, 408, 24600, 84, 1193, 99, 72, 1),
    @(1792169161, 1792169060, 100, 113, 113, 113, 114, 44, 238, 1926, 63, 1263, 99, -1, 1),
    @(1792171443, 1792171163, 280, 112, 112, 112, 112, 38, 264, 6153, 58, 1705, -1, 68, 1),
    @(1792171463, 1792171163, 300, 99, 98, 99, 101, 25, 148, 745, 48, 12, -1, 68, 1),
    @(1792171483, 1792171163, 320, 99, 98, 99, 101, 25, 148, 745, 48, 40, 60, 68, 0)
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
$exportLines = @("FRIEND_EXPORT_BEGIN,4,0.4.0", "FRIEND_DEVICE,006-B4257-00,27.09,5.2.0")
$exportLines += "FRIEND_snap_BEGIN,4"
$exportLines += @(1..4 | ForEach-Object { "1792172519,11949,1052,22,11,51,57,77,131,74,1155182,12" })
$exportLines += @("FRIEND_snap_END", "FRIEND_session3_BEGIN,8")
$exportLines += @(1..8 | ForEach-Object {
    "1792169060,1792170899,11838,53,69,94,66,109,141,253,17351,59,10998,11705,100,100,74,100,12,1838,125,2,1838,14,100,97,312,3"
})
$exportLines += @("FRIEND_session3_END", "FRIEND_chapter3_BEGIN,10")
$exportLines += @(1..10 | ForEach-Object {
    "1792169061,1792170899,1838,1,69,66,109,141,67,251,17351,58,11075,11705,3"
})
$exportLines += @("FRIEND_chapter3_END", "FRIEND_live4_BEGIN,90")
$session = 1792169060
$many = [System.Collections.Generic.List[long[]]]::new()
for ($i = 0; $i -lt 90; $i += 1) {
    if ($i % 30 -eq 0) { $session += 4000 }   # three sessions in the window
    $many.Add([long[]]@(($session + 20 * $i), $session, 0, 120, 110, 120, 140, 50,
                        900, 24600, 100, (10000 + $i * 30), 99, 99, 1))
}
$exportLines += @(Export-CompactLiveModel $many.ToArray())
$exportLines += @("FRIEND_live4_END", "FRIEND_EXPORT_END")
$bytes = ($exportLines | ForEach-Object { $_.Length + 1 } | Measure-Object -Sum).Sum
if ($bytes -gt 4800) { throw "Format 4 export is $bytes bytes; must stay under 4800" }

# The reader parses the same block end to end, without headers.
$block = Get-FriendExportBlock (@("junk") + $exportLines + @("FRIEND_EXIT,1,60,40,3"))
Assert-Equal (@(Read-FriendCsvSection $block "session3")[0].hides) "3" "Session columns come from the reader"
Assert-Equal @(ConvertFrom-FriendLive4 (Get-FriendSectionLines $block "live4")).Count 90 "All live rows parse"

# Format 3 sections still parse through their own header lines.
$old = @("FRIEND_EXPORT_BEGIN,3,0.3.1", "FRIEND_session3_BEGIN,1",
         "start_epoch,end_epoch,duration_s", "1792171163,1792171914,750",
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

Write-Host "[pass] Friend export: compact round trip, $bytes-byte full export, headerless parse, format 3, archive"
