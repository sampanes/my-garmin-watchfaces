param(
    [string]$SdkPath,
    [string]$DeveloperKey,
    [switch]$OpenFolders
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$jungle = Join-Path $repo "garmin-pet\probes\wrist-diary\monkey.jungle"
$outDir = Join-Path $repo "bin\wrist-diary"
$outPrg = Join-Path $outDir "wrist-diary-fr265.prg"

if (-not $SdkPath) {
    $sdkRoot = Join-Path $env:APPDATA "Garmin\ConnectIQ\Sdks"
    $sdk = Get-ChildItem -Path $sdkRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $sdk) {
        throw "Could not find a Connect IQ SDK under $sdkRoot. Pass -SdkPath."
    }
    $SdkPath = $sdk.FullName
}

$monkeyc = Join-Path $SdkPath "bin\monkeyc.bat"
if (-not (Test-Path $monkeyc)) {
    throw "Could not find monkeyc.bat at $monkeyc"
}

if (-not $DeveloperKey) {
    if ($env:MONKEYC_DEVELOPER_KEY) {
        $DeveloperKey = $env:MONKEYC_DEVELOPER_KEY
    } else {
        $DeveloperKey = Join-Path $env:USERPROFILE "MonkeyC\developer_key"
    }
}

if (-not (Test-Path $DeveloperKey)) {
    throw "Could not find developer key at $DeveloperKey. Pass -DeveloperKey or set MONKEYC_DEVELOPER_KEY."
}

New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host "[build] fr265 -> $outPrg"
& $monkeyc -o $outPrg -f $jungle -y $DeveloperKey -d fr265 -w -l 2
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "[done] $outPrg"

if ($OpenFolders) {
    Start-Process explorer.exe $outDir
    Start-Process explorer.exe "shell:MyComputerFolder"
}
