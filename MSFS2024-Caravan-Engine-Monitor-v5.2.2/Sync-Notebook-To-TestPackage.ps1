$ErrorActionPreference = 'Stop'

$sourcePath = Join-Path $PSScriptRoot 'Dashboard-Preview-Atmospheric.html'
$packagePath = Join-Path (Split-Path $PSScriptRoot -Parent) '208-EICAS-Atmospheric-Modules-Test-2\Dashboard.html'

$source = [IO.File]::ReadAllText($sourcePath)
$package = [IO.File]::ReadAllText($packagePath)

$stylePattern = '(?s)\.manual-overlay\{.*?(?=main\[data-theme="caravan-utility"\])'
$manualPattern = "(?s)(manual\.innerHTML=)'(<section class=`"manual-book`".*?</section>)'(;document\.body\.appendChild\(manual\);)"

$sourceStyle = [regex]::Match($source, $stylePattern)
$sourceManual = [regex]::Match($source, $manualPattern)
if (-not $sourceStyle.Success -or -not $sourceManual.Success) {
    throw 'Could not locate the generated notebook styles or content.'
}

$package = [regex]::Replace($package, $stylePattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $sourceStyle.Value }, 1)
$package = [regex]::Replace($package, $manualPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $sourceManual.Value }, 1)

[IO.File]::WriteAllText($packagePath, $package, [Text.UTF8Encoding]::new($false))
Write-Host "Synced notebook content and styling to $packagePath"
