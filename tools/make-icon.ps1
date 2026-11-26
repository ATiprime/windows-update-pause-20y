# 生成 EXE 图标（暂停符号），输出多尺寸 ICO
# 用法: powershell -ExecutionPolicy Bypass -File .\tools\make-icon.ps1

param(
    [string]$OutPath = (Join-Path $PSScriptRoot '..\src\app.ico')
)

Add-Type -AssemblyName System.Drawing

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngs  = @()

foreach ($s in $sizes) {
    $bmp = New-Object System.Drawing.Bitmap($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = 'AntiAlias'
    $g.InterpolationMode = 'HighQualityBicubic'
    $g.PixelOffsetMode   = 'HighQuality'
    $g.Clear([System.Drawing.Color]::Transparent)

    # --- 圆角方形背景 ---
    $r    = [int][math]::Round($s * 0.22)
    $d    = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc(0, 0, $d, $d, 180, 90)
    $path.AddArc($s - $d, 0, $d, $d, 270, 90)
    $path.AddArc($s - $d, $s - $d, $d, $d, 0, 90)
    $path.AddArc(0, $s - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    $rect  = New-Object System.Drawing.Rectangle(0, 0, $s, $s)
    $c1    = [System.Drawing.Color]::FromArgb(255, 59, 130, 246)
    $c2    = [System.Drawing.Color]::FromArgb(255, 29, 61, 168)
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 90)
    $g.FillPath($brush, $path)

    # --- 暂停符号（两条白色圆角竖条）---
    $bw     = [double]$s * 0.14
    $bh     = [double]$s * 0.46
    $gap    = [double]$s * 0.12
    $totalW = $bw * 2 + $gap
    $left   = ($s - $totalW) / 2
    $top    = ($s - $bh) / 2
    $white  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $br     = [double]$bw * 0.30

    foreach ($x in @($left, $left + $bw + $gap)) {
        $bp = New-Object System.Drawing.Drawing2D.GraphicsPath
        $dd = [single]($br * 2)
        $bx = [single]$x
        $by = [single]$top
        $bw2 = [single]$bw
        $bh2 = [single]$bh
        $bp.AddArc($bx, $by, $dd, $dd, 180, 90)
        $bp.AddArc($bx + $bw2 - $dd, $by, $dd, $dd, 270, 90)
        $bp.AddArc($bx + $bw2 - $dd, $by + $bh2 - $dd, $dd, $dd, 0, 90)
        $bp.AddArc($bx, $by + $bh2 - $dd, $dd, $dd, 90, 90)
        $bp.CloseFigure()
        $g.FillPath($white, $bp)
        $bp.Dispose()
    }

    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += ,($ms.ToArray())
    $ms.Dispose()
    $bmp.Dispose()
    $brush.Dispose()
    $white.Dispose()
    $path.Dispose()
}

# --- 写 ICO（每个尺寸一张 PNG 条目，Vista+ 支持）---
$fs = [System.IO.File]::Create($OutPath)
$wr = New-Object System.IO.BinaryWriter($fs)
$wr.Write([UInt16]0)
$wr.Write([UInt16]1)
$wr.Write([UInt16]$sizes.Count)

$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s   = $sizes[$i]
    $len = $pngs[$i].Length
    $dim = if ($s -ge 256) { 0 } else { $s }
    $wr.Write([byte]$dim)
    $wr.Write([byte]$dim)
    $wr.Write([byte]0)
    $wr.Write([byte]0)
    $wr.Write([UInt16]1)
    $wr.Write([UInt16]32)
    $wr.Write([UInt32]$len)
    $wr.Write([UInt32]$offset)
    $offset += $len
}
foreach ($p in $pngs) { $wr.Write($p) }

$wr.Flush(); $wr.Close(); $fs.Close()

Write-Host ("icon written: {0} ({1} bytes, sizes: {2})" -f $OutPath, (Get-Item $OutPath).Length, ($sizes -join ','))
