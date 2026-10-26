$ErrorActionPreference = "Stop"

# Host-side acceptance model for the production-facing Walk with Friend flow.
# It deliberately models only UI/lifecycle decisions; it contains no locations,
# FIT payloads, device identifiers, or copied watch data. The Connect IQ
# implementation remains the authority for device behavior.
function New-WalkFlow {
    param(
        [bool]$FixUsable = $false,
        [bool]$SaveSucceeds = $true
    )

    return [ordered]@{
        State = "Home"
        FixUsable = $FixUsable
        SaveSucceeds = $SaveSucceeds
        GpsOn = $false
        Recording = $false
        Closed = $false
        StartCalls = 0
        StopCalls = 0
        SaveCalls = 0
        GpsStopCalls = 0
        Outcome = ""
        EndReason = ""
    }
}

function Stop-WalkGps([System.Collections.IDictionary]$Model) {
    if (-not $Model.GpsOn) { return }
    $Model.GpsOn = $false
    $Model.GpsStopCalls += 1
}

function Start-WalkRecording([System.Collections.IDictionary]$Model) {
    if ($Model.Recording) { return }
    $Model.Recording = $true
    $Model.StartCalls += 1
    $Model.State = "Recording"
}

function Finish-WalkRecording {
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary]$Model,
        [Parameter(Mandatory)] [ValidateSet("Select", "Closed")] [string]$Reason
    )

    # Saving and system-close callbacks may race or be repeated. Only a live
    # recording is allowed to stop/save once.
    if (-not $Model.Recording) { return }
    $Model.Recording = $false
    $Model.StopCalls += 1
    $Model.SaveCalls += 1
    $Model.EndReason = $Reason
    $Model.Outcome = if ($Model.SaveSucceeds) { "Saved" } else { "SaveFailed" }
    $Model.State = "Result"
    Stop-WalkGps $Model
}

function Invoke-WalkAction {
    param(
        [Parameter(Mandatory)] [System.Collections.IDictionary]$Model,
        [Parameter(Mandatory)]
        [ValidateSet("Select", "Back", "Fix", "SystemClose")]
        [string]$Action
    )

    if ($Action -eq "SystemClose") {
        if ($Model.Closed) { return }
        if ($Model.Recording) {
            Finish-WalkRecording $Model "Closed"
        } else {
            Stop-WalkGps $Model
        }
        $Model.State = "Exited"
        $Model.Closed = $true
        return
    }

    if ($Model.Closed) { return }

    if ($Action -eq "Fix") {
        $Model.FixUsable = $true
        return
    }

    if ($Action -eq "Select") {
        switch ($Model.State) {
            "Home" {
                $Model.State = "Ready"
                $Model.GpsOn = $true
            }
            "Ready" {
                # Recording begins immediately. If GPS has no fix yet, the route
                # begins when the first position arrives; there is no hidden
                # double-press confirmation grammar.
                Start-WalkRecording $Model
            }
            "Recording" { $Model.State = "EndPrompt" }
            "EndPrompt" { Finish-WalkRecording $Model "Select" }
            "Result" { $Model.State = "Home" }
        }
        return
    }

    # Back is always navigation/cancel. It never silently saves or discards.
    switch ($Model.State) {
        "Home" {
            $Model.State = "Exited"
            $Model.Closed = $true
        }
        "Ready" {
            Stop-WalkGps $Model
            $Model.State = "Home"
        }
        "Recording" { $Model.State = "EndPrompt" }
        "EndPrompt" { $Model.State = "Recording" }
        "Result" {
            $Model.State = "Home"
        }
    }
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

# Normal path: ready -> start -> end prompt -> resume -> save.
$walk = New-WalkFlow
Invoke-WalkAction $walk Select
Assert-Equal $walk.State "Ready" "Select from Home should enter GPS-ready mode"
Assert-Equal $walk.GpsOn $true "Ready mode should warm GPS"
Assert-Equal $walk.StartCalls 0 "Entering Ready must not start a recording"

Invoke-WalkAction $walk Fix
Invoke-WalkAction $walk Select
Assert-Equal $walk.State "Recording" "Select with a usable fix should start"
Assert-Equal $walk.StartCalls 1 "A walk should start exactly once"

Invoke-WalkAction $walk Select
Assert-Equal $walk.State "EndPrompt" "Select while walking should ask before ending"
Assert-Equal $walk.Recording $true "The end prompt should not create a route gap"
Assert-Equal $walk.SaveCalls 0 "Opening the end prompt must not save"

Invoke-WalkAction $walk Back
Assert-Equal $walk.State "Recording" "Back at the end prompt should resume"
Assert-Equal $walk.StopCalls 0 "Resume must not stop the recording"

Invoke-WalkAction $walk Back
Assert-Equal $walk.State "EndPrompt" "Back while recording should ask before ending"
Assert-Equal $walk.SaveCalls 0 "Back while recording must not silently save"
Invoke-WalkAction $walk Select
Assert-Equal $walk.State "Result" "Confirming the default end action should show a result"
Assert-Equal $walk.Outcome "Saved" "A successful save should be labelled Saved"
Assert-Equal $walk.EndReason "Select" "A confirmed user save should retain its reason"
Assert-Equal $walk.StopCalls 1 "Confirmed end should stop once"
Assert-Equal $walk.SaveCalls 1 "Confirmed end should save once"
Assert-Equal $walk.GpsOn $false "A finished walk should release GPS"
Invoke-WalkAction $walk Back
Assert-Equal $walk.State "Home" "Back from the walk result should return Home"
Invoke-WalkAction $walk Back
Assert-Equal $walk.State "Exited" "A second Back from Home should exit"

# No fix is not a gate: Ready START records now and the route starts at the
# first later fix, matching the proven probe behavior.
$noFix = New-WalkFlow
Invoke-WalkAction $noFix Select
Invoke-WalkAction $noFix Select
Assert-Equal $noFix.State "Recording" "Ready START should record without waiting for a fix"
Assert-Equal $noFix.FixUsable $false "Starting must not invent a GPS fix"
Assert-Equal $noFix.StartCalls 1 "One Ready START should start exactly once"

# Back from preparation cancels GPS preparation; Back from Home exits.
$cancel = New-WalkFlow
Invoke-WalkAction $cancel Select
Invoke-WalkAction $cancel Back
Assert-Equal $cancel.State "Home" "Back from Ready should return Home"
Assert-Equal $cancel.GpsStopCalls 1 "Cancelling Ready should release GPS once"
Invoke-WalkAction $cancel Back
Assert-Equal $cancel.State "Exited" "Back from Home should exit"
Assert-Equal $cancel.SaveCalls 0 "Cancelling before start must not create an activity"

# Save failure is explicit and is never presented as Saved. A later close must
# not retry a stopped session or create a duplicate activity.
$failed = New-WalkFlow -FixUsable $true -SaveSucceeds $false
Invoke-WalkAction $failed Select
Invoke-WalkAction $failed Select
Invoke-WalkAction $failed Back
Invoke-WalkAction $failed Select
Assert-Equal $failed.Outcome "SaveFailed" "A false save result must remain visible"
Assert-Equal $failed.StopCalls 1 "A failed save should still stop once"
Assert-Equal $failed.SaveCalls 1 "A failed save should be attempted once"
Invoke-WalkAction $failed Back
Assert-Equal $failed.State "Home" "Back from a failed result should return Home"
Invoke-WalkAction $failed SystemClose
Assert-Equal $failed.SaveCalls 1 "Closing after a failed save must not retry it"

# An OS close during either recording or its end prompt attempts save once with
# CLOSED. This models lifecycle idempotency only: FR265 T20 showed that a true
# close can still lose the FIT even when Session.save() returns true.
$closed = New-WalkFlow -FixUsable $true
Invoke-WalkAction $closed Select
Invoke-WalkAction $closed Select
Invoke-WalkAction $closed Back
Invoke-WalkAction $closed SystemClose
Invoke-WalkAction $closed SystemClose
Assert-Equal $closed.State "Exited" "System close should leave the flow exited"
Assert-Equal $closed.Outcome "Saved" "System close should retain the mocked save return"
Assert-Equal $closed.EndReason "Closed" "System close should retain its distinct reason"
Assert-Equal $closed.StopCalls 1 "Repeated close should stop at most once"
Assert-Equal $closed.SaveCalls 1 "Repeated close should save at most once"
Assert-Equal $closed.GpsStopCalls 1 "Repeated close should release GPS at most once"

# Closing from Ready cleans up but must not invent a recording.
$readyClose = New-WalkFlow
Invoke-WalkAction $readyClose Select
Invoke-WalkAction $readyClose SystemClose
Invoke-WalkAction $readyClose SystemClose
Assert-Equal $readyClose.StartCalls 0 "Closing from Ready must not start"
Assert-Equal $readyClose.SaveCalls 0 "Closing from Ready must not save"
Assert-Equal $readyClose.GpsStopCalls 1 "Repeated Ready close should clean GPS once"

Write-Host "[pass] Friend walk flow: ready, immediate start, end prompt, resume, save/fail, Back, idempotent close"
