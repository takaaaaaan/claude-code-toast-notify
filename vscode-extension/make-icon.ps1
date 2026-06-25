param([string]$Out = (Join-Path $PSScriptRoot 'icon.png'))
# Generates a 128x128 marketplace icon: dark rounded square with a ">_" prompt.
Add-Type -AssemblyName System.Drawing
$size = 128
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'
$g.TextRenderingHint = 'AntiAliasGridFit'
$g.Clear([System.Drawing.Color]::Transparent)

# rounded dark background
$r = 24
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$path.AddArc(0, 0, $r, $r, 180, 90)
$path.AddArc($size - $r, 0, $r, $r, 270, 90)
$path.AddArc($size - $r, $size - $r, $r, $r, 0, 90)
$path.AddArc(0, $size - $r, $r, $r, 90, 90)
$path.CloseFigure()
$bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 30, 30, 40))
$g.FillPath($bg, $path)

# ">_" prompt in teal
$font = New-Object System.Drawing.Font 'Consolas', 52, ([System.Drawing.FontStyle]::Bold)
$fg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 78, 201, 176))
$fmt = New-Object System.Drawing.StringFormat
$fmt.Alignment = 'Center'; $fmt.LineAlignment = 'Center'
$g.DrawString('>_', $font, $fg, (New-Object System.Drawing.RectangleF 0, 0, $size, $size), $fmt)

$g.Dispose()
$full = [System.IO.Path]::GetFullPath($Out)
$bmp.Save($full, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Host "wrote $full"
