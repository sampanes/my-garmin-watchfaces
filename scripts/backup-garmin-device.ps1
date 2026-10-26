[CmdletBinding()]
param(
    [string]$DeviceName = "Forerunner 265",
    [string]$OutputRoot = "",
    [ValidateRange(1, 3600)]
    [int]$CopyTimeoutSeconds = 300,
    [ValidateRange(1, 300)]
    [int]$DiscoveryTimeoutSeconds = 20,
    [ValidateRange(50, 5000)]
    [int]$PollMilliseconds = 250,
    [ValidateRange(1, 1440)]
    [int]$OverallTimeoutMinutes = 120,
    [ValidateRange(1, 1000000)]
    [int]$MaxItems = 250000,
    [ValidateRange(1, 256)]
    [int]$MaxDepth = 128,
    [switch]$SkipSettingsInventory
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$BackupScriptDirectory = if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) {
    $PSScriptRoot
} else {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}

function Get-UtcTimestamp {
    return [DateTime]::UtcNow.ToString("o", [Globalization.CultureInfo]::InvariantCulture)
}

function Get-NormalizedFileSystemPath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { throw "A filesystem path cannot be empty." }
    $providerPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    return [IO.Path]::GetFullPath($providerPath)
}

function Set-ManifestValue($Manifest, [string]$Name, $Value) {
    if ($Manifest -is [Collections.IDictionary]) {
        $Manifest[$Name] = $Value
    } elseif ($Manifest.PSObject.Properties[$Name]) {
        $Manifest.$Name = $Value
    } else {
        $Manifest | Add-Member -MemberType NoteProperty -Name $Name -Value $Value
    }
}

function Write-BackupManifest($Manifest, [string]$ManifestPath) {
    $tempPath = $ManifestPath + "." + [guid]::NewGuid().ToString("N") + ".tmp"
    try {
        $json = ConvertTo-Json -InputObject $Manifest -Depth 8
        $utf8 = New-Object Text.UTF8Encoding($false)
        [IO.File]::WriteAllText($tempPath, $json + [Environment]::NewLine, $utf8)
        Move-Item -LiteralPath $tempPath -Destination $ManifestPath -Force
    } finally {
        if (Test-Path -LiteralPath $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-BackupManifest([string]$Device, [string]$StartedAtUtc) {
    return [ordered]@{
        schema_version = 1
        backup_status = "starting"
        device_name = $Device
        source_root = "Internal Storage"
        source_access = "read-only"
        copy_method = "Shell.Application.CopyHere, one file at a time"
        verification_method = "source byte count, staged SHA-256, finalized SHA-256 readback"
        started_at_utc = $StartedAtUtc
        finished_at_utc = $null
        verification_passed_at_utc = $null
        directory_count = 0
        file_count = 0
        verified_file_count = 0
        total_source_bytes = 0
        directories = @()
        files = @()
        failure = $null
    }
}

function Convert-MtpDateToUtc($Value) {
    if ($null -eq $Value -or $Value -is [DBNull] -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        return $null
    }
    try {
        $date = if ($Value -is [DateTime]) {
            [DateTime]$Value
        } else {
            [DateTime]::Parse(
                [string]$Value,
                [Globalization.CultureInfo]::CurrentCulture,
                [Globalization.DateTimeStyles]::AssumeUniversal
            )
        }
        # Shell's MTP System.DateModified value is a UTC clock value whose
        # DateTime Kind is Unspecified (confirmed on the Forerunner 265).
        if ($date.Kind -eq [DateTimeKind]::Unspecified) {
            $date = [DateTime]::SpecifyKind($date, [DateTimeKind]::Utc)
        }
        return $date.ToUniversalTime().ToString("o", [Globalization.CultureInfo]::InvariantCulture)
    } catch {
        return $null
    }
}

function Get-MtpExtendedProperty($Item, [string]$PropertyName) {
    try { return $Item.ExtendedProperty($PropertyName) } catch { return $null }
}

function Get-MtpItemName($Item) {
    $name = Get-MtpExtendedProperty $Item "System.FileName"
    if ([string]::IsNullOrWhiteSpace([string]$name)) {
        try { $name = $Item.Name } catch { $name = $null }
    }
    if ([string]::IsNullOrWhiteSpace([string]$name)) {
        throw "The watch exposed an item without a usable name."
    }
    return [string]$name
}

function Assert-SafePathSegment([string]$Name) {
    if ([string]::IsNullOrEmpty($Name) -or $Name -eq "." -or $Name -eq "..") {
        throw "The watch exposed an unsafe empty or relative path segment."
    }
    if ($Name.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
        $Name.Contains("\") -or $Name.Contains("/")) {
        throw "The watch exposed a filename that Windows cannot preserve safely: '$Name'."
    }
    if ($Name.EndsWith(" ") -or $Name.EndsWith(".")) {
        throw "The watch exposed a filename with a trailing space or dot that Windows cannot preserve: '$Name'."
    }
    $baseName = ($Name -split '\.')[0]
    if ($baseName -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$') {
        throw "The watch exposed a Windows-reserved filename that cannot be preserved: '$Name'."
    }
}

function Get-MtpFileSize($Item, [string]$RelativePath) {
    $raw = Get-MtpExtendedProperty $Item "System.Size"
    if ($null -eq $raw -or $raw -is [DBNull] -or [string]::IsNullOrWhiteSpace([string]$raw)) {
        throw "Cannot verify '$RelativePath' because the watch did not report its byte count."
    }
    try {
        return [Convert]::ToUInt64($raw, [Globalization.CultureInfo]::InvariantCulture)
    } catch {
        throw "Cannot verify '$RelativePath' because its reported byte count is invalid."
    }
}

function Assert-BeforeDeadline([DateTime]$DeadlineUtc, [string]$Operation) {
    if ([DateTime]::UtcNow -ge $DeadlineUtc) {
        throw [TimeoutException]::new("Timed out while $Operation.")
    }
}

function Get-MtpStorageFolder($Shell, [string]$WantedDevice, [int]$TimeoutSeconds) {
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $sawDevice = $false
    while ($timer.Elapsed.TotalSeconds -lt $TimeoutSeconds) {
        try {
            $thisPc = $Shell.Namespace(17)
            if ($null -ne $thisPc) {
                $devices = $thisPc.Items()
                for ($i = 0; $i -lt [int]$devices.Count; $i += 1) {
                    $device = $devices.Item($i)
                    $name = try { [string]$device.Name } catch { "" }
                    if ($name -ine $WantedDevice) { continue }
                    $sawDevice = $true
                    $deviceFolder = $device.GetFolder()
                    $items = $deviceFolder.Items()
                    for ($j = 0; $j -lt [int]$items.Count; $j += 1) {
                        $candidate = $items.Item($j)
                        if ((Get-MtpItemName $candidate) -ieq "Internal Storage") {
                            return $candidate.GetFolder()
                        }
                    }
                }
            }
        } catch {
            # MTP often needs another moment after the device first appears.
        }
        Start-Sleep -Milliseconds 500
    }
    if ($sawDevice) {
        throw "'$WantedDevice' is connected, but Internal Storage did not become available within $TimeoutSeconds seconds."
    }
    throw "'$WantedDevice' was not found in This PC within $TimeoutSeconds seconds. Check the USB cable and MTP connection."
}

function Get-MtpInventory($StorageFolder, [DateTime]$DeadlineUtc, [int]$ItemLimit, [int]$DepthLimit) {
    $directories = [Collections.Generic.List[object]]::new()
    $files = [Collections.Generic.List[object]]::new()
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $stack = [Collections.Stack]::new()
    $stack.Push([pscustomobject]@{ Folder = $StorageFolder; RelativePath = ""; Depth = 0 })
    $itemCount = 0

    while ($stack.Count -gt 0) {
        Assert-BeforeDeadline $DeadlineUtc "enumerating Internal Storage"
        $frame = $stack.Pop()
        $items = $frame.Folder.Items()
        $childFolders = [Collections.Generic.List[object]]::new()
        for ($i = 0; $i -lt [int]$items.Count; $i += 1) {
            Assert-BeforeDeadline $DeadlineUtc "enumerating Internal Storage"
            $item = $items.Item($i)
            $name = Get-MtpItemName $item
            Assert-SafePathSegment $name
            $relative = if ([string]::IsNullOrEmpty($frame.RelativePath)) { $name } else { $frame.RelativePath + "/" + $name }
            if (-not $seen.Add($relative)) {
                throw "Internal Storage contains a case-insensitive path collision at '$relative'."
            }
            $itemCount += 1
            if ($itemCount -gt $ItemLimit) {
                throw "Internal Storage exceeded the safety limit of $ItemLimit items."
            }
            $modified = Convert-MtpDateToUtc (Get-MtpExtendedProperty $item "System.DateModified")
            $isFolder = try { [bool]$item.IsFolder } catch { $false }
            if ($isFolder) {
                $depth = [int]$frame.Depth + 1
                if ($depth -gt $DepthLimit) {
                    throw "Internal Storage exceeded the safety limit of $DepthLimit directory levels at '$relative'."
                }
                $directories.Add([pscustomobject]@{
                    RelativePath = $relative
                    SourceModifiedUtc = $modified
                })
                $childFolders.Add([pscustomobject]@{
                    Folder = $item.GetFolder()
                    RelativePath = $relative
                    Depth = $depth
                })
            } else {
                $files.Add([pscustomobject]@{
                    RelativePath = $relative
                    Name = $name
                    SourceSize = Get-MtpFileSize $item $relative
                    SourceModifiedUtc = $modified
                    SourceItem = $item
                })
            }
        }
        $orderedChildren = @($childFolders.ToArray() | Sort-Object RelativePath -Descending)
        foreach ($child in $orderedChildren) { $stack.Push($child) }
    }

    return [pscustomobject]@{
        Directories = @($directories.ToArray() | Sort-Object RelativePath)
        Files = @($files.ToArray() | Sort-Object RelativePath)
    }
}

function Get-SafeDestinationPath([string]$Root, [string]$RelativePath) {
    $rootFull = [IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $current = $rootFull
    foreach ($segment in ($RelativePath -split '[/\\]')) {
        Assert-SafePathSegment $segment
        $current = Join-Path $current $segment
    }
    $full = [IO.Path]::GetFullPath($current)
    $prefix = $rootFull + [IO.Path]::DirectorySeparatorChar
    if (-not $full.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "A device path would escape the backup directory."
    }
    return $full
}

function Test-FileReady([string]$Path) {
    try {
        $stream = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::None)
        $stream.Dispose()
        return $true
    } catch {
        return $false
    }
}

function Wait-CopiedFile([string]$Path, [UInt64]$ExpectedSize, [DateTime]$DeadlineUtc, [int]$PollMs) {
    $stablePolls = 0
    while ([DateTime]::UtcNow -lt $DeadlineUtc) {
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            $actual = [UInt64](Get-Item -LiteralPath $Path -Force).Length
            if ($actual -gt $ExpectedSize) {
                throw "The copied file is larger than the byte count reported by the watch."
            }
            if ($actual -eq $ExpectedSize) {
                $stablePolls += 1
                if ($stablePolls -ge 2 -and (Test-FileReady $Path)) { return }
            } else {
                $stablePolls = 0
            }
        }
        Start-Sleep -Milliseconds $PollMs
    }
    $actualText = if (Test-Path -LiteralPath $Path -PathType Leaf) {
        [string](Get-Item -LiteralPath $Path -Force).Length
    } else { "missing" }
    throw [TimeoutException]::new("The file copy did not reach the expected $ExpectedSize bytes before the deadline (actual: $actualText).")
}

function Initialize-ManifestInventory($Manifest, $Inventory) {
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $directoryEntries = @()
    foreach ($directory in $Inventory.Directories) {
        if (-not $seen.Add([string]$directory.RelativePath)) {
            throw "The inventory contains a path collision at '$($directory.RelativePath)'."
        }
        $directoryEntries += [ordered]@{
            relative_path = ([string]$directory.RelativePath).Replace("\", "/")
            source_modified_utc = $directory.SourceModifiedUtc
            status = "pending"
        }
    }
    $fileEntries = @()
    [UInt64]$totalBytes = 0
    foreach ($file in $Inventory.Files) {
        if (-not $seen.Add([string]$file.RelativePath)) {
            throw "The inventory contains a path collision at '$($file.RelativePath)'."
        }
        $totalBytes += [UInt64]$file.SourceSize
        $fileEntries += [ordered]@{
            relative_path = ([string]$file.RelativePath).Replace("\", "/")
            source_size_bytes = [UInt64]$file.SourceSize
            source_modified_utc = $file.SourceModifiedUtc
            copy_started_at_utc = $null
            verified_at_utc = $null
            copied_size_bytes = $null
            sha256 = $null
            status = "pending"
        }
    }
    Set-ManifestValue $Manifest "directories" $directoryEntries
    Set-ManifestValue $Manifest "files" $fileEntries
    Set-ManifestValue $Manifest "directory_count" $directoryEntries.Count
    Set-ManifestValue $Manifest "file_count" $fileEntries.Count
    Set-ManifestValue $Manifest "total_source_bytes" $totalBytes
    return $fileEntries
}

function Assert-BackupDataTree([string]$DataRoot, $Manifest, [DateTime]$DeadlineUtc) {
    foreach ($directory in $Manifest.directories) {
        Assert-BeforeDeadline $DeadlineUtc "verifying backup directories"
        $path = Get-SafeDestinationPath $DataRoot ([string]$directory.relative_path)
        if (-not (Test-Path -LiteralPath $path -PathType Container)) {
            throw "A backed-up directory is missing: '$($directory.relative_path)'."
        }
    }
    foreach ($file in $Manifest.files) {
        Assert-BeforeDeadline $DeadlineUtc "performing SHA-256 readback"
        $path = Get-SafeDestinationPath $DataRoot ([string]$file.relative_path)
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "A backed-up file is missing: '$($file.relative_path)'."
        }
        $size = [UInt64](Get-Item -LiteralPath $path -Force).Length
        if ($size -ne [UInt64]$file.source_size_bytes) {
            throw "Final size verification failed for '$($file.relative_path)'."
        }
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($hash -cne [string]$file.sha256) {
            throw "Final SHA-256 verification failed for '$($file.relative_path)'."
        }
    }
    $actualFiles = @(Get-ChildItem -LiteralPath $DataRoot -File -Force -Recurse)
    $actualDirectories = @(Get-ChildItem -LiteralPath $DataRoot -Directory -Force -Recurse)
    if ($actualFiles.Count -ne [int]$Manifest.file_count) {
        throw "The finalized data tree contains $($actualFiles.Count) files; the manifest contains $($Manifest.file_count)."
    }
    if ($actualDirectories.Count -ne [int]$Manifest.directory_count) {
        throw "The finalized data tree contains $($actualDirectories.Count) directories; the manifest contains $($Manifest.directory_count)."
    }
}

function Invoke-BackupPlan(
    $Shell,
    $Inventory,
    $Manifest,
    [string]$PartialPath,
    [string]$CompletedPath,
    [int]$PerFileTimeoutSeconds,
    [int]$PollMs,
    [DateTime]$DeadlineUtc
) {
    $manifestPath = Join-Path $PartialPath "manifest.json"
    $dataRoot = Join-Path $PartialPath "Internal Storage"
    $stagingRoot = Join-Path $PartialPath ".copy-staging"
    $currentEntry = $null
    try {
        Set-ManifestValue $Manifest "backup_status" "copying"
        $fileEntries = @(Initialize-ManifestInventory $Manifest $Inventory)
        New-Item -ItemType Directory -Path $dataRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $stagingRoot | Out-Null
        for ($i = 0; $i -lt $Inventory.Directories.Count; $i += 1) {
            Assert-BeforeDeadline $DeadlineUtc "creating the local directory tree"
            $directory = $Inventory.Directories[$i]
            $path = Get-SafeDestinationPath $dataRoot ([string]$directory.RelativePath)
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            $Manifest.directories[$i].status = "created"
        }
        Write-BackupManifest $Manifest $manifestPath

        for ($i = 0; $i -lt $Inventory.Files.Count; $i += 1) {
            Assert-BeforeDeadline $DeadlineUtc "copying Internal Storage"
            $file = $Inventory.Files[$i]
            $currentEntry = $fileEntries[$i]
            $currentEntry.status = "copying"
            $currentEntry.copy_started_at_utc = Get-UtcTimestamp
            Write-BackupManifest $Manifest $manifestPath

            $target = Get-SafeDestinationPath $dataRoot ([string]$file.RelativePath)
            $targetParent = Split-Path -Parent $target
            if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
                New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
            }
            if (Test-Path -LiteralPath $target) {
                throw "Refusing to overwrite a pre-existing backup file: '$($file.RelativePath)'."
            }

            $stageDirectory = Join-Path $stagingRoot ("file-{0:D8}" -f ($i + 1))
            New-Item -ItemType Directory -Path $stageDirectory | Out-Null
            $stageFile = Join-Path $stageDirectory ([string]$file.Name)
            $destination = $Shell.Namespace($stageDirectory)
            if ($null -eq $destination) { throw "Windows Shell could not open the local staging directory." }

            # Source is the MTP FolderItem; destination is always a new local folder.
            # Nothing in this script calls CopyHere, InvokeVerb, or delete on the watch.
            $destination.CopyHere($file.SourceItem, 1044)
            $fileDeadline = [DateTime]::UtcNow.AddSeconds($PerFileTimeoutSeconds)
            if ($fileDeadline -gt $DeadlineUtc) { $fileDeadline = $DeadlineUtc }
            Wait-CopiedFile $stageFile ([UInt64]$file.SourceSize) $fileDeadline $PollMs

            $stageHash = (Get-FileHash -LiteralPath $stageFile -Algorithm SHA256).Hash.ToLowerInvariant()
            Move-Item -LiteralPath $stageFile -Destination $target
            $finalHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($stageHash -cne $finalHash) {
                throw "SHA-256 changed while finalizing '$($file.RelativePath)'."
            }
            $currentEntry.copied_size_bytes = [UInt64](Get-Item -LiteralPath $target -Force).Length
            $currentEntry.sha256 = $finalHash
            $currentEntry.verified_at_utc = Get-UtcTimestamp
            $currentEntry.status = "verified"
            Set-ManifestValue $Manifest "verified_file_count" ($i + 1)

            $stageContents = @(Get-ChildItem -LiteralPath $stageDirectory -Force)
            if ($stageContents.Count -ne 0) {
                throw "The staging directory contained unexpected extra data after copying '$($file.RelativePath)'."
            }
            Remove-Item -LiteralPath $stageDirectory -Force
            Write-BackupManifest $Manifest $manifestPath
        }

        Assert-BackupDataTree $dataRoot $Manifest $DeadlineUtc
        $remainingStaging = @(Get-ChildItem -LiteralPath $stagingRoot -Force)
        if ($remainingStaging.Count -ne 0) { throw "The staging directory was not empty after verification." }
        Remove-Item -LiteralPath $stagingRoot -Force

        Set-ManifestValue $Manifest "backup_status" "complete"
        Set-ManifestValue $Manifest "verification_passed_at_utc" (Get-UtcTimestamp)
        Set-ManifestValue $Manifest "finished_at_utc" (Get-UtcTimestamp)
        Set-ManifestValue $Manifest "failure" $null
        Write-BackupManifest $Manifest $manifestPath

        if (Test-Path -LiteralPath $CompletedPath) {
            throw "The completed backup destination already exists."
        }
        if ((Split-Path -Parent $PartialPath) -ine (Split-Path -Parent $CompletedPath)) {
            throw "Partial and completed backup directories must have the same parent."
        }
        Rename-Item -LiteralPath $PartialPath -NewName (Split-Path -Leaf $CompletedPath)
        return $CompletedPath
    } catch {
        if ($null -ne $currentEntry -and $currentEntry.status -eq "copying") {
            $currentEntry.status = "failed"
        }
        Set-ManifestValue $Manifest "backup_status" "failed"
        Set-ManifestValue $Manifest "finished_at_utc" (Get-UtcTimestamp)
        Set-ManifestValue $Manifest "failure" ([ordered]@{
            code = "backup_failed"
            message = $_.Exception.Message
        })
        if (Test-Path -LiteralPath $PartialPath -PathType Container) {
            try { Write-BackupManifest $Manifest $manifestPath } catch { }
        }
        throw
    }
}

function New-BackupSession([string]$Root, [string]$Device) {
    $rootPath = Get-NormalizedFileSystemPath $Root
    New-Item -ItemType Directory -Path $rootPath -Force | Out-Null
    $slug = (($Device -replace '[^A-Za-z0-9._-]+', '-') -replace '^-+|-+$', '').ToLowerInvariant()
    if ([string]::IsNullOrEmpty($slug)) { $slug = "garmin-device" }
    $name = (Get-Date -Format "yyyyMMdd-HHmmss") + "-" + $slug + "-" + [guid]::NewGuid().ToString("N").Substring(0, 8)
    $completed = Join-Path $rootPath $name
    $partial = $completed + ".partial"
    New-Item -ItemType Directory -Path $partial | Out-Null
    return [pscustomobject]@{ PartialPath = $partial; CompletedPath = $completed }
}

function Invoke-GarminDeviceBackup {
    param(
        [string]$WantedDevice,
        [string]$BackupRoot,
        [int]$PerFileTimeoutSeconds,
        [int]$FindTimeoutSeconds,
        [int]$PollMs,
        [int]$OverallMinutes,
        [int]$ItemLimit,
        [int]$DepthLimit
    )
    $started = Get-UtcTimestamp
    $session = New-BackupSession $BackupRoot $WantedDevice
    $manifest = New-BackupManifest $WantedDevice $started
    $manifestPath = Join-Path $session.PartialPath "manifest.json"
    Write-BackupManifest $manifest $manifestPath
    $deadline = [DateTime]::UtcNow.AddMinutes($OverallMinutes)

    try {
        Set-ManifestValue $manifest "backup_status" "discovering"
        Write-BackupManifest $manifest $manifestPath
        $shell = New-Object -ComObject Shell.Application
        $storage = Get-MtpStorageFolder $shell $WantedDevice $FindTimeoutSeconds
        $inventory = Get-MtpInventory $storage $deadline $ItemLimit $DepthLimit
        $totalBytes = [UInt64]0
        foreach ($file in $inventory.Files) { $totalBytes += [UInt64]$file.SourceSize }
        Write-Host ("[inventory] {0} files, {1} directories, {2} bytes" -f $inventory.Files.Count, $inventory.Directories.Count, $totalBytes)
        $completed = Invoke-BackupPlan $shell $inventory $manifest $session.PartialPath $session.CompletedPath `
            $PerFileTimeoutSeconds $PollMs $deadline
        Write-Host "[complete] Verified read-only device backup: $completed"
        return $completed
    } catch {
        Set-ManifestValue $manifest "backup_status" "failed"
        Set-ManifestValue $manifest "finished_at_utc" (Get-UtcTimestamp)
        Set-ManifestValue $manifest "failure" ([ordered]@{ code = "backup_failed"; message = $_.Exception.Message })
        if (Test-Path -LiteralPath $session.PartialPath -PathType Container) {
            try { Write-BackupManifest $manifest $manifestPath } catch { }
        }
        throw ("Garmin backup failed: {0} Partial data was preserved at: {1}" -f $_.Exception.Message, $session.PartialPath)
    }
}

if ($MyInvocation.InvocationName -ne ".") {
    $effectiveOutputRoot = $OutputRoot
    if ([string]::IsNullOrWhiteSpace($effectiveOutputRoot)) {
        $effectiveOutputRoot = Join-Path (Split-Path -Parent $BackupScriptDirectory) "bin\garmin-device-backups"
    }
    $completedBackup = Invoke-GarminDeviceBackup -WantedDevice $DeviceName -BackupRoot $effectiveOutputRoot `
        -PerFileTimeoutSeconds $CopyTimeoutSeconds -FindTimeoutSeconds $DiscoveryTimeoutSeconds `
        -PollMs $PollMilliseconds -OverallMinutes $OverallTimeoutMinutes `
        -ItemLimit $MaxItems -DepthLimit $MaxDepth | Select-Object -Last 1
    # A readable settings inventory and the diff against the previous backup. Only
    # reads the finished backup, and a failure here never invalidates the backup.
    if (-not $SkipSettingsInventory) {
        try {
            & (Join-Path $BackupScriptDirectory "watch-tools.ps1") settings $completedBackup
        } catch {
            Write-Warning ("Settings inventory skipped: {0}" -f $_.Exception.Message)
        }
    }
}
