[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sampleData = Join-Path $repositoryRoot 'sample\Data\Vehicle_Status_Data.example.json'
$renderer = Join-Path $repositoryRoot 'src\Update-VehicleStatusPage.ps1'
$testRoot = Join-Path $repositoryRoot 'TestResults\Latest'

New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
Get-Content -Raw -LiteralPath $sampleData | ConvertFrom-Json | Out-Null
& $renderer -DataPath $sampleData -OutputPath (Join-Path $testRoot 'Vehicle_Status.html')

foreach ($name in @('Vehicle_Status.html','index.html','Honda.html','Sonata.html')) {
    $path = Join-Path $testRoot $name
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Generated page is missing: $name" }
    $html = Get-Content -Raw -LiteralPath $path
    if ($html -match '<form|fetch\s*\(') { throw "Generated page is not read-only: $name" }
    foreach ($badCharacter in @([char]194,[char]195,[char]226)) {
        if ($html.Contains([string]$badCharacter)) { throw "Encoding artifact found in: $name" }
    }
}

$ignoredRoots = @((Join-Path $repositoryRoot '.git'), (Join-Path $repositoryRoot 'TestResults'))
$files = @(Get-ChildItem -LiteralPath $repositoryRoot -File -Recurse | Where-Object {
    $path = $_.FullName
    -not ($ignoredRoots | Where-Object { $path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })
})

$forbiddenExtensions = @('.pdf','.png','.jpg','.jpeg','.webp','.gif','.bmp','.tif','.tiff','.zip','.7z','.rar','.log','.bak')
$badFiles = @($files | Where-Object { $forbiddenExtensions -contains $_.Extension.ToLowerInvariant() })
if ($badFiles.Count -gt 0) { throw "Forbidden binary/private file found: $($badFiles.FullName -join ', ')" }

$privacyPatterns = @(
    '(?i)\\Users\\[^\\]+',
    '(?<![A-Z0-9])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])',
    '(?i)invoice\s*(number|no\.?|reference)\s*[:#]?\s*[0-9]{5,}',
    '(?i)D:\\Vehicle_Maintenance_Software',
    '(?i)D:\\Sonata_Maintenance'
)
foreach ($file in $files) {
    $content = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    foreach ($pattern in $privacyPatterns) {
        if ($content -match $pattern) { throw "Privacy pattern found in $($file.FullName): $pattern" }
    }
}

Write-Host 'Repository tests: PASS'
Write-Host "Files scanned: $($files.Count)"
Write-Host 'Private documents/binaries: NONE'
Write-Host 'VIN-like values/private local paths: NONE'
