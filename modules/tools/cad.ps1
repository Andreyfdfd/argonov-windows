# ARGONOV SHELL · CAD/CAM launcher v2

# ─── Реестр программ ───
# Ключ → набор приоритетных имён exe + ключевые слова для поиска в реестре
$script:CAD_APPS = @{
    # ─── CAD ───
    "solidworks" = @{ Name="SolidWorks"; Type="CAD"; Exes=@("SLDWORKS.exe","sldworks.exe");   Keys=@("SolidWorks","SOLIDWORKS","Dassault Systemes") }
    "autocad"    = @{ Name="AutoCAD";    Type="CAD"; Exes=@("acad.exe");                       Keys=@("AutoCAD","Autodesk AutoCAD") }
    "inventor"   = @{ Name="Inventor";   Type="CAD"; Exes=@("Inventor.exe");                   Keys=@("Inventor","Autodesk Inventor") }
    "fusion"     = @{ Name="Fusion 360"; Type="CAD"; Exes=@("Fusion.exe","Fusion360.exe");     Keys=@("Fusion 360","Autodesk Fusion") }
    "nx"         = @{ Name="Siemens NX"; Type="CAD"; Exes=@("ugraf.exe","nx.exe");             Keys=@("Siemens NX","NX ","UGII") }
    "catia"      = @{ Name="CATIA";      Type="CAD"; Exes=@("CNEXT.exe","catstart.exe");       Keys=@("CATIA","Dassault Systemes CATIA") }
    "creo"       = @{ Name="PTC Creo";   Type="CAD"; Exes=@("parametric.exe","proe.exe");      Keys=@("Creo","PTC Creo","Parametric") }
    "kompas"     = @{ Name="КОМПАС-3D";  Type="CAD"; Exes=@("KOMPAS.exe","Kompas.exe","kStudy.exe"); Keys=@("КОМПАС","ASCON","KOMPAS") }
    "freecad"    = @{ Name="FreeCAD";    Type="CAD"; Exes=@("FreeCAD.exe","freecad.exe");      Keys=@("FreeCAD") }
    "rhino"      = @{ Name="Rhinoceros"; Type="CAD"; Exes=@("Rhino.exe","rhino.exe");          Keys=@("Rhinoceros","McNeel","Rhino") }
    "sketchup"   = @{ Name="SketchUp";   Type="CAD"; Exes=@("SketchUp.exe","sketchup.exe");    Keys=@("SketchUp","Trimble") }
    "archicad"   = @{ Name="ArchiCAD";   Type="CAD"; Exes=@("ArchiCAD.exe","StartArchiCAD.exe"); Keys=@("ArchiCAD","GRAPHISOFT") }
    # ─── CAM ───
    "mastercam"  = @{ Name="Mastercam";  Type="CAM"; Exes=@("Mastercam.exe","mastercam.exe","MastercamApp.exe","Mastercam.exe"); Keys=@("Mastercam") }
    "solidcam"   = @{ Name="SolidCAM";   Type="CAM"; Exes=@("SolidCAM.exe","solidcam.exe");    Keys=@("SolidCAM") }
    "hypermill"  = @{ Name="hyperMILL";  Type="CAM"; Exes=@("hyperMILL.exe","hm.exe");         Keys=@("hyperMILL","OPEN MIND") }
    "powermill"  = @{ Name="PowerMill";  Type="CAM"; Exes=@("powermill.exe","pmill.exe");      Keys=@("PowerMill","Autodesk PowerMill") }
    "esprit"     = @{ Name="ESPRIT";     Type="CAM"; Exes=@("esprit.exe");                     Keys=@("ESPRIT","DP Technology") }
    "camworks"   = @{ Name="CAMWorks";   Type="CAM"; Exes=@("camworks.exe","cw.exe");          Keys=@("CAMWorks","HCL") }
    "featurecam" = @{ Name="FeatureCAM"; Type="CAM"; Exes=@("FeatureCAM.exe");                 Keys=@("FeatureCAM") }
}

# ─── Поиск по реестру ───
function Get-CadRegistry {
    $keys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.InstallLocation -and (Test-Path $_.InstallLocation -ErrorAction SilentlyContinue) } |
        Select-Object DisplayName, InstallLocation, DisplayVersion
}

# ─── Найти главный exe ───
function Find-CadExe {
    param([string]$InstallLoc, [string[]]$ExeNames)

    if (-not $InstallLoc -or -not (Test-Path $InstallLoc)) { return $null }

    # Сначала ищем в корне и в стандартных подпапках
    $searchDirs = @(
        $InstallLoc,
        (Join-Path $InstallLoc "Bin"),
        (Join-Path $InstallLoc "bin"),
        (Join-Path $InstallLoc "Program"),
        (Join-Path $InstallLoc "Programs")
    )

    foreach ($dir in $searchDirs) {
        if (-not (Test-Path $dir)) { continue }
        foreach ($exe in $ExeNames) {
            $f = Join-Path $dir $exe
            if (Test-Path $f) { return $f }
        }
    }

    # Потом глубокий рекурсивный поиск по приоритету имён
    foreach ($exe in $ExeNames) {
        $f = Get-ChildItem $InstallLoc -Recurse -Filter $exe -ErrorAction SilentlyContinue -Depth 3 | Select-Object -First 1
        if ($f) { return $f.FullName }
    }
    return $null
}

# ─── Все установленные CAD/CAM ───
function Get-CadInstalled {
    $result = @()
    $registry = Get-CadRegistry

    foreach ($key in $script:CAD_APPS.Keys) {
        $app = $script:CAD_APPS[$key]

        # Ищем в реестре запись, чей DisplayName совпадает с одним из ключевых слов
        $entry = $registry | Where-Object {
            $name = $_.DisplayName
            ($app.Keys | Where-Object { $name -match [regex]::Escape($_) }) -ne $null
        } | Select-Object -First 1

        $installLoc = $null
        if ($entry) { $installLoc = $entry.InstallLocation }

        # Ищем exe
        $exePath = $null
        if ($installLoc) {
            $exePath = Find-CadExe -InstallLoc $installLoc -ExeNames $app.Exes
        }

        # Fallback — поиск в Program Files по ключевым словам из Keys
        if (-not $exePath) {
            foreach ($keyword in $app.Keys) {
                $searchRoots = @("$env:ProgramFiles", "${env:ProgramFiles(x86)}")
                foreach ($root in $searchRoots) {
                    $dirs = Get-ChildItem $root -Directory -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match [regex]::Escape($keyword) }
                    foreach ($d in $dirs) {
                        $exePath = Find-CadExe -InstallLoc $d.FullName -ExeNames $app.Exes
                        if ($exePath) { break }
                    }
                    if ($exePath) { break }
                }
                if ($exePath) { break }
            }
        }

        if ($exePath) {
            $result += [PSCustomObject]@{
                Key         = $key
                Name        = $app.Name
                Type        = $app.Type
                Path        = $exePath
                InstallLoc  = $installLoc
                Version     = if ($entry) { $entry.DisplayVersion } else { "" }
            }
        }
    }
    return $result
}

# ─── Показать список установленных ───
function cad-list {
    Write-Host ""
    Write-Host "  Поиск CAD/CAM через реестр..." -ForegroundColor Yellow
    $found = Get-CadInstalled

    if (-not $found) {
        Write-Host "  Ничего не найдено" -ForegroundColor Yellow
        Write-Host ""
        return
    }

    $cad = $found | Where-Object { $_.Type -eq "CAD" }
    $cam = $found | Where-Object { $_.Type -eq "CAM" }

    if ($cad) {
        Write-Host ""
        Write-Host "  CAD (проектирование):" -ForegroundColor Cyan
        Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
        foreach ($f in $cad) {
            Write-Host "  [$($f.Key.PadRight(12))] " -NoNewline -ForegroundColor Yellow
            Write-Host "$($f.Name) " -NoNewline -ForegroundColor White
            if ($f.Version) { Write-Host "v$($f.Version) " -NoNewline -ForegroundColor DarkGray }
            Write-Host ""
            Write-Host "      $($f.Path)" -ForegroundColor DarkGray
        }
    }
    if ($cam) {
        Write-Host ""
        Write-Host "  CAM (обработка):" -ForegroundColor Cyan
        Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
        foreach ($f in $cam) {
            Write-Host "  [$($f.Key.PadRight(12))] " -NoNewline -ForegroundColor Yellow
            Write-Host "$($f.Name) " -NoNewline -ForegroundColor White
            if ($f.Version) { Write-Host "v$($f.Version) " -NoNewline -ForegroundColor DarkGray }
            Write-Host ""
            Write-Host "      $($f.Path)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
    Write-Host "  Запуск: cad <ключ>" -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Запуск программы ───
function cad {
    param([string]$Key = "")

    if (-not $Key -or $Key -eq "list") {
        if ($Key -eq "list") { cad-list; return }
        Write-Host ""
        Write-Host "  CAD/CAM launcher" -ForegroundColor Cyan
        Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  cad list           — что установлено" -ForegroundColor Gray
        Write-Host "  cad <ключ>         — запустить" -ForegroundColor Gray
        Write-Host "  cad-files [путь]   — найти проекты" -ForegroundColor Gray
        Write-Host "  cad-open <файл>    — открыть файл" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  Ключи: " -NoNewline -ForegroundColor Yellow
        Write-Host (($script:CAD_APPS.Keys | Sort-Object) -join "  ") -ForegroundColor Gray
        Write-Host ""
        return
    }

    $k = $Key.ToLower()
    if (-not $script:CAD_APPS.ContainsKey($k)) {
        Write-Host "  Неизвестный ключ: $Key" -ForegroundColor Red
        return
    }

    $app = $script:CAD_APPS[$k]
    Write-Host "  Ищу $($app.Name)..." -ForegroundColor Yellow

    $found = Get-CadInstalled | Where-Object { $_.Key -eq $k } | Select-Object -First 1
    if (-not $found) {
        Write-Host "  $($app.Name) не найден" -ForegroundColor Red
        return
    }

    Write-Host "  Запускаю: $($found.Path)" -ForegroundColor Green
    Start-Process $found.Path
    Write-Host ""
}

# ─── Открытие файла ───
function cad-open {
    param([Parameter(Mandatory)][string]$File)
    if (-not (Test-Path $File)) {
        Write-Host "  Файл не найден: $File" -ForegroundColor Red
        return
    }

    $ext = [System.IO.Path]::GetExtension($File).ToLower()
    $extMap = @{
        ".sldprt"="solidworks"; ".sldasm"="solidworks"; ".slddrw"="solidworks"
        ".dwg"="autocad"; ".dxf"="autocad"
        ".ipt"="inventor"; ".iam"="inventor"
        ".f3d"="fusion"; ".f3z"="fusion"
        ".prt"="nx"; ".asm"="nx"
        ".catpart"="catia"; ".catproduct"="catia"
        ".m3d"="kompas"; ".cdw"="kompas"; ".a3d"="kompas"; ".spw"="kompas"; ".frw"="kompas"
        ".fcstd"="freecad"; ".3dm"="rhino"; ".skp"="sketchup"; ".pln"="archicad"
        ".mcam"="mastercam"; ".mcx"="mastercam"
        ".sldcam"="solidcam"; ".hm"="hypermill"; ".dgk"="powermill"; ".esp"="esprit"
    }

    if (-not $extMap.ContainsKey($ext)) {
        Write-Host "  Неизвестное расширение: $ext. Открываю системной ассоциацией." -ForegroundColor Yellow
        Start-Process $File
        return
    }

    $key = $extMap[$ext]
    $app = $script:CAD_APPS[$key]
    $found = Get-CadInstalled | Where-Object { $_.Key -eq $key } | Select-Object -First 1

    if (-not $found) {
        Write-Host "  $($app.Name) не найден. Открываю системной ассоциацией." -ForegroundColor Yellow
        Start-Process $File
        return
    }

    Write-Host "  Открываю в $($app.Name)..." -ForegroundColor Green
    Start-Process -FilePath $found.Path -ArgumentList "`"$File`""
}

# ─── Поиск проектов ───
function cad-files {
    param([string]$Path = "$HOME", [int]$MaxResults = 30)

    $extensions = @(".sldprt",".sldasm",".slddrw",".dwg",".dxf",".ipt",".iam",
                    ".f3d",".f3z",".prt",".asm",".catpart",".catproduct",
                    ".m3d",".a3d",".cdw",".spw",".fcstd",".3dm",".skp",".pln",
                    ".mcam",".mcx",".sldcam",".hm",".dgk",".esp")

    Write-Host ""
    Write-Host "  Поиск CAD-проектов в $Path ..." -ForegroundColor Yellow
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan

    $files = Get-ChildItem -Path $Path -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extensions -contains $_.Extension.ToLower() } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $MaxResults

    if (-not $files) {
        Write-Host "  Ничего не найдено" -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    foreach ($f in $files) {
        $kb = [math]::Round($f.Length / 1KB, 1)
        Write-Host "  $($f.Extension.PadRight(12)) " -NoNewline -ForegroundColor Cyan
        Write-Host "$($f.Name)" -NoNewline -ForegroundColor White
        Write-Host "  ($kb KB, $($f.LastWriteTime.ToString('yyyy-MM-dd')))" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  Найдено: $($files.Count)" -ForegroundColor Cyan
    Write-Host ""
}

function cad-help {
    Write-Host ""
    Write-Host "  CAD/CAM Launcher v2" -ForegroundColor Cyan
    Write-Host "  ─────────────────────────────────────────" -ForegroundColor DarkCyan
    Write-Host "  cad list           — что установлено (через реестр)" -ForegroundColor Gray
    Write-Host "  cad <ключ>         — запустить программу" -ForegroundColor Gray
    Write-Host "  cad-files [путь]   — найти проекты на диске" -ForegroundColor Gray
    Write-Host "  cad-open <файл>    — открыть файл в нужной программе" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  CAD: solidworks  autocad  inventor  fusion  nx  catia  creo" -ForegroundColor Gray
    Write-Host "       kompas  freecad  rhino  sketchup  archicad" -ForegroundColor Gray
    Write-Host "  CAM: mastercam  solidcam  hypermill  powermill  esprit  camworks" -ForegroundColor Gray
    Write-Host ""
}