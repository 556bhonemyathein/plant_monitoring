# "Try the best" logo — gear ring + orange wreath + wheat ear + green leaves.
# Design grid is 1024x1024; everything scales from $Size.
#
#   dart run flutter_launcher_icons        # after regenerating the PNGs
#   dart run flutter_native_splash:create
param(
  [Parameter(Mandatory = $true)][string]$Out,
  [int]$Size = 1024,
  [switch]$Transparent,   # no white plate behind the art (adaptive foreground)
  [switch]$WithText,      # draw the "Try the best" wordmark (splash only)
  [switch]$LightText,     # white wordmark, for the green splash background
  [double]$Inset = 1.0    # shrink the art (adaptive icons need a safe zone)
)

Add-Type -AssemblyName System.Drawing

$S = $Size
$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::Transparent)

$k = $S / 1024.0
$cx = $S / 2.0
$cy = $S / 2.0

$dark  = [System.Drawing.Color]::FromArgb(255, 51, 51, 51)
$gold  = [System.Drawing.Color]::FromArgb(255, 244, 166, 26)
$green = [System.Drawing.Color]::FromArgb(255, 22, 122, 58)
$white = [System.Drawing.Color]::White

$brDark  = New-Object System.Drawing.SolidBrush($dark)
$brGold  = New-Object System.Drawing.SolidBrush($gold)
$brGreen = New-Object System.Drawing.SolidBrush($green)
$brWhite = New-Object System.Drawing.SolidBrush($white)

# ---------- plate ----------
if (-not $Transparent) {
  $g.FillRectangle($brWhite, 0, 0, $S, $S)
}

# Art is drawn on the 1024 grid, then scaled/inset around the centre.
$state = $g.Save()
$g.TranslateTransform([float]$cx, [float]$cy)
$g.ScaleTransform([float]($k * $Inset), [float]($k * $Inset))
if ($WithText) { $g.TranslateTransform(0, -40) }   # leave room for the wordmark
$g.TranslateTransform([float](-512), [float](-512))

function Ring([double]$outer, [double]$inner, $brush) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddEllipse([float](512 - $outer), [float](512 - $outer), [float]($outer * 2), [float]($outer * 2))
  $p.AddEllipse([float](512 - $inner), [float](512 - $inner), [float]($inner * 2), [float]($inner * 2))
  $g.FillPath($brush, $p)     # even-odd fill punches the inner circle out
  $p.Dispose()
}

# ---------- gear ----------
# Teeth first, so the ring covers their inner ends.
$toothCount = 20
$toothW = 62.0
$toothH = 104.0
$toothR = 404.0
for ($i = 0; $i -lt $toothCount; $i++) {
  $angle = 360.0 / $toothCount * $i
  $s2 = $g.Save()
  $g.TranslateTransform(512, 512)
  $g.RotateTransform([float]$angle)
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  # Slightly tapered tooth with rounded outer corners.
  $p.AddPolygon(@(
    (New-Object System.Drawing.PointF([float](-$toothW / 2), [float](-$toothR))),
    (New-Object System.Drawing.PointF([float]($toothW / 2), [float](-$toothR))),
    (New-Object System.Drawing.PointF([float]($toothW / 2 * 0.72), [float](-$toothR - $toothH))),
    (New-Object System.Drawing.PointF([float](-$toothW / 2 * 0.72), [float](-$toothR - $toothH)))
  ))
  $g.FillPath($brDark, $p)
  $p.Dispose()
  $g.Restore($s2)
}
Ring 428 336 $brDark

# White face inside the gear (also on transparent variants, so the art reads).
$g.FillEllipse($brWhite, [float](512 - 334), [float](512 - 334), [float](334 * 2), [float](334 * 2))

# ---------- orange wreath (two tapered horns) ----------
function Horn([double]$startDeg, [double]$sweepDeg) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $outer = 300.0
  $inner = 232.0
  $p.AddArc([float](512 - $outer), [float](512 - $outer), [float]($outer * 2), [float]($outer * 2), [float]$startDeg, [float]$sweepDeg)
  $p.AddArc([float](512 - $inner), [float](512 - $inner), [float]($inner * 2), [float]($inner * 2), [float]($startDeg + $sweepDeg), [float](-$sweepDeg))
  $p.CloseFigure()
  $g.FillPath($brGold, $p)
  $p.Dispose()
}
Horn 128 130    # left horn
Horn -78 130    # right horn

# ---------- wheat ear ----------
# Stalk
$stalk = New-Object System.Drawing.Drawing2D.GraphicsPath
$stalk.AddRectangle((New-Object System.Drawing.RectangleF([float](512 - 11), [float]300, [float]22, [float]330)))
$g.FillPath($brGold, $stalk)
$stalk.Dispose()

# Grain pairs, biggest at the bottom
$rows = @(
  @{ y = 545; len = 132; w = 58; tilt = 38 },
  @{ y = 478; len = 128; w = 56; tilt = 36 },
  @{ y = 413; len = 120; w = 53; tilt = 34 },
  @{ y = 350; len = 108; w = 49; tilt = 32 }
)
foreach ($row in $rows) {
  foreach ($side in @(-1, 1)) {
    $s2 = $g.Save()
    $g.TranslateTransform(512, [float]$row.y)
    $g.RotateTransform([float]($side * $row.tilt))
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddEllipse([float]($side * 6), [float](-$row.len), [float]($side * $row.w), [float]$row.len)
    $g.FillPath($brGold, $p)
    $p.Dispose()
    $g.Restore($s2)
  }
}
# Top grain
$tip = New-Object System.Drawing.Drawing2D.GraphicsPath
$tip.AddEllipse([float](512 - 32), [float]196, [float]64, [float]150)
$g.FillPath($brGold, $tip)
$tip.Dispose()

# ---------- green leaves ----------
# Each leaf is two bezier curves meeting at a point — mirrored for the other side.
function Leaf([double]$tipX, [double]$tipY, [double]$c1x, [double]$c1y, [double]$c2x, [double]$c2y, [double]$backX, [double]$backY) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddBezier(
    (New-Object System.Drawing.PointF([float]512, [float]690)),
    (New-Object System.Drawing.PointF([float]$c1x, [float]$c1y)),
    (New-Object System.Drawing.PointF([float]$c2x, [float]$c2y)),
    (New-Object System.Drawing.PointF([float]$tipX, [float]$tipY)))
  $p.AddBezier(
    (New-Object System.Drawing.PointF([float]$tipX, [float]$tipY)),
    (New-Object System.Drawing.PointF([float]$backX, [float]$backY)),
    (New-Object System.Drawing.PointF([float](512 + ($c1x - 512) * 0.35), [float]($c1y + 96))),
    (New-Object System.Drawing.PointF([float]512, [float]690)))
  $p.CloseFigure()
  $g.FillPath($brGreen, $p)
  $p.Dispose()
}
foreach ($side in @(-1, 1)) {
  # Outer (long, sweeping) leaf
  Leaf (512 + $side * 268) 548  (512 + $side * 92) 612  (512 + $side * 196) 548  (512 + $side * 150) 690
  # Inner (short, upright) leaf
  Leaf (512 + $side * 138) 486  (512 + $side * 40) 628  (512 + $side * 96) 528  (512 + $side * 70) 660
}

$g.Restore($state)

# ---------- wordmark ----------
if ($WithText) {
  $fontSize = [float](96 * $k)
  $font = New-Object System.Drawing.Font('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $textBrush = if ($LightText) { $brWhite } else { $brGreen }
  $g.DrawString('Try the best', $font, $textBrush, [float]$cx, [float](880 * $k), $fmt)
  $font.Dispose(); $fmt.Dispose()
}

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose(); $bmp.Dispose()
$brDark.Dispose(); $brGold.Dispose(); $brGreen.Dispose(); $brWhite.Dispose()
Write-Output "wrote $Out ($S x $S)"
