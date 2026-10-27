# Runs the Python watch tools in scripts/watch with their own virtual environment
# (.venv at the repo root, rebuilt when requirements.txt changes).
#
#   .\scripts\watch-tools.ps1 settings [backup-folder]   inventory + diff vs the previous backup
#   .\scripts\watch-tools.ps1 check                      validate scripts/watch/workouts/*.toml
#   .\scripts\watch-tools.ps1 find squat                 search Garmin's exercise catalog
#   .\scripts\watch-tools.ps1 show "Mat basics"          the JSON Garmin Connect would receive
#   .\scripts\watch-tools.ps1 push [name...]             create/update in Garmin Connect, send to the watch
#   .\scripts\watch-tools.ps1 push --schedule 2026-10-27 put them on the calendar instead
#   .\scripts\watch-tools.ps1 snapshot                   save what Garmin Connect holds (read-only)
#   .\scripts\watch-tools.ps1 recover --wiped 2026-10-26 settings inside activities before/after a wipe
#   .\scripts\watch-tools.ps1 apply [file]               diff bin\watch-setup.toml vs Garmin Connect
#   .\scripts\watch-tools.ps1 apply --yes                ...and write the differences
#   .\scripts\watch-tools.ps1 test                       host tests
param(
    [Parameter(Position = 0)]
    [ValidateSet("settings", "check", "find", "show", "push", "snapshot", "recover", "apply", "test")]
    [string]$Command = "check",
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$Rest = @()
)

$ErrorActionPreference = "Stop"
$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$tools = Join-Path $PSScriptRoot "watch"
$venv = Join-Path $repo ".venv"
$python = Join-Path $venv "Scripts\python.exe"
$requirements = Join-Path $tools "requirements.txt"
$stamp = Join-Path $venv "requirements.sha256"

$wanted = (Get-FileHash -LiteralPath $requirements).Hash
$installed = if (Test-Path -LiteralPath $stamp) { (Get-Content -LiteralPath $stamp -Raw).Trim() } else { "" }
if (-not (Test-Path -LiteralPath $python) -or $installed -ne $wanted) {
    $base = $null
    foreach ($candidate in @(@("py", "-3"), @("python"))) {
        if (Get-Command $candidate[0] -ErrorAction SilentlyContinue) { $base = $candidate; break }
    }
    if (-not $base) { throw "Python 3.12 or newer is needed (garminconnect requires it). Install it from python.org." }
    $baseArgs = @($base | Select-Object -Skip 1)
    & $base[0] @baseArgs -c "import sys; sys.exit(0 if sys.version_info >= (3, 12) else 1)"
    if ($LASTEXITCODE -ne 0) { throw "Python 3.12 or newer is needed (garminconnect requires it)." }
    Write-Host "[setup] Creating $venv"
    & $base[0] @baseArgs -m venv $venv
    if ($LASTEXITCODE -ne 0) { throw "Could not create $venv" }
    & $python -m pip install --quiet --disable-pip-version-check -r $requirements
    if ($LASTEXITCODE -ne 0) { throw "pip could not install $requirements" }
    Set-Content -LiteralPath $stamp -Value $wanted -Encoding ascii
}

switch ($Command) {
    "settings" { & $python -I (Join-Path $tools "settings_inventory.py") @Rest }
    { $_ -in @("snapshot", "recover", "apply") } { & $python -I (Join-Path $tools "connect_setup.py") $Command @Rest }
    "test" { & $python -I (Join-Path $tools "test_watch_tools.py") @Rest }
    default { & $python -I (Join-Path $tools "workouts.py") $Command @Rest }
}
exit $LASTEXITCODE
