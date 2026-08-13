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

# ── emblem crop ────────────────────────────────────────────────────────────
# Launcher icon မှာ "Try the best" စာသားက 48dp မှာ ဖတ်လို့ မရတဲ့အပြင်
# အနားပတ်လည် အဖြူကွက်ကြောင့် လိုဂိုက သေးနေတယ်။ ဒါကြောင့် စာသားပိုင်း ဖြတ်ပြီး
# gear ရဲ့ တကယ့် အနားသတ်ကို ရှာကာ အပြည့် ချဲ့ပေးတယ်။
function Get-EmblemBounds([System.Drawing.Bitmap]$bmp, [double]$IgnoreBelow = 0.78) {
  $rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
  $bmp.UnlockBits($data)

  $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
  $limit = [int]($bmp.Height * $IgnoreBelow)   # wordmark အောက်ပိုင်းကို လုံးဝ မရေတွက်
  for ($y = 0; $y -lt $limit; $y++) {
    $row = $y * $data.Stride
    for ($x = 0; $x -lt $bmp.Width; $x++) {
      $i = $row + $x * 4
      # BGRA — အဖြူ (သို့) အလွန်ဖျော့တဲ့ pixel တွေကို နောက်ခံအဖြစ် သတ်မှတ်တယ်။
      if ($bytes[$i] -lt 235 -or $bytes[$i + 1] -lt 235 -or $bytes[$i + 2] -lt 235) {
        if ($x -lt $minX) { $minX = $x }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt 0) { return $rect }   # ဘာမှ မတွေ့ရင် မူရင်းအတိုင်း

  # စတုရန်းအဖြစ် ညှိ — မဟုတ်ရင် ချဲ့လိုက်တဲ့အခါ ပုံပျက်တယ်။
  $w = $maxX - $minX + 1
  $h = $maxY - $minY + 1
  $side = [Math]::Max($w, $h)
  $cx = $minX + $w / 2.0
  $cy = $minY + $h / 2.0
  $x0 = [Math]::Max(0, [int]($cx - $side / 2.0))
  $y0 = [Math]::Max(0, [int]($cy - $side / 2.0))
  $side = [Math]::Min($side, [Math]::Min($bmp.Width - $x0, $bmp.Height - $y0))
  return New-Object System.Drawing.Rectangle($x0, $y0, $side, $side)
}

$srcBmp = New-Object System.Drawing.Bitmap($src)
$emblemRect = Get-EmblemBounds $srcBmp
$emblem = $srcBmp.Clone($emblemRect, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
Write-Output "emblem crop: $($emblemRect.Width)x$($emblemRect.Height) at ($($emblemRect.X),$($emblemRect.Y))"

# $Inset shrinks the logo inside the canvas — adaptive icons mask to a circle,
# so the art has to sit inside the safe zone or the edges get cut off.
function Render([string]$Out, [double]$Inset, [bool]$WhitePlate, [System.Drawing.Image]$Image = $null) {
  if ($null -eq $Image) { $Image = $src }
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
  $scale = [Math]::Min($target / $Image.Width, $target / $Image.Height)
  $w = $Image.Width * $scale
  $h = $Image.Height * $scale
  $g.DrawImage($Image, [float](($Size - $w) / 2), [float](($Size - $h) / 2), [float]$w, [float]$h)

  $dir = Split-Path -Parent $Out
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "  wrote $Out"
}

# ── launcher icon: emblem only, filling the tile ──
# စာသားမပါတဲ့ gear အလုံးကိုပဲ သုံးတာမို့ အနားထိ အပြည့် ချဲ့လို့ရတယ်။
Render "$root\assets\icon\app_icon.png" 0.98 $true $emblem
# Adaptive foreground က 108dp canvas ပေါ်မှာ အလယ် 72dp (66%) ပဲ မြင်ရတယ်။
# gear က စက်ဝိုင်းဖြစ်လို့ 0.72 ထိ ချဲ့လည်း ထောင့်တွေ မပြတ်ဘူး — အပြည့် မြင်ရတယ်။
Render "$root\assets\icon\app_icon_foreground.png" 0.72 $false $emblem
# ── splash: နေရာကျယ်တာမို့ စာသားပါတဲ့ လိုဂို အပြည့်အစုံ ──
Render "$root\assets\splash\splash_logo.png" 0.80 $false
Render "$root\assets\splash\splash_logo_android12.png" 0.62 $false $emblem

$emblem.Dispose(); $srcBmp.Dispose(); $src.Dispose()
Write-Output "done"
