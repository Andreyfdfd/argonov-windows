# ARGONOV SHELL · backup

$script:BACKUP_DIR = "$HOME\ARGONOV-Backups"

function backup {
    param([string]$Note = "")
    
    if (-not (Test-Path $script:BACKUP_DIR)) {
        New-Item -ItemType Directory -Force -Path $script:BACKUP_DIR | Out-Null
    }
    
    $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $suffix = if ($Note) { "_$($Note -replace '[^\w\-]','_')" } else { "" }
    $zipPath = Join-Path $script:BACKUP_DIR "argonov_$stamp$suffix.zip"
    
    Write-Host ""
    Write-Host "  Creating backup..." -ForegroundColor Yellow
    Write-Host "  Source: C:\ARGONOV" -ForegroundColor DarkGray
    Write-Host "  Target: $zipPath" -ForegroundColor DarkGray
    
    # Собираем файлы: profile.ps1 + modules + README + ROADMAP
    $items = @()
    $items += Get-Item "C:\ARGONOV\profile.ps1" -ErrorAction SilentlyContinue
    $items += Get-Item "C:\ARGONOV\README.md" -ErrorAction SilentlyContinue
    $items += Get-Item "C:\ARGONOV\ROADMAP.md" -ErrorAction SilentlyContinue
    $items += Get-ChildItem "C:\ARGONOV\modules" -File -ErrorAction SilentlyContinue
    
    if (-not $items) {
        Write-Host "  No files to backup" -ForegroundColor Red
        return
    }
    
    # Создаём временную папку и копируем структуру
    $tmp = Join-Path $env:TEMP "argonov_backup_$stamp"
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    New-Item -ItemType Directory -Force -Path "$tmp\modules" | Out-Null
    
    foreach ($f in $items) {
        if ($f.DirectoryName -like "*\modules") {
            Copy-Item $f.FullName "$tmp\modules\" -Force
        } else {
            Copy-Item $f.FullName $tmp -Force
        }
    }
    
    # Упаковываем
    try {
        Compress-Archive -Path "$tmp\*" -DestinationPath $zipPath -Force
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        $size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
        Write-Host ""
        Write-Host "  Backup created: $size KB" -ForegroundColor Green
        Write-Host "  $zipPath" -ForegroundColor Cyan
        Write-Host ""
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
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
    
    if (-not (Test-Path $script:BACKUP_DIR)) {
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
    Write-Host "  To: C:\ARGONOV" -ForegroundColor DarkGray
    
    $confirm = Read-Host "  This will overwrite current files. Continue? (y/N)"
    if ($confirm -ne "y") {
        Write-Host "  Cancelled" -ForegroundColor DarkGray
        return
    }
    
    # Делаем бэкап текущего состояния перед восстановлением
    Write-Host "  Backing up current state first..." -ForegroundColor DarkGray
    backup "before-restore"
    
    try {
        $tmp = Join-Path $env:TEMP "argonov_restore_$([guid]::NewGuid().ToString('N'))"
        Expand-Archive -Path $src -DestinationPath $tmp -Force
        
        # Копируем profile.ps1
        if (Test-Path "$tmp\profile.ps1") {
            Copy-Item "$tmp\profile.ps1" "C:\ARGONOV\profile.ps1" -Force
        }
        # README, ROADMAP
        foreach ($f in @("README.md", "ROADMAP.md")) {
            if (Test-Path "$tmp\$f") {
                Copy-Item "$tmp\$f" "C:\ARGONOV\$f" -Force
            }
        }
        # modules
        if (Test-Path "$tmp\modules") {
            New-Item -ItemType Directory -Force -Path "C:\ARGONOV\modules" | Out-Null
            Copy-Item "$tmp\modules\*" "C:\ARGONOV\modules\" -Force
        }
        
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host ""
        Write-Host "  Restored successfully" -ForegroundColor Green
        Write-Host "  Restart terminal to reload modules" -ForegroundColor Yellow
        Write-Host ""
    } catch {
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
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
        $ans = Read-Host "  Which to delete? (1-$($files.Count), 0 to cancel)"
        if ($ans -notmatch '^\d+$') { return }
        $Index = [int]$ans
        if ($Index -eq 0) { Write-Host "  Cancelled" -ForegroundColor DarkGray; return }
    }
    
    $target = $files[$Index - 1]
    $confirm = Read-Host "  Delete $($target.Name)? (y/N)"
    if ($confirm -ne "y") {
        Write-Host "  Cancelled" -ForegroundColor DarkGray
        return
    }
    Remove-Item $target.FullName -Force
    Write-Host "  Deleted: $($target.Name)" -ForegroundColor Green
}