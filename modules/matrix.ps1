# ARGONOV SHELL · matrix rain v2

# Огромный набор символов: катакана, кириллица, греческий, латиница,
# цифры, математика, символы, стрелки, боксовые
$script:MATRIX_CHARS = (
    # Halfwidth katakana (японский, 1 клетка)
    'ｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏﾐﾑﾒﾓﾔﾕﾖﾗﾘﾙﾚﾛﾜﾝ' +
    # Кириллица
    'АБВГДЕЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдежзийклмнопрстуфхцчшщъыьэюя' +
    # Греческий
    'αβγδεζηθικλμνξοπρστυφχψωΑΒΓΔΕΖΗΘΙΚΛΜΝΞΟΠΡΣΤΥΦΧΨΩ' +
    # Латиница + цифры
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789' +
    # Математика
    '∑∫√∞∂π∆Ω∇≈≠±×÷∅∈∉∋∌∝∟∠∡∢' +
    # Символы
    '★☆♠♣♥♦◆◇○●□■△▽▲▼◄►' +
    # Стрелки и рамки
    '↑↓←→↔↕↖↗↘↙┃━┏┓┗┛┣┫┳┻╋'
).ToCharArray()

function matrix {
    param(
        [int]$Fps = 30,
        [int]$MinTail = 8,
        [int]$MaxTail = 30
    )

    $esc = [char]27
    $cols = [Console]::WindowWidth
    $rows = [Console]::WindowHeight

    if ($cols -lt 20 -or $rows -lt 10) {
        Write-Host "  Окно слишком маленькое (минимум 20x10)" -ForegroundColor Red
        return
    }

    $chars = $script:MATRIX_CHARS
    $charLen = $chars.Length

    # Функция создания новой капли с рандомными параметрами
    function New-Drop {
        @{
            Y           = (Get-Random -Minimum (-$rows * 2) -Maximum 0)
            Speed       = (Get-Random -Minimum 5 -Maximum 70) / 10.0   # 0.5 .. 7.0
            TailLen     = (Get-Random -Minimum $MinTail -Maximum ($MaxTail + 1))
            FlashChance = (Get-Random -Minimum 0 -Maximum 80) / 1000.0 # 0 .. 0.08
        }
    }

    # Инициализация капель
    $drops = @()
    for ($i = 0; $i -lt $cols; $i++) {
        $drops += New-Drop
    }

    # Скрыть курсор, очистить экран
    Write-Host "$esc[?25l$esc[2J" -NoNewline

    $delay = [int](1000 / $Fps)
    if ($delay -lt 8) { $delay = 8 }

    try {
        while ($true) {
            # Выход: Esc или Q
            if ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                if ($k.Key -eq 'Escape' -or $k.Key -eq 'Q') { break }
            }

            # Изменение размера окна
            $newCols = [Console]::WindowWidth
            $newRows = [Console]::WindowHeight
            if ($newCols -ne $cols -or $newRows -ne $rows) {
                $cols = $newCols
                $rows = $newRows
                $drops = @()
                for ($i = 0; $i -lt $cols; $i++) {
                    $drops += New-Drop
                }
                Write-Host "$esc[2J" -NoNewline
            }

            # Большой буфер, чтобы меньше обращений к консоли
            $sb = [System.Text.StringBuilder]::new(131072)

            # Основной рендер — по колонкам
            for ($x = 0; $x -lt $cols; $x++) {
                $d = $drops[$x]
                $y = [int]$d.Y
                $tail = [int]$d.TailLen

                # Хвост капли
                for ($t = 0; $t -lt $tail; $t++) {
                    $cy = $y - $t
                    if ($cy -lt 0 -or $cy -ge $rows) { continue }

                    # Градиент цвета
                    if ($t -eq 0) {
                        # Голова — либо вспышка белым, либо яркая
                        if ((Get-Random -Maximum 1000) / 1000.0 -lt $d.FlashChance) {
                            $color = "$esc[38;2;255;255;255m"
                        } else {
                            $color = "$esc[38;2;220;255;220m"
                        }
                    } elseif ($t -lt 3) {
                        $color = "$esc[38;2;0;255;80m"
                    } elseif ($t -lt 7) {
                        $color = "$esc[38;2;0;200;0m"
                    } elseif ($t -lt 12) {
                        $color = "$esc[38;2;0;150;0m"
                    } elseif ($t -lt 18) {
                        $color = "$esc[38;2;0;90;0m"
                    } elseif ($t -lt 24) {
                        $color = "$esc[38;2;0;50;0m"
                    } else {
                        $color = "$esc[38;2;0;25;0m"
                    }

                    $ch = $chars[(Get-Random -Maximum $charLen)]
                    [void]$sb.Append("$esc[$($cy + 1);$($x + 1)H$color$ch")
                }

                # Стираем ячейку за хвостом
                $ey = $y - $tail
                if ($ey -ge 0 -and $ey -lt $rows) {
                    [void]$sb.Append("$esc[$($ey + 1);$($x + 1)H ")
                }

                # Двигаем каплю вниз
                $d.Y = $d.Y + $d.Speed
                if ($d.Y - $tail -gt $rows) {
                    $drops[$x] = New-Drop
                }
            }

            # Взрывы — случайные вспышки белым по экрану
            $burstCount = Get-Random -Minimum 0 -Maximum 4
            for ($b = 0; $b -lt $burstCount; $b++) {
                $bx = Get-Random -Minimum 0 -Maximum $cols
                $by = Get-Random -Minimum 0 -Maximum $rows

                # Центр вспышки — белый
                $ch = $chars[(Get-Random -Maximum $charLen)]
                [void]$sb.Append("$esc[$($by + 1);$($bx + 1)H$esc[38;2;255;255;255m$ch")

                # Соседние ячейки — светло-зелёные
                $offsets = @(@(1,0),@(-1,0),@(0,1),@(0,-1))
                foreach ($o in $offsets) {
                    $nx = $bx + $o[0]
                    $ny = $by + $o[1]
                    if ($nx -ge 0 -and $nx -lt $cols -and $ny -ge 0 -and $ny -lt $rows) {
                        $ch2 = $chars[(Get-Random -Maximum $charLen)]
                        [void]$sb.Append("$esc[$($ny + 1);$($nx + 1)H$esc[38;2;180;255;180m$ch2")
                    }
                }
            }

            [Console]::Out.Write($sb.ToString())
            [Console]::Out.Flush()
            Start-Sleep -Milliseconds $delay
        }
    } finally {
        # Восстановить курсор, сбросить цвет, очистить
        Write-Host "$esc[?25h$esc[0m$esc[2J$esc[H" -NoNewline
        Write-Host ""
    }
}

function matrix-fast {
    matrix -Fps 45 -MinTail 6 -MaxTail 16
}

function matrix-slow {
    matrix -Fps 12 -MinTail 20 -MaxTail 40
}

function matrix-long {
    matrix -Fps 30 -MinTail 30 -MaxTail 60
}

# Алиас — кириллическая "м"
Set-Alias -Name "м" -Value "matrix" -Force