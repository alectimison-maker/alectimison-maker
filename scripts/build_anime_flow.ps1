$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$repo = "C:\Users\chenyuxin\alectimison-maker"
$download = "C:\Users\chenyuxin\Downloads"
$outDir = Join-Path $repo "assets\anime-posters"
if (!(Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

$srcFiles = Get-ChildItem $download -File | Where-Object {
  $_.Extension -match "\.(png|jpg|jpeg|webp)$"
} | Sort-Object LastWriteTime

if ($srcFiles.Count -eq 0) {
  throw "No image files found in Downloads."
}

# Normalize to portrait posters with same ratio and size.
$tw = 240
$th = 360
$targetRatio = $tw / $th

$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object {
  $_.MimeType -eq "image/jpeg"
}
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
  [System.Drawing.Imaging.Encoder]::Quality,
  88L
)

Get-ChildItem $outDir -File -ErrorAction SilentlyContinue | Where-Object {
  $_.Name -ne ".gitkeep"
} | Remove-Item -Force

$idx = 1
foreach ($f in $srcFiles) {
  $img = [System.Drawing.Image]::FromFile($f.FullName)
  try {
    $w = [double]$img.Width
    $h = [double]$img.Height
    $srcRatio = $w / $h

    if ($srcRatio -gt $targetRatio) {
      $cropH = [int]$h
      $cropW = [int][Math]::Round($h * $targetRatio)
      $cropX = [int][Math]::Round(($w - $cropW) / 2)
      $cropY = 0
    } else {
      $cropW = [int]$w
      $cropH = [int][Math]::Round($w / $targetRatio)
      $cropX = 0
      $cropY = [int][Math]::Round(($h - $cropH) / 2)
    }

    $bmp = New-Object System.Drawing.Bitmap($tw, $th)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
      $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
      $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
      $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

      $srcRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropW, $cropH)
      $dstRect = New-Object System.Drawing.Rectangle(0, 0, $tw, $th)
      $g.DrawImage($img, $dstRect, $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    } finally {
      $g.Dispose()
    }

    $outPath = Join-Path $outDir ("poster-{0:D2}.jpg" -f $idx)
    $bmp.Save($outPath, $jpegCodec, $encParams)
    $bmp.Dispose()
    $idx++
  } finally {
    $img.Dispose()
  }
}

$posters = Get-ChildItem $outDir -File | Where-Object {
  $_.Name -like "poster-*.jpg"
} | Sort-Object Name

if ($posters.Count -eq 0) {
  throw "No generated anime posters."
}

$tileW = 108
$tileH = 162
$gap = 116
$trackWidth = $gap * $posters.Count
$canvasW = 1200
$canvasH = 176
$yOffset = 7

function Escape-Xml([string]$s) {
  $s = $s -replace "&", "&amp;"
  $s = $s -replace "<", "&lt;"
  $s = $s -replace ">", "&gt;"
  return $s
}

$imgData = @()
foreach ($p in $posters) {
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($p.FullName))
  $imgData += "data:image/jpeg;base64,$b64"
}

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine(("<svg xmlns=""http://www.w3.org/2000/svg"" width=""{0}"" height=""{1}"" viewBox=""0 0 {0} {1}"" role=""img"" aria-label=""Flowing anime poster wall"">" -f $canvasW, $canvasH))
$null = $sb.AppendLine("  <defs>")
$null = $sb.AppendLine(("    <clipPath id=""animeClip""><rect x=""0"" y=""0"" width=""{0}"" height=""{1}"" rx=""8""/></clipPath>" -f $tileW, $tileH))
$null = $sb.AppendLine("  </defs>")
$null = $sb.AppendLine(("  <g transform=""translate(0,{0})"">" -f $yOffset))

$null = $sb.AppendLine("    <g id=""track-a"">")
for ($i = 0; $i -lt $imgData.Count; $i++) {
  $x = $i * $gap
  $href = Escape-Xml $imgData[$i]
  $null = $sb.AppendLine(("      <g transform=""translate({0},0)"">" -f $x))
  $null = $sb.AppendLine(("        <image href=""{0}"" x=""0"" y=""0"" width=""{1}"" height=""{2}"" preserveAspectRatio=""xMidYMid slice"" clip-path=""url(#animeClip)""/>" -f $href, $tileW, $tileH))
  $null = $sb.AppendLine(("        <rect x=""0"" y=""0"" width=""{0}"" height=""{1}"" rx=""8"" fill=""none"" stroke=""rgba(120,120,120,0.28)""/>" -f $tileW, $tileH))
  $null = $sb.AppendLine("      </g>")
}
$null = $sb.AppendLine(("      <animateTransform attributeName=""transform"" type=""translate"" from=""0 0"" to=""-{0} 0"" dur=""54s"" repeatCount=""indefinite""/>" -f $trackWidth))
$null = $sb.AppendLine("    </g>")

$null = $sb.AppendLine(("    <g id=""track-b"" transform=""translate({0},0)"">" -f $trackWidth))
for ($i = 0; $i -lt $imgData.Count; $i++) {
  $x = $i * $gap
  $href = Escape-Xml $imgData[$i]
  $null = $sb.AppendLine(("      <g transform=""translate({0},0)"">" -f $x))
  $null = $sb.AppendLine(("        <image href=""{0}"" x=""0"" y=""0"" width=""{1}"" height=""{2}"" preserveAspectRatio=""xMidYMid slice"" clip-path=""url(#animeClip)""/>" -f $href, $tileW, $tileH))
  $null = $sb.AppendLine(("        <rect x=""0"" y=""0"" width=""{0}"" height=""{1}"" rx=""8"" fill=""none"" stroke=""rgba(120,120,120,0.28)""/>" -f $tileW, $tileH))
  $null = $sb.AppendLine("      </g>")
}
$null = $sb.AppendLine(("      <animateTransform attributeName=""transform"" type=""translate"" from=""{0} 0"" to=""0 0"" dur=""54s"" repeatCount=""indefinite""/>" -f $trackWidth))
$null = $sb.AppendLine("    </g>")

$null = $sb.AppendLine("  </g>")
$null = $sb.AppendLine("</svg>")

$svgPath = Join-Path $repo "assets\anime-posters-flow.svg"
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($svgPath, $sb.ToString(), $utf8NoBom)

Write-Output ("Generated posters: {0}" -f $posters.Count)
Get-Item $svgPath | Select-Object FullName, Length, LastWriteTime
