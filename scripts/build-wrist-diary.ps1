param(
    [string]$SdkPath,
    [string]$DeveloperKey,
    [switch]$OpenFolders
)

Write-Warning "Wrist Diary has become Friend; forwarding to build-friend.ps1."
& (Join-Path $PSScriptRoot "build-friend.ps1") @PSBoundParameters
