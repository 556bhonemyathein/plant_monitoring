param(
  [string]$Out,
  [int]$Size = 1024,
  [switch]$Transparent,
  [switch]$Foreground
)

Add-Type -AssemblyName System.Drawing

$S = $Size
$bmp = New-Object System.Drawing.Bitmap($S, $S, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.Clear([System.Drawing.Color]::Transparent)

# ---------- background ----------
if (-not $Transparent) {
  $rect = New-Object System.Drawing.RectangleF(0, 0, $S, $S)
  $c1 = [System.Drawing.Color]::FromArgb(255, 26, 122, 74)   # deep green
  $c2 = [System.Drawing.Color]::FromArgb(255, 107, 191, 89)  # fresh leaf green
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $c1, $c2, 45.0)

  $r = [int]($S * 0.235)   # squircle-ish corner radius
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc(0, 0, $d, $d, 180, 90)
  $path.AddArc($S - $d, 0, $d, $d, 270, 90)
  $path.AddArc($S - $d, $S - $d, $d, $d, 0, 90)
  $path.AddArc(0, $S - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  $g.FillPath($brush, $path)
  $path.Dispose(); $brush.Dispose()
}

# scale helper: design grid is 1024x1024
$k = $S / 1024.0
function P($x, $y) { New-Object System.Drawing.PointF(([float]($x * $k)), ([float]($y * $k))) }

# On adaptive-icon foreground the art must sit inside the safe zone -> shrink art.
$artScale = 1.0
if ($Foreground) { $artScale = 0.72 }

$state = $g.Save()
$g.TranslateTransform([float]($S / 2), [float]($S / 2))
$g.ScaleTransform([float]$artScale, [float]$artScale)
$g.TranslateTransform([float](-$S / 2), [float](-$S / 2))

$white   = [System.Drawing.Color]::FromArgb(255, 255, 255, 255)
$softest = [System.Drawing.Color]::FromArgb(255, 214, 245, 214)

# ---------- leaf builder ----------
# Leaf pointing "up-right" from origin, length L, width W.
function New-Leaf([float]$L, [float]$W) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddBezier(
    (New-Object System.Drawing.PointF(0, 0)),
    (New-Object System.Drawing.PointF(($W * 1.15), (-$L * 0.18))),
    (New-Object System.Drawing.PointF(($W * 1.05), (-$L * 0.72))),
    (New-Object System.Drawing.PointF(0, (-$L)))
  )
  $p.AddBezier(
    (New-Object System.Drawing.PointF(0, (-$L))),
    (New-Object System.Drawing.PointF((-$W * 1.05), (-$L * 0.72))),
    (New-Object System.Drawing.PointF((-$W * 1.15), (-$L * 0.18))),
    (New-Object System.Drawing.PointF(0, 0))
  )
  $p.CloseFigure()
  return $p
}

function Draw-Leaf([float]$cx, [float]$cy, [float]$L, [float]$W, [float]$angle, $color) {
  $leaf = New-Leaf $L $W
  $m = New-Object System.Drawing.Drawing2D.Matrix
  $m.Translate([float]($cx * $k), [float]($cy * $k))
  $m.Rotate([float]$angle)
  $m.Scale([float]$k, [float]$k)
  $leaf.Transform($m)
  $b = New-Object System.Drawing.SolidBrush($color)
  $g.FillPath($b, $leaf)
  $b.Dispose()

  # midrib
  $rib = New-Object System.Drawing.Drawing2D.GraphicsPath
  $rib.AddLine((New-Object System.Drawing.PointF(0, 0)), (New-Object System.Drawing.PointF(0, (-$L * 0.86))))
  $rib.Transform($m)
  $penW = [float](26 * $k * ($L / 300.0))
  if ($penW -lt (6 * $k)) { $penW = [float](6 * $k) }
  $pen = New-Object System.Drawing.Pen((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90, 26, 122, 74))), $penW)
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawPath($pen, $rib)
  $pen.Dispose(); $rib.Dispose(); $m.Dispose(); $leaf.Dispose()
}

# ---------- stem ----------
$stem = New-Object System.Drawing.Drawing2D.GraphicsPath
$stem.AddBezier((P 512 800), (P 512 690), (P 512 590), (P 512 350))
$stemPen = New-Object System.Drawing.Pen($white, [float](46 * $k))
$stemPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$stemPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawPath($stemPen, $stem)
$stemPen.Dispose(); $stem.Dispose()

# ---------- leaves ----------
Draw-Leaf 512 640 300 100 72  $softest    # lower right leaf
Draw-Leaf 512 640 300 100 -72 $softest    # lower left leaf
Draw-Leaf 512 470 270 92  40  $white      # upper right leaf
Draw-Leaf 512 470 270 92  -40 $white      # upper left leaf

# ---------- water droplet (monitoring / moisture cue) ----------
$drop = New-Object System.Drawing.Drawing2D.GraphicsPath
$dx = 512.0; $dy = 300.0; $dl = 140.0; $dw = 60.0
$drop.AddBezier((P $dx ($dy - $dl)), (P ($dx + $dw * 0.55) ($dy - $dl * 0.45)), (P ($dx + $dw) ($dy - $dl * 0.12)), (P $dx $dy))
$drop.AddBezier((P $dx $dy), (P ($dx - $dw) ($dy - $dl * 0.12)), (P ($dx - $dw * 0.55) ($dy - $dl * 0.45)), (P $dx ($dy - $dl)))
$drop.CloseFigure()
# droplet sits above the sprout, rendered as a hollow ring-free solid
$dropBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 168, 226, 255))
$g.FillPath($dropBrush, $drop)
$dropBrush.Dispose(); $drop.Dispose()

# ---------- soil arc ----------
$soil = New-Object System.Drawing.Drawing2D.GraphicsPath
$soil.AddArc([float](236 * $k), [float](756 * $k), [float](552 * $k), [float](180 * $k), 210, 120)
$soilPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235, 255, 255, 255), [float](54 * $k))
$soilPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$soilPen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
$g.DrawPath($soilPen, $soil)
$soilPen.Dispose(); $soil.Dispose()

$g.Restore($state)

$dir = Split-Path -Parent $Out
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force $dir | Out-Null }
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "wrote $Out"
