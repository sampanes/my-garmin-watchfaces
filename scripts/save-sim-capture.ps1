[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [int]$FocusDelayMs = 500,
    [int]$MenuDelayMs = 300,
    [int]$DialogDelayMs = 1000,
    [int]$SaveTimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    throw 'The capture helper must run in an STA PowerShell process.'
}

Add-Type -AssemblyName System.Windows.Forms

if (-not ('SimCapture.NativeWindow' -as [type])) {
    $nativeMethods = @'
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(IntPtr hWnd);

[DllImport("user32.dll")]
public static extern IntPtr GetForegroundWindow();

[DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
'@
    Add-Type -MemberDefinition $nativeMethods -Name NativeWindow -Namespace SimCapture -ErrorAction Stop
}

function Get-SimulatorWindow {
    $windows = @(Get-Process -Name simulator -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 })

    if ($windows.Count -eq 0) {
        throw 'No CIQ Simulator window was found. Start the simulator and try again.'
    }
    if ($windows.Count -ne 1) {
        $details = $windows | ForEach-Object { "PID $($_.Id): $($_.MainWindowTitle)" }
        throw "Expected one CIQ Simulator window, found $($windows.Count): $($details -join '; ')"
    }
    return $windows[0]
}

function Assert-SimulatorForeground($Process) {
    if ([SimCapture.NativeWindow]::GetForegroundWindow() -ne $Process.MainWindowHandle) {
        throw 'The CIQ Simulator lost focus; capture was aborted before sending more keys.'
    }
}

function Assert-SimulatorOwnsForeground($Process) {
    $foregroundWindow = [SimCapture.NativeWindow]::GetForegroundWindow()
    $foregroundProcessId = [uint32]0
    [SimCapture.NativeWindow]::GetWindowThreadProcessId(
        $foregroundWindow,
        [ref]$foregroundProcessId
    ) | Out-Null

    if ($foregroundProcessId -ne [uint32]$Process.Id) {
        throw 'The CIQ Simulator lost focus; capture was aborted before sending more keys.'
    }
}

function Copy-ClipboardData {
    $source = [Windows.Forms.Clipboard]::GetDataObject()
    if ($null -eq $source) { return $null }

    $copy = New-Object Windows.Forms.DataObject
    foreach ($format in $source.GetFormats($false)) {
        $copy.SetData($format, $false, $source.GetData($format, $false))
    }
    return $copy
}

$resolvedOutputPath = [IO.Path]::GetFullPath($OutputPath)
$outputDirectory = [IO.Path]::GetDirectoryName($resolvedOutputPath)
if ([string]::IsNullOrWhiteSpace($outputDirectory)) {
    throw "Could not determine the output directory from: $OutputPath"
}
if (Test-Path -LiteralPath $resolvedOutputPath) {
    throw "Refusing to mistake an old capture for a new one: $resolvedOutputPath"
}

$simulator = Get-SimulatorWindow
$shell = New-Object -ComObject WScript.Shell

[SimCapture.NativeWindow]::ShowWindow($simulator.MainWindowHandle, 9) | Out-Null
Start-Sleep -Milliseconds 600
[SimCapture.NativeWindow]::SetForegroundWindow($simulator.MainWindowHandle) | Out-Null
if (-not $shell.AppActivate([int]$simulator.Id)) {
    throw "Could not activate CIQ Simulator PID $($simulator.Id)."
}
Start-Sleep -Milliseconds $FocusDelayMs
Assert-SimulatorForeground $simulator

if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$savedClipboard = Copy-ClipboardData
$hadClipboard = $null -ne $savedClipboard
$captureStartedUtc = [DateTime]::UtcNow
try {
    [Windows.Forms.Clipboard]::SetText($resolvedOutputPath)

    $shell.SendKeys('%F')
    Start-Sleep -Milliseconds $MenuDelayMs
    Assert-SimulatorForeground $simulator
    $shell.SendKeys('S')
    Start-Sleep -Milliseconds $DialogDelayMs

    Assert-SimulatorOwnsForeground $simulator
    $shell.SendKeys('^a')
    Start-Sleep -Milliseconds $MenuDelayMs
    Assert-SimulatorOwnsForeground $simulator
    $shell.SendKeys('^v')
    Start-Sleep -Milliseconds $MenuDelayMs
    Assert-SimulatorOwnsForeground $simulator
    $shell.SendKeys('{ENTER}')
} finally {
    if ($hadClipboard) {
        [Windows.Forms.Clipboard]::SetDataObject($savedClipboard, $true)
    } else {
        [Windows.Forms.Clipboard]::Clear()
    }
}

$deadline = [DateTime]::UtcNow.AddSeconds($SaveTimeoutSeconds)
$stablePolls = 0
$captureVerified = $false
while ([DateTime]::UtcNow -lt $deadline) {
    if (Test-Path -LiteralPath $resolvedOutputPath -PathType Leaf) {
        $file = Get-Item -LiteralPath $resolvedOutputPath
        if ($file.Length -gt 0 -and $file.LastWriteTimeUtc -ge $captureStartedUtc.AddSeconds(-1)) {
            $stablePolls += 1
            if ($stablePolls -ge 2) {
                $captureVerified = $true
                break
            }
        } else {
            $stablePolls = 0
        }
    }
    Start-Sleep -Milliseconds 250
}

if (-not $captureVerified) {
    throw "A new capture file did not appear within $SaveTimeoutSeconds seconds: $resolvedOutputPath"
}

Write-Output $resolvedOutputPath
