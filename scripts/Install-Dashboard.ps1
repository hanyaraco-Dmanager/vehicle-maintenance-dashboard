[CmdletBinding()]
param(
    [string]$DashboardRoot = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'VehicleMaintenanceDashboard')
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repositoryRoot = Split-Path -Parent $PSScriptRoot
$rendererSource = Join-Path $repositoryRoot 'src\Update-VehicleStatusPage.ps1'
$sampleData = Join-Path $repositoryRoot 'sample\Data\Vehicle_Status_Data.example.json'
$sampleAssets = Join-Path $repositoryRoot 'sample\Assets'

foreach ($required in @($rendererSource, $sampleData, $sampleAssets)) {
    if (-not (Test-Path -LiteralPath $required)) { throw "Repository file is missing: $required" }
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if (Test-Path -LiteralPath $DashboardRoot -PathType Container) {
    $backup = Join-Path $DashboardRoot "Backups\PRE_CODE_INSTALL_$timestamp"
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($name in @('Update-VehicleStatusPage.ps1','Vehicle_Status.html','index.html','Honda.html','Sonata.html')) {
        $existing = Join-Path $DashboardRoot $name
        if (Test-Path -LiteralPath $existing -PathType Leaf) { Copy-Item -LiteralPath $existing -Destination $backup -Force }
    }
}

foreach ($relative in @('Data','Assets','Evidence','Inbox\Honda\New','Inbox\Honda\Processed','Inbox\Sonata\New','Inbox\Sonata\Processed','Backups')) {
    New-Item -ItemType Directory -Path (Join-Path $DashboardRoot $relative) -Force | Out-Null
}

Copy-Item -LiteralPath $rendererSource -Destination (Join-Path $DashboardRoot 'Update-VehicleStatusPage.ps1') -Force
Get-ChildItem -LiteralPath $sampleAssets -File -Filter '*.svg' | Copy-Item -Destination (Join-Path $DashboardRoot 'Assets') -Force

$canonicalData = Join-Path $DashboardRoot 'Data\Vehicle_Status_Data.json'
if (-not (Test-Path -LiteralPath $canonicalData -PathType Leaf)) {
    Copy-Item -LiteralPath $sampleData -Destination $canonicalData
    Write-Host 'Installed sanitized sample data. Restore private data separately when required.'
} else {
    Get-Content -Raw -LiteralPath $canonicalData | ConvertFrom-Json | Out-Null
    Write-Host 'Existing canonical data preserved.'
}

& (Join-Path $DashboardRoot 'Update-VehicleStatusPage.ps1') -DataPath $canonicalData -OutputPath (Join-Path $DashboardRoot 'Vehicle_Status.html')

Write-Host ''
Write-Host 'DASHBOARD INSTALLATION COMPLETED'
Write-Host "Runtime: $DashboardRoot"
Write-Host "Garage: $(Join-Path $DashboardRoot 'Vehicle_Status.html')"
