param([string]$Path)
Add-Type -AssemblyName System.Drawing
$b = [System.Drawing.Bitmap]::FromFile($Path)
Write-Output ("{0}x{1}" -f $b.Width, $b.Height)
$b.Dispose()
