param([string]$SrcPath, [string]$DstPath, [int]$MaxWidth = 540, [int]$Quality = 82)
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile($SrcPath)
$r = $MaxWidth / $img.Width
if ($r -gt 1) { $r = 1 }
$w = [int]($img.Width * $r)
$h = [int]($img.Height * $r)
$bmp = New-Object System.Drawing.Bitmap($w, $h, [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, $w, $h)
$g.Dispose()
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$Quality)
$bmp.Save($DstPath, $codec, $ep)
$bmp.Dispose()
$img.Dispose()
Write-Output "saved $DstPath ${w}x${h}"
