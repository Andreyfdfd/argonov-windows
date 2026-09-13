# ARGONOV SHELL · screenshot

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# DPI-aware: без этого при масштабировании 125/150% размеры экрана врут
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class DpiHelper {
    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();
}
"@
[DpiHelper]::SetProcessDPIAware() | Out-Null

# Находим папку Pictures через реестр (учитывает переезд на другой диск)
function Get-PicturesPath {
    $reg = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
    try {
        $p = (Get-ItemProperty -Path $reg -Name "My Pictures" -ErrorAction Stop)."My Pictures"
        $p = [Environment]::ExpandEnvironmentVariables($p)
        if (Test-Path $p) { return $p }
    } catch {}
    # Fallback — стандартный путь
    return "$HOME\Pictures"
}

$script:SHOTS_DIR = Join-Path (Get-PicturesPath) "ARGONOV Screenshots"

function Ensure-ShotsDir {
    if (-not (Test-Path $script:SHOTS_DIR)) {
        New-Item -ItemType Directory -Force -Path $script:SHOTS_DIR | Out-Null
        Write-Host "  Created: $script:SHOTS_DIR" -ForegroundColor DarkGray
    }
}

function screenshot {
    param(
        [string]$Path = "",
        [switch]$NoOpen
    )

    Ensure-ShotsDir

    # Виртуальный экран — учитывает все мониторы и их координаты (включая отрицательные)
    $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $left   = $vs.Left
    $top    = $vs.Top
    $width  = $vs.Width
    $height = $vs.Height

    if ($width -le 0 -or $height -le 0) {
        Write-Host "  ERROR: invalid screen size ($width x $height)" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  Capturing $width x $height (offset: $left, $top) ..." -ForegroundColor Yellow

    try {
        $bmp = New-Object System.Drawing.Bitmap($width, $height)
        $gfx = [System.Drawing.Graphics]::FromImage($bmp)
        $gfx.CopyFromScreen($left, $top, 0, 0, $bmp.Size)
        $gfx.Dispose()
    } catch {
        Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
        return
    }

    if (-not $Path) {
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $Path = Join-Path $script:SHOTS_DIR "shot_$stamp.png"
    }

    try {
        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        $size = [math]::Round((Get-Item $Path).Length / 1KB, 1)
        Write-Host "  Saved: $Path  ($size KB)" -ForegroundColor Green
    } catch {
        Write-Host "  ERROR saving: $($_.Exception.Message)" -ForegroundColor Red
        $bmp.Dispose()
        return
    }

    if (-not $NoOpen) {
        Start-Process explorer.exe "/select,`"$Path`""
    }
    Write-Host ""
}

function screenshot-window {
    param([string]$Path = "")

    Ensure-ShotsDir

    Add-Type @"
        using System;
        using System.Runtime.InteropServices;
        public class Win32W {
            [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
            [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
            [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
        }
"@ -ErrorAction SilentlyContinue

    $hwnd = [Win32W]::GetForegroundWindow()
    $rect = New-Object Win32W+RECT
    [Win32W]::GetWindowRect($hwnd, [ref]$rect) | Out-Null

    $width  = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    if ($width -le 0 -or $height -le 0) {
        Write-Host "  ERROR: invalid window size" -ForegroundColor Red
        return
    }

    Write-Host ""
    Write-Host "  Capturing active window ($width x $height) ..." -ForegroundColor Yellow

    $bmp = New-Object System.Drawing.Bitmap($width, $height)
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
    $gfx.Dispose()

    if (-not $Path) {
        $stamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
        $Path = Join-Path $script:SHOTS_DIR "win_$stamp.png"
    }

    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()

    $size = [math]::Round((Get-Item $Path).Length / 1KB, 1)
    Write-Host "  Saved: $Path  ($size KB)" -ForegroundColor Green
    Write-Host ""
}

function screenshot-folder {
    Ensure-ShotsDir
    Start-Process explorer.exe $script:SHOTS_DIR
    Write-Host "  Opened: $script:SHOTS_DIR" -ForegroundColor Green
}

function screenshot-list {
    Ensure-ShotsDir
    $files = Get-ChildItem $script:SHOTS_DIR -Filter *.png -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 20
    if (-not $files) {
        Write-Host "  No screenshots yet" -ForegroundColor Yellow
        return
    }
    Write-Host ""
    Write-Host "  Latest 20 screenshots in $script:SHOTS_DIR :" -ForegroundColor Cyan
    Write-Host "  ----------------------------------------" -ForegroundColor DarkCyan
    foreach ($f in $files) {
        $kb = [math]::Round($f.Length / 1KB, 1)
        Write-Host "  $($f.Name)  ($kb KB, $($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))" -ForegroundColor Gray
    }
    Write-Host ""
}

function screenshot-clean {
    param([int]$Days = 30)
    Ensure-ShotsDir
    $cutoff = (Get-Date).AddDays(-$Days)
    $old = Get-ChildItem $script:SHOTS_DIR -Filter *.png -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff }
    if (-not $old) {
        Write-Host "  Nothing to delete (older than $Days days)" -ForegroundColor Yellow
        return
    }
    $total = [math]::Round(($old | Measure-Object Length -Sum).Sum / 1MB, 1)
    Write-Host "  Found $($old.Count) files ($total MB) older than $Days days" -ForegroundColor Yellow
    $a = Read-Host "  Delete? (y/N)"
    if ($a -ne "y") { Write-Host "  Cancelled" -ForegroundColor DarkGray; return }
    $old | Remove-Item -Force
    Write-Host "  Deleted $($old.Count) files" -ForegroundColor Green
}