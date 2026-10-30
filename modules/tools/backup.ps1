# ARGONOV SHELL · backup
$script:BACKUP_DIR = Join-Path $HOME 'ARGONOV-Backups'
$script:ARGONOV_BACKUP_SOURCE = if ($global:ARGONOV_ROOT) { $global:ARGONOV_ROOT } else { Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }

function backup {
    param([string]$Note = "")
    $sourceRoot = $script:ARGONOV_BACKUP_SOURCE
    if (-not (Test-Path -LiteralPath $sourceRoot -PathType Container)) {
        Write-Host "  ARGONOV folder not found: $sourceRoot" -ForegroundColor Red
        return
    }
    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR)) {
        New-Item -ItemType Directory -Force -Path $script:BACKUP_DIR | Out-Null
    }

    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $suffix = if ($Note) { "_$($Note -replace '[^\w\-]','_')" } else { "" }
    $zipPath = Join-Path $script:BACKUP_DIR "argonov_$stamp$suffix.zip"
    $tmp = Join-Path $env:TEMP "argonov_backup_$stamp"
    $moduleSource = Join-Path $sourceRoot 'modules'

    Write-Host ""
    Write-Host "  Creating backup..." -ForegroundColor Yellow
    Write-Host "  Source: $sourceRoot" -ForegroundColor DarkGray
    Write-Host "  Target: $zipPath" -ForegroundColor DarkGray

    try {
        New-Item -ItemType Directory -Force -Path $tmp | Out-Null
        foreach ($name in @('profile.ps1','README.md','ROADMAP.md')) {
            $source = Join-Path $sourceRoot $name
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                Copy-Item -LiteralPath $source -Destination $tmp -Force
            }
        }
        if (Test-Path -LiteralPath $moduleSource -PathType Container) {
            Copy-Item -LiteralPath $moduleSource -Destination (Join-Path $tmp 'modules') -Recurse -Force
        }
        if (-not (Get-ChildItem -LiteralPath $tmp -Force)) {
            throw 'No ARGONOV files were available to back up.'
        }
        Compress-Archive -Path (Join-Path $tmp '*') -DestinationPath $zipPath -Force
        $size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Write-Host ""
        Write-Host "  Backup created: $size KB" -ForegroundColor Green
        Write-Host "  $zipPath" -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function backup-list {
    if (-not (Test-Path $script:BACKUP_DIR)) {
        Write-Host "  No backups yet ($script:BACKUP_DIR)" -ForegroundColor Yellow
        return
    }
    $files = Get-ChildItem $script:BACKUP_DIR -Filter "argonov_*.zip" | Sort-Object LastWriteTime -Descending
    if (-not $files) {
        Write-Host "  No backups yet" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  Backups in $script:BACKUP_DIR :" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------" -ForegroundColor DarkCyan
    $i = 1
    foreach ($f in $files) {
        $size = [math]::Round($f.Length / 1KB, 1)
        Write-Host "  [$i] " -NoNewline -ForegroundColor Yellow
        Write-Host $f.Name -NoNewline -ForegroundColor White
        Write-Host "  ($size KB, $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor DarkGray
        $i++
    }
    Write-Host ""
}

function backup-restore {
    param([int]$Index = 0)
    $targetRoot = $script:ARGONOV_BACKUP_SOURCE
    if (-not (Test-Path -LiteralPath $script:BACKUP_DIR)) {
        Write-Host "  No backups found" -ForegroundColor Red
        return
    }
    $files = Get-ChildItem $script:BACKUP_DIR -Filter "argonov_*.zip" | Sort-Object LastWriteTime -Descending
    if (-not $files) {
        Write-Host "  No backups found" -ForegroundColor Red
        return
    }
    backup-list
    if ($Index -le 0 -or $Index -gt $files.Count) {
        $ans = Read-Host "  Which to restore? (1-$($files.Count), 0 to cancel)"
        if ($ans -notmatch '^\d+$') { return }
        $Index = [int]$ans
        if ($Index -eq 0) { Write-Host "  Cancelled" -ForegroundColor DarkGray; return }
        if ($Index -lt 1 -or $Index -gt $files.Count) {
            Write-Host "  Invalid number" -ForegroundColor Red
            return
        }
    }

    $src = $files[$Index - 1].FullName
    Write-Host ""
    Write-Host "  Restoring: $($files[$Index - 1].Name)" -ForegroundColor Yellow
    Write-Host "  To: $targetRoot" -ForegroundColor DarkGray
    $confirm = Read-Host "  This will overwrite current files. Continue? (y/N)"
    if ($confirm -ne "y") {
        Write-Host "  Cancelled" -ForegroundColor DarkGray
        return
    }

    Write-Host "  Backing up current state first..." -ForegroundColor DarkGray
    backup "before-restore"
    $tmp = Join-Path $env:TEMP "argonov_restore_$([guid]::NewGuid().ToString('N'))"
    try {
        Expand-Archive -Path $src -DestinationPath $tmp -Force
        foreach ($name in @('profile.ps1','README.md','ROADMAP.md')) {
            $source = Join-Path $tmp $name
            if (Test-Path -LiteralPath $source -PathType Leaf) {
                Copy-Item -LiteralPath $source -Destination $targetRoot -Force
            }
        }
        $sourceModules = Join-Path $tmp 'modules'
        $targetModules = Join-Path $targetRoot 'modules'
        if (Test-Path -LiteralPath $sourceModules -PathType Container) {
            New-Item -ItemType Directory -Force -Path $targetModules | Out-Null
            Copy-Item -Path (Join-Path $sourceModules '*') -Destination $targetModules -Recurse -Force
        }
        Write-Host ""
        Write-Host "  Restored successfully" -ForegroundColor Green
        Write-Host "  Restart terminal to reload modules" -ForegroundColor Yellow
        Write-Host ""
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

function backup-delete {
    param([int]$Index = 0)
    if (-not (Test-Path $script:BACKUP_DIR)) {
        Write-Host "  No backups" -ForegroundColor Red
        return
    }
    $files = Get-ChildItem $script:BACKUP_DIR -Filter "argonov_*.zip" | Sort-Object LastWriteTime -Descending
    if (-not $files) {
        Write-Host "  No backups" -ForegroundColor Red
        return
    }
    backup-list
    if ($Index -le 0 -or $Index -gt $files.Count) {
        $ans = Read-Host "  Which backup to delete? (1-$($files.Count), 0 to cancel)"
        if ($ans -notmatch '^\d+$') { return }
        $Index = [int]$ans
        if ($Index -eq 0) { return }
        if ($Index -lt 1 -or $Index -gt $files.Count) { return }
    }
    $file = $files[$Index - 1]
    $confirm = Read-Host "  Delete $($file.Name)? (y/N)"
    if ($confirm -eq "y") {
        Remove-Item -LiteralPath $file.FullName -Force
        Write-Host "  Deleted" -ForegroundColor Green
    }
}
