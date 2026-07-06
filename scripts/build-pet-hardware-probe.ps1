param(
    [ValidateSet("fr265", "fr265s", "vivoactive6")]
    [string]$Device = "fr265",

    [string]$SdkPath,

    [string]$DeveloperKey,

    [switch]$OpenFolders
)

$ErrorActionPreference = "Stop"

$repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$jungle = Join-Path $repo "garmin-pet\probes\hardware\monkey.jungle"
$outDir = Join-Path $repo "bin\hardware-probes"
$outPrg = Join-Path $outDir "pet-hardware-probe-$Device.prg"

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

Write-Host "[build] $Device -> $outPrg"
& $monkeyc -o $outPrg -f $jungle -y $DeveloperKey -d $Device -w -l 2
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

Write-Host "[done] $outPrg"
Write-Host "[copy] Plug the watch in, open GARMIN\Apps, and copy this .prg there."

if ($OpenFolders) {
    Start-Process explorer.exe $outDir
    Start-Process explorer.exe "shell:MyComputerFolder"
}
