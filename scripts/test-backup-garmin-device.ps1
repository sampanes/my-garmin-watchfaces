$ErrorActionPreference = "Stop"
Set-StrictMode -Version 2.0

. (Join-Path $PSScriptRoot "backup-garmin-device.ps1")

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Equal($Actual, $Expected, [string]$Message) {
    if ($Actual -ne $Expected) {
        throw "$Message (expected=$Expected actual=$Actual)"
    }
}

function Assert-Throws([scriptblock]$Action, [string]$Message) {
    $threw = $false
    try { & $Action } catch { $threw = $true }
    if (-not $threw) { throw $Message }
}

function New-FakeShell([string]$FailName = "", [switch]$DoNotCopy) {
    $shell = [pscustomobject]@{
        FailName = $FailName
        DoNotCopy = [bool]$DoNotCopy
        CopyCount = 0
    }
    $shell | Add-Member -MemberType ScriptMethod -Name Namespace -Value {
        param([string]$Path)
        $namespace = [pscustomobject]@{ Path = $Path; Owner = $this }
        $namespace | Add-Member -MemberType ScriptMethod -Name CopyHere -Value {
            param($SourceItem, [int]$Flags)
            $this.Owner.CopyCount += 1
            if ($SourceItem.Name -eq $this.Owner.FailName) { throw "synthetic copy failure" }
            if ($this.Owner.DoNotCopy) { return }
            [IO.File]::Copy($SourceItem.LocalPath, (Join-Path $this.Path $SourceItem.Name), $false)
        }
        return $namespace
    }
    return $shell
}

function New-TestInventory([string]$SourceRoot) {
    $files = @()
    foreach ($definition in @(
        @{ Relative = "root.bin"; Name = "root.bin"; Bytes = [byte[]](0, 1, 2, 3, 255) },
        @{ Relative = "Nested/hello.txt"; Name = "hello.txt"; Bytes = [Text.Encoding]::UTF8.GetBytes("hello`n") },
        @{ Relative = "Unicode/cafe.txt"; Name = "cafe.txt"; Bytes = [Text.Encoding]::UTF8.GetBytes(("caf" + [char]0x00E9)) },
        @{ Relative = "Nested/zero.dat"; Name = "zero.dat"; Bytes = [byte[]]@() }
    )) {
        $sourcePath = Join-Path $SourceRoot $definition.Name
        [IO.File]::WriteAllBytes($sourcePath, $definition.Bytes)
        $sourceItem = [pscustomobject]@{ LocalPath = $sourcePath; Name = $definition.Name }
        $files += [pscustomobject]@{
            RelativePath = $definition.Relative
            Name = $definition.Name
            SourceSize = [UInt64]$definition.Bytes.Length
            SourceModifiedUtc = "2026-10-26T12:00:00.0000000Z"
            SourceItem = $sourceItem
        }
    }
    return [pscustomobject]@{
        Directories = @(
            [pscustomobject]@{ RelativePath = "Empty"; SourceModifiedUtc = $null },
            [pscustomobject]@{ RelativePath = "Nested"; SourceModifiedUtc = $null },
            [pscustomobject]@{ RelativePath = "Unicode"; SourceModifiedUtc = $null }
        )
        Files = $files
    }
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("garmin-backup-test-" + [guid]::NewGuid().ToString("N"))
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
$resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
if (-not $resolvedTestRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create the test outside the temporary directory."
}

New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $sourceRoot = Join-Path $testRoot "source"
    New-Item -ItemType Directory -Path $sourceRoot | Out-Null
    $inventory = New-TestInventory $sourceRoot

    $partial = Join-Path $testRoot "success.partial"
    $completed = Join-Path $testRoot "success"
    New-Item -ItemType Directory -Path $partial | Out-Null
    $manifest = New-BackupManifest "Fake Garmin" (Get-UtcTimestamp)
    Write-BackupManifest $manifest (Join-Path $partial "manifest.json")
    $shell = New-FakeShell
    $result = Invoke-BackupPlan $shell $inventory $manifest $partial $completed 3 50 ([DateTime]::UtcNow.AddMinutes(2))

    Assert-Equal $result $completed "Successful backup returns its completed directory"
    Assert-True (Test-Path -LiteralPath $completed -PathType Container) "Completed directory was not created"
    Assert-True (-not (Test-Path -LiteralPath $partial)) "Partial directory remained after success"
    Assert-True (Test-Path -LiteralPath (Join-Path $completed "Internal Storage\Empty") -PathType Container) "Empty directory was not preserved"
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $completed ".copy-staging"))) "Staging directory leaked into completed backup"
    Assert-Equal $shell.CopyCount $inventory.Files.Count "Files were not copied exactly once"

    $savedManifest = Get-Content -LiteralPath (Join-Path $completed "manifest.json") -Raw | ConvertFrom-Json
    Assert-Equal $savedManifest.backup_status "complete" "Manifest was not marked complete"
    Assert-Equal $savedManifest.verified_file_count $inventory.Files.Count "Manifest verified count"
    foreach ($entry in $savedManifest.files) {
        Assert-Equal $entry.status "verified" "Every file must be verified"
        Assert-True (-not [string]::IsNullOrWhiteSpace([string]$entry.sha256)) "A file lacks a SHA-256 digest"
        Assert-True ([string]$entry.verified_at_utc -match 'Z$') "Per-file verification timestamp is not UTC"
    }

    $tampered = Join-Path $completed "Internal Storage\root.bin"
    [IO.File]::WriteAllBytes($tampered, [byte[]](9, 9, 9, 9, 9))
    Assert-Throws {
        Assert-BackupDataTree (Join-Path $completed "Internal Storage") $savedManifest ([DateTime]::UtcNow.AddMinutes(1))
    } "Tampering was not detected by SHA-256 readback"

    $failurePartial = Join-Path $testRoot "failure.partial"
    $failureCompleted = Join-Path $testRoot "failure"
    New-Item -ItemType Directory -Path $failurePartial | Out-Null
    $failureManifest = New-BackupManifest "Fake Garmin" (Get-UtcTimestamp)
    Write-BackupManifest $failureManifest (Join-Path $failurePartial "manifest.json")
    $failingShell = New-FakeShell -FailName "hello.txt"
    Assert-Throws {
        Invoke-BackupPlan $failingShell $inventory $failureManifest $failurePartial $failureCompleted 3 50 ([DateTime]::UtcNow.AddMinutes(2))
    } "Synthetic copy failure did not fail the backup"
    Assert-True (Test-Path -LiteralPath $failurePartial -PathType Container) "Failed backup did not retain its partial directory"
    Assert-True (-not (Test-Path -LiteralPath $failureCompleted)) "Failed backup created a completed directory"
    $failedManifest = Get-Content -LiteralPath (Join-Path $failurePartial "manifest.json") -Raw | ConvertFrom-Json
    Assert-Equal $failedManifest.backup_status "failed" "Failed manifest status"

    Assert-Throws {
        Get-SafeDestinationPath (Join-Path $testRoot "safe") "../escape.txt"
    } "Path traversal was accepted"

    $collisionManifest = New-BackupManifest "Fake Garmin" (Get-UtcTimestamp)
    $collisionInventory = [pscustomobject]@{
        Directories = @([pscustomobject]@{ RelativePath = "Data"; SourceModifiedUtc = $null })
        Files = @([pscustomobject]@{
            RelativePath = "data"; Name = "data"; SourceSize = [UInt64]0
            SourceModifiedUtc = $null; SourceItem = [pscustomobject]@{}
        })
    }
    Assert-Throws {
        Initialize-ManifestInventory $collisionManifest $collisionInventory
    } "Case-insensitive path collision was accepted"

    $missingSizeItem = [pscustomobject]@{}
    $missingSizeItem | Add-Member -MemberType ScriptMethod -Name ExtendedProperty -Value { param($Name) return $null }
    Assert-Throws {
        Get-MtpFileSize $missingSizeItem "unknown.bin"
    } "Missing source byte count was accepted"

    $rawMtpTime = [DateTime]::SpecifyKind(
        [DateTime]::ParseExact("2026-10-26 15:30:32", "yyyy-MM-dd HH:mm:ss", [Globalization.CultureInfo]::InvariantCulture),
        [DateTimeKind]::Unspecified
    )
    Assert-Equal (Convert-MtpDateToUtc $rawMtpTime) "2026-10-26T15:30:32.0000000Z" `
        "Unspecified MTP timestamps must retain their UTC clock value"

    Write-Host "[pass] Garmin backup: full tree, empty/zero-byte files, manifest, SHA-256 tamper detection, partial failure, path safety"
} finally {
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
