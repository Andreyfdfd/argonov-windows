# ARGONOV SHELL - backup and restore

$script:ARGONOV_ROOT = if ($global:ARGONOV_ROOT) {
    [System.IO.Path]::GetFullPath($global:ARGONOV_ROOT)
} else {
    [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
}
$script:BACKUP_DIR = if ($global:ARGONOV_BACKUP_DIR) {
    [System.IO.Path]::GetFullPath($global:ARGONOV_BACKUP_DIR)
} else {
    Join-Path $HOME 'ARGONOV-Backups'
}

function backup {
    [CmdletBinding()]
    param([string]$Note = '')

    if (-not (Test-Path -LiteralPath $script:ARGONOV_ROOT -PathType Container)) {
        Write-Host "  Project folder not found: $script:ARGONOV_ROOT" -ForegroundColor Red
        return
    }

    try {
        New-Item -ItemType Directory -Path $script:BACKUP_DIR -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "  Cannot create backup directory: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    $stamp = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $safeNote = if ([string]::IsNullOrWhiteSpace($Note)) { '' } else { '_' + ($Note -replace '[^\w-]', '_') }
    $zipPath = Join-Path $script:BACKUP_DIR "argonov_$stamp$safeNote.zip"
    if (Test-Path -LiteralPath $zipPath) {
        $zipPath = Join-Path $script:BACKUP_DIR ("argonov_{0}{1}_{2}.zip" -f $stamp, $safeNote, [guid]::NewGuid().ToString('N').Substring(0, 8))
    }
    $stagePath = Join-Path ([System.IO.Path]::GetTempPath()) ("argonov_backup_{0}" -f [guid]::NewGuid().ToString('N'))
    $archiveCreated = $false

    try {
        New-Item -ItemType Directory -Path $stagePath -Force -ErrorAction Stop | Out-Null
        $rootFull = [System.IO.Path]::GetFullPath($script:ARGONOV_ROOT).TrimEnd([char[]]@('\', '/'))
        $backupFull = [System.IO.Path]::GetFullPath($script:BACKUP_DIR).TrimEnd([char[]]@('\', '/'))
        $separator = [System.IO.Path]::DirectorySeparatorChar

        foreach ($item in (Get-ChildItem -LiteralPath $rootFull -Force -ErrorAction Stop)) {
            if ($item.Name -in @('.git', '.installed', 'ARGONOV-Backups')) { continue }
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                Write-Host "  Skipping linked item: $($item.Name)" -ForegroundColor DarkGray
                continue
            }

            $itemFull = [System.IO.Path]::GetFullPath($item.FullName).TrimEnd([char[]]@('\', '/'))
            if ($backupFull -eq $itemFull -or $backupFull.StartsWith($itemFull + $separator, [System.StringComparison]::OrdinalIgnoreCase)) {
                Write-Host "  Skipping backup output folder: $($item.Name)" -ForegroundColor DarkGray
                continue
            }

            Copy-Item -LiteralPath $item.FullName -Destination (Join-Path $stagePath $item.Name) -Recurse -Force -ErrorAction Stop
        }

        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $stagePath,
            $zipPath,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )
        $archiveCreated = $true

        $size = [math]::Round((Get-Item -LiteralPath $zipPath).Length / 1KB, 1)
        Write-Host ''
        Write-Host "  Backup created: $size KB" -ForegroundColor Green
        Write-Host "  Source: $rootFull" -ForegroundColor DarkGray
        Write-Host "  Archive: $zipPath" -ForegroundColor Cyan
        Write-Host ''
        return (Get-Item -LiteralPath $zipPath)
    } catch {
        # Do not delete a pre-existing archive if archive creation failed.
        if ($archiveCreated -and (Test-Path -LiteralPath $zipPath)) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
        Write-Host "  Backup failed: $($_.Exception.Message)" -ForegroundColor Red
        return
    } finally {
        if (Test-Path -LiteralPath $stagePath) {
            Remove-Item -LiteralPath $stagePath -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function backup-list {
    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR -PathType Container)) {
        Write-Host "  No backups yet ($script:BACKUP_DIR)" -ForegroundColor Yellow
        return
    }

    $files = @(Get-ChildItem -LiteralPath $script:BACKUP_DIR -Filter 'argonov_*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        Write-Host '  No backups yet' -ForegroundColor Yellow
        return
    }

    Write-Host ''
    Write-Host "  Backups in $script:BACKUP_DIR :" -ForegroundColor Cyan
    Write-Host '  ----------------------------------------' -ForegroundColor DarkCyan
    for ($i = 0; $i -lt $files.Count; $i++) {
        $size = [math]::Round($files[$i].Length / 1KB, 1)
        Write-Host ("  [{0}] {1} ({2} KB, {3})" -f ($i + 1), $files[$i].Name, $size, $files[$i].LastWriteTime.ToString('yyyy-MM-dd HH:mm')) -ForegroundColor Gray
    }
    Write-Host ''
}

function backup-restore {
    [CmdletBinding()]
    param([ValidateRange(0, 2147483647)][int]$Index = 0)

    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR -PathType Container)) {
        Write-Host '  No backups found' -ForegroundColor Red
        return
    }
    $files = @(Get-ChildItem -LiteralPath $script:BACKUP_DIR -Filter 'argonov_*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        Write-Host '  No backups found' -ForegroundColor Red
        return
    }

    backup-list
    if ($Index -eq 0) {
        $answer = Read-Host "  Which backup to restore? (1-$($files.Count), 0 to cancel)"
        if ($answer -notmatch '^\d+$') { return }
        $Index = [int]$answer
        if ($Index -eq 0) { Write-Host '  Cancelled' -ForegroundColor DarkGray; return }
    }
    if ($Index -lt 1 -or $Index -gt $files.Count) {
        Write-Host '  Invalid backup number' -ForegroundColor Red
        return
    }

    $archivePath = $files[$Index - 1].FullName
    Write-Host ''
    Write-Host "  Restore archive: $($files[$Index - 1].Name)" -ForegroundColor Yellow
    Write-Host "  Destination: $script:ARGONOV_ROOT" -ForegroundColor DarkGray
    Write-Host '  Existing files with matching paths will be overwritten. Other files will be kept.' -ForegroundColor Yellow
    $confirm = Read-Host '  Continue? Type y to confirm'
    if ($confirm -cne 'y') {
        Write-Host '  Cancelled' -ForegroundColor DarkGray
        return
    }

    # Snapshot the current project before restoration. The archive selected above is retained in $archivePath.
    Write-Host '  Backing up current state first...' -ForegroundColor DarkGray
    backup 'before-restore' | Out-Null

    $restoreStage = Join-Path ([System.IO.Path]::GetTempPath()) ("argonov_restore_{0}" -f [guid]::NewGuid().ToString('N'))
    try {
        New-Item -ItemType Directory -Path $restoreStage -Force -ErrorAction Stop | Out-Null
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction Stop
        $archive = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
        try {
            $stageFull = [System.IO.Path]::GetFullPath($restoreStage).TrimEnd([char[]]@('\', '/'))
            $stagePrefix = $stageFull + [System.IO.Path]::DirectorySeparatorChar
            foreach ($entry in $archive.Entries) {
                $entryName = $entry.FullName.Replace('/', [System.IO.Path]::DirectorySeparatorChar)
                if ([System.IO.Path]::IsPathRooted($entryName) -or $entryName -match '(^|[\\/])\.\.([\\/]|$)' -or $entryName -match '^[A-Za-z]:') {
                    throw "Unsafe archive path detected: $($entry.FullName)"
                }
                $targetFull = [System.IO.Path]::GetFullPath((Join-Path $stageFull $entryName))
                if (-not $targetFull.StartsWith($stagePrefix, [System.StringComparison]::OrdinalIgnoreCase) -and $targetFull -ne $stageFull) {
                    throw "Archive entry escapes extraction folder: $($entry.FullName)"
                }
            }
        } finally {
            $archive.Dispose()
        }

        Expand-Archive -LiteralPath $archivePath -DestinationPath $restoreStage -Force -ErrorAction Stop
        $rootFull = [System.IO.Path]::GetFullPath($script:ARGONOV_ROOT)
        if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
            New-Item -ItemType Directory -Path $rootFull -Force -ErrorAction Stop | Out-Null
        }

        $restoredCount = 0
        foreach ($file in (Get-ChildItem -LiteralPath $restoreStage -File -Recurse -Force -ErrorAction Stop)) {
            $relativePath = [System.IO.Path]::GetRelativePath($restoreStage, $file.FullName)
            $targetPath = Join-Path $rootFull $relativePath
            $targetDirectory = Split-Path -Parent $targetPath
            if (-not (Test-Path -LiteralPath $targetDirectory -PathType Container)) {
                New-Item -ItemType Directory -Path $targetDirectory -Force -ErrorAction Stop | Out-Null
            }
            Copy-Item -LiteralPath $file.FullName -Destination $targetPath -Force -ErrorAction Stop
            $restoredCount++
        }

        Write-Host ''
        Write-Host "  Restored $restoredCount file(s)." -ForegroundColor Green
        Write-Host '  Files absent from the archive were not deleted.' -ForegroundColor DarkGray
        Write-Host '  Restart PowerShell 7 to reload modules.' -ForegroundColor Yellow
        Write-Host ''
    } catch {
        Write-Host "  Restore failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host '  The archive was not extracted outside the project folder.' -ForegroundColor DarkGray
    } finally {
        if (Test-Path -LiteralPath $restoreStage) {
            Remove-Item -LiteralPath $restoreStage -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function backup-delete {
    [CmdletBinding()]
    param([ValidateRange(0, 2147483647)][int]$Index = 0)

    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR -PathType Container)) {
        Write-Host '  No backups' -ForegroundColor Red
        return
    }
    $files = @(Get-ChildItem -LiteralPath $script:BACKUP_DIR -Filter 'argonov_*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) {
        Write-Host '  No backups' -ForegroundColor Red
        return
    }

    backup-list
    if ($Index -eq 0) {
        $answer = Read-Host "  Which backup to delete? (1-$($files.Count), 0 to cancel)"
        if ($answer -notmatch '^\d+$') { return }
        $Index = [int]$answer
        if ($Index -eq 0) { Write-Host '  Cancelled' -ForegroundColor DarkGray; return }
    }
    if ($Index -lt 1 -or $Index -gt $files.Count) {
        Write-Host '  Invalid backup number' -ForegroundColor Red
        return
    }

    $target = $files[$Index - 1]
    $confirm = Read-Host "  Delete '$($target.Name)'? Type y to confirm"
    if ($confirm -cne 'y') {
        Write-Host '  Cancelled' -ForegroundColor DarkGray
        return
    }
    Remove-Item -LiteralPath $target.FullName -Force -ErrorAction Stop
    Write-Host "  Deleted: $($target.Name)" -ForegroundColor Green
}