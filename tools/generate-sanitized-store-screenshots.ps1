param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDirectory,
  [Parameter(Mandatory = $true)]
  [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Drawing

function Color([string]$hex) {
  return [System.Drawing.ColorTranslator]::FromHtml($hex)
}

function Fill-Block(
  [System.Drawing.Graphics]$graphics,
  [string]$hex,
  [int]$x,
  [int]$y,
  [int]$width,
  [int]$height
) {
  $brush = [System.Drawing.SolidBrush]::new((Color $hex))
  try {
    $graphics.FillRectangle($brush, $x, $y, $width, $height)
  } finally {
    $brush.Dispose()
  }
}

function Draw-Text(
  [System.Drawing.Graphics]$graphics,
  [string]$text,
  [string]$hex,
  [int]$size,
  [bool]$bold,
  [int]$x,
  [int]$y,
  [int]$width,
  [int]$height,
  [bool]$center = $false
) {
  $style = if ($bold) {
    [System.Drawing.FontStyle]::Bold
  } else {
    [System.Drawing.FontStyle]::Regular
  }
  $font = [System.Drawing.Font]::new(
    'Segoe UI',
    [single]$size,
    $style,
    [System.Drawing.GraphicsUnit]::Pixel
  )
  $brush = [System.Drawing.SolidBrush]::new((Color $hex))
  $format = [System.Drawing.StringFormat]::new()
  try {
    $format.Trimming = [System.Drawing.StringTrimming]::EllipsisCharacter
    $format.FormatFlags = [System.Drawing.StringFormatFlags]::NoWrap
    if ($center) {
      $format.Alignment = [System.Drawing.StringAlignment]::Center
      $format.LineAlignment = [System.Drawing.StringAlignment]::Center
    }
    $rectangle = [System.Drawing.RectangleF]::new($x, $y, $width, $height)
    $graphics.DrawString($text, $font, $brush, $rectangle, $format)
  } finally {
    $format.Dispose()
    $brush.Dispose()
    $font.Dispose()
  }
}

function Open-Editable([string]$path) {
  $source = [System.Drawing.Image]::FromFile($path)
  try {
    if ($source.Width -ne 590 -or $source.Height -ne 1280) {
      throw "Unexpected source dimensions for $path"
    }
    $bitmap = [System.Drawing.Bitmap]::new(
      590,
      1280,
      [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
      # The supplied iPhone captures are tagged at 72 DPI while a new Windows
      # bitmap defaults to 96 DPI. DrawImageUnscaled still applies that physical
      # resolution difference on this runtime, enlarging the source by 4/3 and
      # clipping its bottom edge. Explicit pixel rectangles keep the capture
      # pixel-for-pixel so every privacy mask lands deterministically.
      $destination = [System.Drawing.Rectangle]::new(0, 0, 590, 1280)
      $sourceRectangle = [System.Drawing.Rectangle]::new(0, 0, 590, 1280)
      $graphics.DrawImage(
        $source,
        $destination,
        $sourceRectangle,
        [System.Drawing.GraphicsUnit]::Pixel
      )
    } finally {
      $graphics.Dispose()
    }
    return $bitmap
  } finally {
    $source.Dispose()
  }
}

function Clear-PhoneChrome([System.Drawing.Graphics]$graphics) {
  # The supplied captures include a device status bar.  App Store previews must
  # show only the product UI, so remove that chrome before any screen-specific
  # replacements are drawn.
  Fill-Block $graphics '#F6F7F9' 0 0 590 76
}

function Save-AppStorePng(
  [System.Drawing.Bitmap]$source,
  [string]$path
) {
  $target = [System.Drawing.Bitmap]::new(
    1242,
    2688,
    [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
  )
  $graphics = [System.Drawing.Graphics]::FromImage($target)
  try {
    $graphics.Clear([System.Drawing.Color]::White)
    $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $destination = [System.Drawing.Rectangle]::new(0, 0, 1242, 2688)
    $crop = [System.Drawing.Rectangle]::new(0, 0, 590, 1277)
    $graphics.DrawImage(
      $source,
      $destination,
      $crop.X,
      $crop.Y,
      $crop.Width,
      $crop.Height,
      [System.Drawing.GraphicsUnit]::Pixel
    )
  } finally {
    $graphics.Dispose()
  }
  try {
    $target.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally {
    $target.Dispose()
  }
}

if (-not (Test-Path -LiteralPath $SourceDirectory -PathType Container)) {
  throw "Source directory does not exist: $SourceDirectory"
}
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

$background = '#F6F7F9'
$white = '#FFFFFF'
$dark = '#111827'
$muted = '#6B7280'
$blue = '#087CF0'
$codePanel = '#EBECF0'

# 1. Home — replace every personal/property reference and the live invite code.
$image = Open-Editable (Join-Path $SourceDirectory '6-Photo-6.jpg')
try {
  $g = [System.Drawing.Graphics]::FromImage($image)
  try {
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Clear-PhoneChrome $g
    Fill-Block $g $background 18 102 360 72
    Draw-Text $g 'Hey Taylor' $dark 28 $true 21 108 300 38
    Draw-Text $g 'Shared Home' $muted 18 $false 22 146 300 27

    # Property title/address, including the truncated second address instance.
    Fill-Block $g $white 107 402 440 63
    Draw-Text $g 'Shared Home' $dark 21 $true 116 407 330 31
    Draw-Text $g 'Sydney NSW' $muted 15 $false 116 438 330 25

    # Replace the complete glyph area while preserving the capture's genuine
    # rounded invite-code panel.
    Fill-Block $g $codePanel 198 850 210 45
    Draw-Text $g 'DEMO42' $blue 24 $true 198 850 210 45 $true
  } finally {
    $g.Dispose()
  }
  Save-AppStorePng $image (Join-Path $OutputDirectory '01-home.png')
} finally {
  $image.Dispose()
}

# 2. Expenses — replace names and unsuitable labels with synthetic household data.
$image = Open-Editable (Join-Path $SourceDirectory '4-Photo-4.jpg')
try {
  $g = [System.Drawing.Graphics]::FromImage($image)
  try {
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Clear-PhoneChrome $g
    # Removes the stranded loading spinner above the future-version control.
    Fill-Block $g $background 274 91 42 26

    # Each rectangle covers the complete editable portion of its card.  The
    # leading category icon and card silhouette are retained from the capture.
    Fill-Block $g $white 104 365 445 165
    Draw-Text $g 'Home internet' $dark 20 $true 171 370 240 31
    Draw-Text $g '$99.00' $dark 21 $true 456 370 90 31
    Draw-Text $g 'Monthly household bill' $muted 15 $false 171 405 260 25
    Draw-Text $g 'Paid by Taylor  ·  Aug 9' $muted 16 $false 109 438 330 27
    Draw-Text $g 'Split across 3 housemates' $muted 16 $false 109 495 330 27

    Fill-Block $g $white 104 584 445 107
    Draw-Text $g 'Weekly rent' $dark 20 $true 204 590 210 31
    Draw-Text $g '$150.00' $dark 21 $true 456 590 90 31
    Draw-Text $g 'Shared by Alex  ·  Jun 3' $muted 15 $false 109 624 330 25
    Draw-Text $g 'Split across 3 housemates' $muted 16 $false 109 662 330 25

    Fill-Block $g $white 104 744 445 78
    Draw-Text $g 'Cleaning supplies' $dark 20 $true 143 750 270 31
    Draw-Text $g '$12.50' $dark 21 $true 456 750 91 31
    Draw-Text $g 'Paid by Alex  ·  Jun 2' $muted 15 $false 109 784 330 25

    Fill-Block $g $white 104 848 445 119
    Draw-Text $g 'Groceries' $dark 20 $true 204 856 210 31
    Draw-Text $g '$100.00' $dark 21 $true 456 856 90 31
    Draw-Text $g 'Paid by Sam  ·  May 1' $muted 15 $false 109 890 330 25
    Draw-Text $g 'Split across 3 housemates' $muted 16 $false 109 928 330 25

    Fill-Block $g $white 104 1013 445 112
    Draw-Text $g 'Electricity bill' $dark 20 $true 143 1021 250 31
    Draw-Text $g '$67.00' $dark 21 $true 456 1021 91 31
    Draw-Text $g 'Paid by Alex  ·  May 1' $muted 15 $false 109 1055 330 25
    Draw-Text $g 'Split across 3 housemates' $muted 16 $false 109 1095 330 25
  } finally {
    $g.Dispose()
  }
  Save-AppStorePng $image (Join-Path $OutputDirectory '02-expenses.png')
} finally {
  $image.Dispose()
}

# 3. Spending — remove the overlapping status-bar fragment and activity name.
$image = Open-Editable (Join-Path $SourceDirectory '5-Photo-5.jpg')
try {
  $g = [System.Drawing.Graphics]::FromImage($image)
  try {
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Clear-PhoneChrome $g
    Draw-Text $g 'Spending' $dark 27 $true 22 24 260 40
    Fill-Block $g $white 91 1043 310 34
    Draw-Text $g 'Taylor  ·  Aug 9' $muted 15 $false 92 1048 255 25
  } finally {
    $g.Dispose()
  }
  Save-AppStorePng $image (Join-Path $OutputDirectory '03-spending.png')
} finally {
  $image.Dispose()
}

# 4. Messages — replace address, live-looking invite code, username, and chat text.
$image = Open-Editable (Join-Path $SourceDirectory '1-Photo-1.jpg')
try {
  $g = [System.Drawing.Graphics]::FromImage($image)
  try {
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Clear-PhoneChrome $g
    Fill-Block $g $background 18 141 350 37
    Draw-Text $g 'Shared Home' $muted 18 $false 22 144 300 28
    Fill-Block $g $codePanel 196 731 212 45
    Draw-Text $g 'DEMO42' $blue 25 $true 196 731 212 45 $true
    Fill-Block $g $white 112 1035 375 38
    Draw-Text $g 'Alex: Bin night is sorted' $muted 15 $false 115 1041 360 26
  } finally {
    $g.Dispose()
  }
  Save-AppStorePng $image (Join-Path $OutputDirectory '04-messages.png')
} finally {
  $image.Dispose()
}

# 5. Rental Passport — replace all contact and property details.
$image = Open-Editable (Join-Path $SourceDirectory '2-Photo-2.jpg')
try {
  $g = [System.Drawing.Graphics]::FromImage($image)
  try {
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    Clear-PhoneChrome $g
    Fill-Block $g $white 145 181 350 128
    Draw-Text $g 'Taylor Smith' $dark 23 $true 153 188 260 34
    Draw-Text $g 'taylor@example.com' $muted 17 $false 153 226 300 28
    Draw-Text $g 'Shared Home' $muted 16 $false 153 267 300 26
    Fill-Block $g $white 104 710 445 66
    Draw-Text $g 'Shared Home' $dark 21 $true 116 715 330 32
    Draw-Text $g 'Sydney NSW' $muted 15 $false 116 747 330 25
  } finally {
    $g.Dispose()
  }
  Save-AppStorePng $image (Join-Path $OutputDirectory '05-rental-passport.png')
} finally {
  $image.Dispose()
}

$outputNames = @(
  '01-home.png',
  '02-expenses.png',
  '03-spending.png',
  '04-messages.png',
  '05-rental-passport.png'
)

$outputNames |
  ForEach-Object {
    $outputPath = Join-Path $OutputDirectory $_
    if (-not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
      throw "Expected output was not created: $_"
    }
    $bitmap = [System.Drawing.Bitmap]::FromFile($outputPath)
    try {
      if ($bitmap.Width -ne 1242 -or $bitmap.Height -ne 2688) {
        throw "Invalid output dimensions: $_"
      }
      if ($bitmap.PixelFormat -ne [System.Drawing.Imaging.PixelFormat]::Format24bppRgb) {
        throw "Output is not 24-bit RGB: $_"
      }
      [pscustomobject]@{
        Name = $_
        Width = $bitmap.Width
        Height = $bitmap.Height
        PixelFormat = $bitmap.PixelFormat.ToString()
        Bytes = (Get-Item -LiteralPath $outputPath).Length
        Sha256 = (Get-FileHash -LiteralPath $outputPath -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    } finally {
      $bitmap.Dispose()
    }
  }
