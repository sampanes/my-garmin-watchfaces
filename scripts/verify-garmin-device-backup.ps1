[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BackupPath,
    [ValidateRange(1, 1440)]
    [int]$TimeoutMinutes = 30
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "backup-garmin-device.ps1")

$resolved = (Resolve-Path -LiteralPath $BackupPath).Path
$manifestPath = Join-Path $resolved "manifest.json"
$dataRoot = Join-Path $resolved "Internal Storage"
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw "manifest.json was not found in '$resolved'."
}
if (-not (Test-Path -LiteralPath $dataRoot -PathType Container)) {
    throw "Internal Storage was not found in '$resolved'."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if ([int]$manifest.schema_version -ne 1) {
    throw "Unsupported backup manifest schema '$($manifest.schema_version)'."
}
if ([string]$manifest.backup_status -cne "complete") {
    throw "The backup is not complete (status: '$($manifest.backup_status)')."
}
if ($null -ne $manifest.failure) {
    throw "A completed backup must not contain a failure record."
}
if ([int]$manifest.file_count -ne @($manifest.files).Count) {
    throw "The file count does not match the manifest file list."
}
if ([int]$manifest.directory_count -ne @($manifest.directories).Count) {
    throw "The directory count does not match the manifest directory list."
}
if ([int]$manifest.verified_file_count -ne [int]$manifest.file_count) {
    throw "Not every manifest file was marked verified."
}
foreach ($file in $manifest.files) {
    if ([string]$file.status -cne "verified") {
        throw "Manifest file '$($file.relative_path)' is not marked verified."
    }
    if ([string]$file.sha256 -cnotmatch '^[0-9a-f]{64}$') {
        throw "Manifest file '$($file.relative_path)' has an invalid SHA-256 digest."
    }
}

$deadline = [DateTime]::UtcNow.AddMinutes($TimeoutMinutes)
Assert-BackupDataTree $dataRoot $manifest $deadline

Write-Host ("[pass] Verified Garmin backup: {0} files, {1} directories, {2} bytes" -f `
    $manifest.file_count, $manifest.directory_count, $manifest.total_source_bytes)
Write-Host "[backup] $resolved"
