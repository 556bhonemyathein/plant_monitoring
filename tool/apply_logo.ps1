# Builds every icon/splash source PNG from one square source logo.
#
#   powershell -File tool\apply_logo.ps1
#   dart run flutter_launcher_icons
#   dart run flutter_native_splash:create
param(
  [string]$Source = "$PSScriptRoot\..\assets\icon\image.png",
  [int]$Size = 1024
)

Add-Type -AssemblyName System.Drawing

$root = Resolve-Path "$PSScriptRoot\.."
$src = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
Write-Output "source: $Source ($($src.Width)x$($src.Height))"

# $Inset shrinks the logo inside the canvas — adaptive icons mask to a circle,
# so the art has to sit inside the safe zone or the edges get cut off.
function Render([string]$Out, [double]$Inset, [bool]$WhitePlate) {
  $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.Clear([System.Drawing.Color]::Transparent)

  if ($WhitePlate) {
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $g.FillRectangle($brush, 0, 0, $Size, $Size)
    $brush.Dispose()
  }

  # Fit the source square inside the canvas, keeping its aspect ratio.
  $target = $Size * $Inset
  $scale = [Math]::Min($target / $src.Width, $target / $src.Height)
  $w = $src.Width * $scale
  $h = $src.Height * $scale
  $g.DrawImage($src, [float](($Size - $w) / 2), [float](($Size - $h) / 2), [float]$w, [float]$h)

  $dir = Split-Path -Parent $Out
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "  wrote $Out"
}

# Store / legacy launcher icon — full bleed, white plate behind it.
Render "$root\assets\icon\app_icon.png" 1.0 $true
# Android adaptive foreground — transparent, inside the circular safe zone.
Render "$root\assets\icon\app_icon_foreground.png" 0.62 $false
# Splash — the wordmark stays readable here, there is room for it.
Render "$root\assets\splash\splash_logo.png" 0.80 $false
# Android 12 splash masks to a circle, so it needs the tighter inset.
Render "$root\assets\splash\splash_logo_android12.png" 0.60 $false

$src.Dispose()
Write-Output "done"
