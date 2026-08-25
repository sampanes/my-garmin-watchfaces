$ErrorActionPreference = "Stop"

# Host-side acceptance model for Friend's intentionally small bucket state machine.
# A bucket is one 20-second HR/motion summary. This guards the behavior contract;
# the Connect IQ compiler remains the authority for the device implementation.
function Invoke-ChapterModel {
    param(
        [Parameter(Mandatory)] [array]$Buckets,
        [switch]$BackAtEnd
    )

    $bits = 0
    $bucketCount = 0
    $active = $false
    $age = 0
    $start = 0
    $lastStrong = 0
    $chapters = @()

    function Count-Recent([int]$Window) {
        $copy = $bits
        $count = 0
        $available = [Math]::Min($bucketCount, $Window)
        for ($i = 0; $i -lt $available; $i += 1) {
            $count += $copy % 2
            $copy = [Math]::Floor($copy / 2)
        }
        return $count
    }

    for ($index = 0; $index -lt $Buckets.Count; $index += 1) {
        $bucket = $Buckets[$index]
        $strong = ($bucket.hr_delta -ge 10) -or
                  ($bucket.moving_pct -ge 30) -or
                  ($bucket.motion_avg -ge 120)
        $bits = ($bits * 2 + $(if ($strong) { 1 } else { 0 })) % 256
        $bucketCount += 1
        $now = ($index + 1) * 20

        if (-not $active) {
            if ($strong -and (Count-Recent 3) -ge 2) {
                $active = $true
                $age = 0
                $start = [Math]::Max(0, $now - 40)
                $lastStrong = $now
            }
            continue
        }

        $age += 1
        if ($strong) { $lastStrong = $now }
        if ($age -ge 8 -and (Count-Recent 8) -le 2) {
            $chapters += [pscustomobject]@{
                duration_s = [Math]::Max(20, $lastStrong - $start)
                partial = 0
            }
            $active = $false
            $bits = 0
        }
    }

    if ($BackAtEnd -and $active) {
        $chapters += [pscustomobject]@{
            duration_s = [Math]::Max(20, $lastStrong - $start)
            partial = 1
        }
    }
    return @($chapters)
}

function New-Bucket([int]$HrDelta, [int]$Motion, [int]$Moving) {
    return [pscustomobject]@{
        hr_delta = $HrDelta
        motion_avg = $Motion
        moving_pct = $Moving
    }
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

$quiet = New-Bucket 3 45 8
$motion = New-Bucket 4 180 45
$heartOnly = New-Bucket 14 35 4

$isolated = @($quiet, $motion) + @($quiet) * 10
Assert-Equal (Invoke-ChapterModel $isolated).Count 0 "One gesture must not open a chapter"

$pullupsThenDesk = @($motion) * 15 + @($quiet) * 60
$chapters = @(Invoke-ChapterModel $pullupsThenDesk)
Assert-Equal $chapters.Count 1 "Sustained effort plus desk tail should make one chapter"
Assert-Equal $chapters[0].duration_s 300 "Desk tail must be excluded from chapter duration"
Assert-Equal $chapters[0].partial 0 "Quiet-closed chapter should be complete"

$wristStillEffort = @($heartOnly) * 8 + @($quiet) * 10
$chapters = @(Invoke-ChapterModel $wristStillEffort)
Assert-Equal $chapters.Count 1 "HR-only stationary effort should be retained"

$backDuringEffort = @($motion) * 5
$chapters = @(Invoke-ChapterModel $backDuringEffort -BackAtEnd)
Assert-Equal $chapters.Count 1 "Back should retain the active chapter"
Assert-Equal $chapters[0].partial 1 "Back-retained chapter should be marked partial"

Write-Host "[pass] Friend chapter behavior: isolated gesture, desk tail, HR-only, Back partial"
