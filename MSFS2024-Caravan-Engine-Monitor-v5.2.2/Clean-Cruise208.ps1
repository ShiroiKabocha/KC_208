$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $PSScriptRoot 'cruise208.png'
$outputPath = Join-Path $PSScriptRoot 'Assets\cruise208-clean.png'
$source = [System.Drawing.Bitmap]::FromFile($sourcePath)

# Crop just inside the baked checkerboard and render to a practical UI resolution.
$crop = [System.Drawing.Rectangle]::FromLTRB(48, 204, 1727, 668)
$output = New-Object System.Drawing.Bitmap(900, 249, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($output)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.Clear([System.Drawing.Color]::Transparent)
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$radius = 20
$path.AddArc(0, 0, $radius * 2, $radius * 2, 180, 90)
$path.AddArc($output.Width - ($radius * 2) - 1, 0, $radius * 2, $radius * 2, 270, 90)
$path.AddArc($output.Width - ($radius * 2) - 1, $output.Height - ($radius * 2) - 1, $radius * 2, $radius * 2, 0, 90)
$path.AddArc(0, $output.Height - ($radius * 2) - 1, $radius * 2, $radius * 2, 90, 90)
$path.CloseFigure()
$graphics.SetClip($path)
$graphics.DrawImage($source, [System.Drawing.Rectangle]::new(0, 0, $output.Width, $output.Height), $crop, [System.Drawing.GraphicsUnit]::Pixel)
$graphics.Dispose()
$source.Dispose()
$path.Dispose()

$output.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
$output.Dispose()
Write-Host "Created $outputPath"
