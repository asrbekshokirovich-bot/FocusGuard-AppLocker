Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Bitmap]::FromFile("C:\Users\User\Downloads\FocusGuardIcon.png")
$w = $img.Width
$h = $img.Height
$minX = $w; $minY = $h; $maxX = 0; $maxY = 0

for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
        $color = $img.GetPixel($x, $y)
        if ($color.A -gt 0) {
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }
}

if ($maxX -ge $minX -and $maxY -ge $minY) {
    $rect = New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
    $cropped = $img.Clone($rect, $img.PixelFormat)
    
    $outDir = "c:\Users\User\Desktop\Saas project 1\Project app locker\assets"
    if (!(Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }
    
    $outPath = Join-Path $outDir "logo.png"
    $cropped.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Success! Cropped padding and saved to $outPath"
} else {
    Write-Host "Image is fully transparent."
}
