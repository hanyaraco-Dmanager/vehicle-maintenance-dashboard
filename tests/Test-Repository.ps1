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

$published = Get-Content -Raw (Join-Path $PSScriptRoot 'Published-Snapshot.json') | ConvertFrom-Json
$approvedPaths = @()
foreach ($entry in $published.PSObject.Properties) {
    $snapshotPath = Join-Path $repositoryRoot $entry.Name
    if ((Get-FileHash -LiteralPath $snapshotPath -Algorithm SHA256).Hash -ne $entry.Value) {
        throw "Published snapshot changed; repeat owner-scope/privacy review: $($entry.Name)"
    }
    $approvedPaths += $snapshotPath.Replace('/', '\')
}
$forbiddenExtensions = @('.pdf','.png','.jpg','.jpeg','.webp','.gif','.bmp','.tif','.tiff','.zip','.7z','.rar','.log','.bak')
$badFiles = @($files | Where-Object { ($forbiddenExtensions -contains $_.Extension.ToLowerInvariant()) -and ($approvedPaths -notcontains $_.FullName) })
if ($badFiles.Count -gt 0) { throw "Forbidden binary/private file found: $($badFiles.FullName -join ', ')" }

$privacyPatterns = @(
    '(?i)\\Users\\[^\\]+',
    '(?<![A-Z0-9])[A-HJ-NPR-Z0-9]{17}(?![A-Z0-9])',
    '(?i)invoice\s*(number|no\.?|reference)\s*[:#]?\s*[0-9]{5,}',
    '(?i)D:\\Vehicle_Maintenance_Software',
    '(?i)D:\\Sonata_Maintenance'
)
foreach ($file in $files) {
    if ($file.Extension -eq '.png' -and $approvedPaths -contains $file.FullName) { continue }
    $content = Get-Content -Raw -LiteralPath $file.FullName -ErrorAction SilentlyContinue
    foreach ($pattern in $privacyPatterns) {
        # Exact reviewed snapshots retain owner-authorized local invoice paths.
        if ($approvedPaths -contains $file.FullName -and $pattern.StartsWith('(?i)D:')) { continue }
        if ($content -match $pattern) { throw "Privacy pattern found in $($file.FullName): $pattern" }
    }
}

Write-Host 'Repository tests: PASS'
Write-Host "Files scanned: $($files.Count)"
Write-Host 'Private documents: NONE; only two hash-verified generated PNGs allowed'
Write-Host 'VIN-like values: NONE; reviewed local invoice paths preserved in hash-locked HTML'
