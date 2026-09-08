[CmdletBinding()]
param(
    [string]$DataPath = "",
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
if ([string]::IsNullOrWhiteSpace($DataPath)) { $DataPath = Join-Path $PSScriptRoot "Data\Vehicle_Status_Data.json" }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $PSScriptRoot "Vehicle_Status.html" }

function Get-V {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $Default }
    return $property.Value
}

function Html {
    param($Value)
    return [Net.WebUtility]::HtmlEncode([string]$Value)
}

function Format-Number {
    param($Value, [int]$Decimals = 0)
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { return "-" }
    $number = [decimal]0
    if (-not [decimal]::TryParse([string]$Value, [Globalization.NumberStyles]::Any, [Globalization.CultureInfo]::InvariantCulture, [ref]$number)) {
        return [string]$Value
    }
    return $number.ToString("N$Decimals", [Globalization.CultureInfo]::GetCultureInfo("en-US"))
}

function Get-WebPath {
    param([string]$Path)
    return $Path.Replace('\', '/')
}

function Get-StatusClass {
    param([string]$Status)
    switch -Regex ($Status) {
        'OVERDUE|DO NOW|DUE NOW' { return "danger" }
        'DUE SOON|VERIFY|SOURCE REVIEW|CONDITION|TIME DUE' { return "warning" }
        'UP TO DATE|LATER|NO SERVICE' { return "good" }
        default { return "neutral" }
    }
}

function Get-StatusLabel {
    param([string]$Status)
    switch ($Status) {
        "INSPECTION OVERDUE" { return "INSPECTION OVERDUE" }
        "CONDITION-BASED" { return "CHECK BY CONDITION" }
        "TIME DUE DATE REQUIRES VERIFICATION" { return "VERIFY SERVICE DATE" }
        default { return $Status }
    }
}

function Get-DueText {
    param($Item, [string]$Unit)
    $parts = @()
    $distance = Get-V $Item "NextDueDistance"
    $date = [string](Get-V $Item "NextDueDate" "")
    if ($null -ne $distance -and -not [string]::IsNullOrWhiteSpace([string]$distance)) { $parts += "$(Format-Number $distance) $Unit" }
    if ($date) { $parts += $date }
    if ($parts.Count -eq 0) { return "No calculated due point" }
    return ($parts -join " or ")
}

function Get-FileLinkHtml {
    param([string]$Path, [string]$Title = "Document")
    if ([string]::IsNullOrWhiteSpace($Path)) { return '<span class="muted">No document linked</span>' }

    $resolved = if ([IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $PSScriptRoot $Path }
    $display = Html $Path
    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        return ('<span class="muted">Stored path: <code>{0}</code> (file not currently found)</span>' -f $display)
    }

    $uri = ([Uri]([IO.Path]::GetFullPath($resolved))).AbsoluteUri
    return ('<button type="button" class="document-button open-document no-print" data-url="{0}" data-title="{1}">View document</button><code class="file-path">{2}</code><span class="print-document">Document: {2}</span>' -f (Html $uri), (Html $Title), $display)
}

function Render-CountCards {
    param($Vehicle)
    $cards = foreach ($count in @($Vehicle.Counts)) {
        @"
<div class="count-card $(Html $count.Class)"><span>$(Html $count.Label)</span><strong>$(Html $count.Value)</strong></div>
"@
    }
    return ($cards -join "`n")
}

function Render-AttentionRows {
    param($Vehicle)
    $attention = @($Vehicle.MaintenanceItems | Where-Object { [string]$_.Status -notin @("UP TO DATE", "LATER", "NO SERVICE REQUIRED") })
    if ($attention.Count -eq 0) { return '<p class="empty">No currently open maintenance item.</p>' }
    $rows = foreach ($item in $attention) {
        $class = Get-StatusClass ([string]$item.Status)
        @"
<article class="attention-row $class">
  <div class="attention-main"><span class="status $class">$(Html (Get-StatusLabel ([string]$item.Status)))</span><h4>$(Html $item.Name)</h4><p>$(Html $item.Reason)</p></div>
  <div class="attention-side"><b>Action</b><span>$(Html $item.Action)</span><b>Due</b><span>$(Html (Get-DueText $item $Vehicle.Unit))</span></div>
</article>
"@
    }
    return ($rows -join "`n")
}

function Render-AllMaintenance {
    param($Vehicle)
    $rows = foreach ($item in @($Vehicle.MaintenanceItems)) {
        $class = Get-StatusClass ([string]$item.Status)
        @"
<tr><td><strong>$(Html $item.Name)</strong><small>$(Html $item.Category)</small></td><td><span class="status $class">$(Html (Get-StatusLabel ([string]$item.Status)))</span></td><td>$(Html $item.Action)</td><td>$(Html (Get-DueText $item $Vehicle.Unit))</td><td>$(Html $item.Reason)</td></tr>
"@
    }
    return ($rows -join "`n")
}

function Render-History {
    param($Vehicle, [string]$PropertyName, [string]$EmptyMessage)
    $entries = @(@(Get-V $Vehicle $PropertyName @()) | Sort-Object Date -Descending)
    if ($entries.Count -eq 0) { return ('<p class="empty">{0}</p>' -f (Html $EmptyMessage)) }
    $rows = foreach ($entry in $entries) {
        $odometer = if ($null -ne $entry.Odometer -and -not [string]::IsNullOrWhiteSpace([string]$entry.Odometer)) { "$(Format-Number $entry.Odometer) $($Vehicle.Unit)" } else { "Odometer not recorded" }
        $reference = if ([string]$entry.Reference) { " | Ref: $(Html $entry.Reference)" } else { "" }
        $cost = if ($null -ne $entry.AmountAED -and [decimal]$entry.AmountAED -ne 0) { "<strong>AED $(Format-Number $entry.AmountAED 2)</strong>" } else { "" }
        @"
<article class="history-row">
  <div class="history-date"><strong>$(Html $entry.Date)</strong><span>$(Html $odometer)</span></div>
  <div class="history-body"><h4>$(Html $entry.Description)</h4><p>$(Html $entry.Details)</p><small>$(Html $entry.Vendor)$reference</small></div>
  <div class="history-cost">$cost</div>
  <div class="history-file">$(Get-FileLinkHtml ([string]$entry.EvidencePath) ([string]$entry.Description))</div>
</article>
"@
    }
    return ($rows -join "`n")
}

function Render-CostSummary {
    param($Vehicle)
    $estimate = Get-V $Vehicle "PlanningEstimate"
    $estimatedAmount = if ($null -ne $estimate) { [decimal](Get-V $estimate "AmountAED" 0) } else { [decimal]0 }
    $estimateDetails = if ($null -ne $estimate) {
        $breakdown = foreach ($line in @(Get-V $estimate "Breakdown" @())) {
            '<div class="estimate-line"><div><strong>{0}</strong><small>{1}</small></div><b>AED {2}</b></div>' -f (Html $line.Label), (Html $line.Basis), (Format-Number $line.AmountAED 2)
        }
        @"
<div class="estimate-note"><strong>Estimate basis &mdash; not confirmed payment history</strong><p>$(Html $estimate.Method)</p>$($breakdown -join "`n")</div>
"@
    } else {
        '<p class="muted">No estimated bills are included for this vehicle.</p>'
    }
    return @"
<div class="money-grid">
  <div class="money-card confirmed"><span>Confirmed bills</span><strong>AED $(Format-Number $Vehicle.ConfirmedSpendAED 2)</strong><small>Supported by recorded bills or owner-confirmed payments</small></div>
  <div class="money-card estimated"><span>Estimated bills</span><strong>AED $(Format-Number $estimatedAmount 2)</strong><small>Planning estimate only; not counted as confirmed spending</small></div>
</div>
$estimateDetails
"@
}

function Get-CommonStyles {
    return @'
:root{--navy:#101a2c;--blue:#2b5f9e;--bg:#eef2f5;--card:#fff;--line:#d7dee7;--text:#101722;--muted:#687587;--danger:#bd2026;--danger-bg:#fff2f2;--warning:#a75a08;--warning-bg:#fff7e8;--good:#087641;--good-bg:#eaf8f0;--accent:#315f8c;--accent2:#dce4ec;--shadow:0 12px 32px rgba(16,26,44,.09)}
*{box-sizing:border-box}html{scroll-behavior:smooth}body{margin:0;background:var(--bg);color:var(--text);font:15px/1.55 "Segoe UI",Arial,sans-serif}a{color:var(--accent)}button{font:inherit}code{font:11px Consolas,monospace;word-break:break-all}.topbar{position:sticky;top:0;z-index:20;background:rgba(245,247,249,.96);backdrop-filter:blur(12px);border-bottom:1px solid var(--line)}.topbar-inner{max-width:1420px;margin:auto;padding:13px 22px;display:flex;align-items:center;justify-content:space-between;gap:16px}.brand strong{display:block;font-size:19px}.brand small{color:var(--muted)}.actions{display:flex;gap:9px;flex-wrap:wrap}.button,.actions a{border:1px solid var(--line);border-radius:10px;padding:9px 14px;background:#fff;color:var(--text);font-weight:800;text-decoration:none;cursor:pointer}.button.primary{background:var(--accent);border-color:var(--accent);color:#fff}.wrap{max-width:1420px;margin:28px auto;padding:0 22px 60px}.eyebrow{display:block;color:var(--accent);font-weight:900;font-size:11px;letter-spacing:.12em;text-transform:uppercase}.garage-intro{padding:32px 4px 16px}.garage-intro h1{margin:4px 0;font-size:38px}.garage-intro p{margin:0;color:var(--muted);max-width:760px}.garage-grid{display:grid;grid-template-columns:1fr 1fr;gap:22px;margin-top:18px}.garage-card{position:relative;isolation:isolate;min-height:440px;border-radius:24px;overflow:hidden;color:#fff;padding:30px;box-shadow:var(--shadow);display:flex;flex-direction:column;justify-content:space-between;background-size:cover;background-position:center}.garage-card:before{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(8,12,18,.92) 0%,rgba(8,12,18,.76) 48%,rgba(8,12,18,.25) 100%)}.garage-card.honda:after,.theme-honda .textured:after{content:"";position:absolute;inset:0;z-index:-1;opacity:.18;background:repeating-linear-gradient(90deg,#6b3f24 0,#6b3f24 2px,#b78b5e 3px,#3f2416 7px)}.garage-card.sonata:after,.theme-sonata .textured:after{content:"";position:absolute;inset:0;z-index:-1;opacity:.16;background:repeating-linear-gradient(135deg,#fff 0,#fff 1px,transparent 1px,transparent 6px)}.garage-card h2{font-size:32px;margin:5px 0}.garage-card p{margin:0;color:#e6ebf0}.garage-metrics{display:flex;gap:12px;flex-wrap:wrap;margin:18px 0}.metric-pill{background:rgba(255,255,255,.13);border:1px solid rgba(255,255,255,.24);border-radius:12px;padding:10px 13px}.metric-pill span,.metric-pill small{display:block;font-size:11px;color:#dce5ee}.metric-pill strong{font-size:20px}.open-car{align-self:flex-start;background:#fff;color:#101722;border-radius:11px;padding:11px 17px;text-decoration:none;font-weight:900}.vehicle-hero{position:relative;isolation:isolate;overflow:hidden;min-height:360px;border-radius:24px 24px 0 0;color:#fff;padding:38px;display:flex;align-items:flex-end;justify-content:space-between;gap:24px;background-size:cover;background-position:center;box-shadow:var(--shadow)}.vehicle-hero:before{content:"";position:absolute;inset:0;z-index:-2;background:inherit}.vehicle-hero:after{content:"";position:absolute;inset:0;z-index:-1;background:linear-gradient(90deg,rgba(8,12,18,.94),rgba(8,12,18,.67) 52%,rgba(8,12,18,.25))}.vehicle-hero h1{font-size:38px;margin:5px 0}.vehicle-hero p{color:#e1e7ee;margin:0}.odometer{min-width:220px;background:rgba(255,255,255,.12);border:1px solid rgba(255,255,255,.3);padding:18px 20px;border-radius:16px;text-align:right}.odometer span,.odometer small{display:block;color:#e3e8ee}.odometer strong{font-size:34px}.source-strip{display:grid;grid-template-columns:auto 1fr auto 1fr;gap:10px 18px;background:#fff;border:1px solid var(--line);border-top:0;padding:15px 22px;border-radius:0 0 18px 18px}.source-strip span{color:var(--muted);font-size:11px;text-transform:uppercase;font-weight:800}.source-strip strong{color:var(--good)}.counts{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:12px;margin:18px 0}.count-card{background:#fff;border:1px solid var(--line);border-top:4px solid #7b8796;border-radius:14px;padding:15px;box-shadow:var(--shadow)}.count-card span{display:block;color:var(--muted);font-size:11px;font-weight:900;text-transform:uppercase}.count-card strong{font-size:29px}.count-card.danger{border-top-color:var(--danger)}.count-card.warning{border-top-color:var(--warning)}.count-card.good{border-top-color:var(--good)}.panel{background:var(--card);border:1px solid var(--line);border-radius:18px;padding:24px;margin-top:16px;box-shadow:var(--shadow)}.panel-title{display:flex;align-items:flex-start;justify-content:space-between;gap:18px;margin-bottom:14px}.panel h2{font-size:24px;margin:3px 0}.attention-row{display:grid;grid-template-columns:1fr 300px;gap:20px;border:1px solid var(--line);border-left:5px solid #7b8796;border-radius:14px;padding:17px;margin:10px 0}.attention-row.danger{border-left-color:var(--danger);background:var(--danger-bg)}.attention-row.warning{border-left-color:var(--warning);background:var(--warning-bg)}.attention-main h4{font-size:17px;margin:7px 0 2px}.attention-main p{margin:0;color:#4c5969}.attention-side{display:grid;grid-template-columns:70px 1fr;gap:6px 10px;align-content:start}.attention-side b{font-size:11px;text-transform:uppercase;color:var(--muted)}.status{display:inline-block;padding:4px 9px;border-radius:999px;font-size:10px;font-weight:900;letter-spacing:.03em;background:#edf1f5}.status.danger{color:var(--danger);background:#ffe0e0}.status.warning{color:var(--warning);background:#ffedc8}.status.good{color:var(--good);background:#d9f5e6}.money-grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}.money-card{border-radius:16px;padding:22px;border:1px solid var(--line)}.money-card span,.money-card small{display:block}.money-card span{font-size:12px;text-transform:uppercase;font-weight:900;color:var(--muted)}.money-card strong{display:block;font-size:31px;margin:3px 0}.money-card.confirmed{background:var(--good-bg);border-color:#bce8d0}.money-card.estimated{background:var(--warning-bg);border-color:#ead1a7}.estimate-note{margin-top:15px;border:1px dashed var(--warning);border-radius:14px;padding:16px;background:#fffaf0}.estimate-note>p{color:#68461e}.estimate-line{display:grid;grid-template-columns:1fr auto;gap:15px;border-top:1px solid #ead8b8;padding:10px 0}.estimate-line small{display:block;color:var(--muted)}.estimate-line b{font-size:17px}.split{display:grid;grid-template-columns:1fr 1fr;gap:26px}.split>div+div{border-left:1px solid var(--line);padding-left:26px}.table-wrap{overflow:auto}table{width:100%;min-width:990px;border-collapse:collapse}th,td{text-align:left;border-bottom:1px solid var(--line);padding:11px;vertical-align:top}th{font-size:11px;text-transform:uppercase;color:var(--muted);background:#f6f8fa}td small{display:block;color:var(--muted)}details{border-top:1px solid var(--line);padding-top:12px;margin-top:12px}summary{cursor:pointer;font-weight:900;color:var(--accent)}.history-row{display:grid;grid-template-columns:145px 1fr 125px minmax(210px,300px);gap:15px;padding:15px 0;border-bottom:1px solid var(--line)}.history-date span{display:block;color:var(--muted)}.history-body h4{margin:0}.history-body p{margin:3px 0;color:#4c5969}.history-body small{color:var(--muted)}.history-cost{text-align:right}.history-file{display:flex;flex-direction:column;align-items:flex-start;gap:5px}.document-button{background:var(--accent);color:#fff;border:0;border-radius:8px;padding:7px 11px;font-weight:800;cursor:pointer}.file-path{color:var(--muted)}.print-document{display:none}.muted,.empty{color:var(--muted)}.document-dialog{width:min(1100px,94vw);height:min(820px,90vh);padding:0;border:0;border-radius:18px;box-shadow:0 24px 70px rgba(0,0,0,.35)}.document-dialog::backdrop{background:rgba(5,10,18,.7)}.dialog-head{height:62px;padding:12px 16px;display:flex;align-items:center;justify-content:space-between;gap:12px;background:#fff;border-bottom:1px solid var(--line)}.dialog-head strong{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.dialog-actions{display:flex;gap:8px}.dialog-actions a,.dialog-actions button{border:1px solid var(--line);border-radius:8px;background:#fff;color:var(--text);padding:7px 10px;text-decoration:none;cursor:pointer}.document-frame{width:100%;height:calc(100% - 62px);border:0;background:#e7ebef}.footer{max-width:1420px;margin:0 auto 38px;padding:0 22px;text-align:center;color:var(--muted)}.theme-honda{--accent:#70452c;--accent2:#ddc5a9;--bg:#f3eee7}.theme-sonata{--accent:#26323e;--accent2:#cbd0d5;--bg:#edf0f2}
@media(max-width:950px){.garage-grid,.money-grid,.split{grid-template-columns:1fr}.garage-card{min-height:380px}.vehicle-hero,.topbar-inner{align-items:flex-start;flex-direction:column}.odometer{width:100%;text-align:left}.attention-row,.history-row{grid-template-columns:1fr}.history-cost{text-align:left}.split>div+div{border-left:0;border-top:1px solid var(--line);padding:20px 0 0}.source-strip{grid-template-columns:1fr 1fr}}
@media print{@page{size:A4;margin:11mm}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}.no-print,.topbar,.document-dialog,.footer{display:none!important}body{background:#fff;font-size:10px}.wrap{max-width:none;margin:0;padding:0}.vehicle-hero{min-height:190px;border-radius:0;padding:22px;box-shadow:none}.vehicle-hero h1{font-size:28px}.odometer strong{font-size:24px}.source-strip,.count-card,.panel{box-shadow:none}.counts{grid-template-columns:repeat(5,1fr);gap:6px;margin:8px 0}.count-card{padding:8px}.count-card strong{font-size:20px}.panel{padding:12px;margin-top:8px;border-radius:8px;break-inside:auto}.panel-title{margin-bottom:6px}.panel h2{font-size:17px}.attention-row{grid-template-columns:1fr 220px;padding:8px;margin:5px 0;break-inside:avoid}.attention-main h4{font-size:12px}.money-grid{grid-template-columns:1fr 1fr}.money-card{padding:12px}.money-card strong{font-size:22px}.estimate-note{padding:10px}.split{grid-template-columns:1fr 1fr}.table-wrap{overflow:visible}table{min-width:0;font-size:8px}th,td{padding:5px}.history-row{grid-template-columns:90px 1fr 85px;gap:8px;padding:7px 0;break-inside:avoid}.history-file{grid-column:1/-1}.file-path{display:none}.print-document{display:block;color:#555;font-size:7px;word-break:break-all}details{display:block}details>summary{display:none}details>*{display:block!important}}
'@
}

function Get-InteractionScript {
    return @'
<script>
(() => {
  const dialog = document.getElementById('documentDialog');
  if (dialog) {
    const frame = document.getElementById('documentFrame');
    const title = document.getElementById('documentTitle');
    const fallback = document.getElementById('documentFallback');
    document.querySelectorAll('.open-document').forEach(button => {
      button.addEventListener('click', () => {
        frame.src = button.dataset.url;
        title.textContent = button.dataset.title || 'Document';
        fallback.href = button.dataset.url;
        dialog.showModal();
      });
    });
    document.getElementById('closeDocument').addEventListener('click', () => dialog.close());
    dialog.addEventListener('close', () => { frame.src = 'about:blank'; });
    dialog.addEventListener('click', event => { if (event.target === dialog) dialog.close(); });
  }
  document.querySelectorAll('.print-button').forEach(button => button.addEventListener('click', () => window.print()));
})();
</script>
'@
}

function Get-DocumentDialog {
    return @'
<dialog class="document-dialog no-print" id="documentDialog">
  <div class="dialog-head"><strong id="documentTitle">Document</strong><div class="dialog-actions"><a id="documentFallback" href="#" target="_blank">Open separately</a><button type="button" id="closeDocument">Close</button></div></div>
  <iframe class="document-frame" id="documentFrame" title="Vehicle document preview"></iframe>
</dialog>
'@
}

function Render-GarageCard {
    param($Vehicle)
    $estimate = Get-V $Vehicle "PlanningEstimate"
    $estimated = if ($null -ne $estimate) { [decimal](Get-V $estimate "AmountAED" 0) } else { [decimal]0 }
    $important = @($Vehicle.Counts | Where-Object { $_.Class -in @("danger", "warning") } | Select-Object -First 3)
    $statusPills = foreach ($count in $important) { '<div class="metric-pill"><span>{0}</span><strong>{1}</strong></div>' -f (Html $count.Label), (Html $count.Value) }
    $photo = Html (Get-WebPath ([string]$Vehicle.PhotoPath))
    return @"
<article class="garage-card $(Html $Vehicle.Theme)" style="background-image:url('$photo')">
  <div><span class="eyebrow">$(Html $Vehicle.StorageMode) &middot; READ ONLY</span><h2>$(Html $Vehicle.DisplayName)</h2><p>$(Html $Vehicle.Subtitle)</p><div class="garage-metrics"><div class="metric-pill"><span>Odometer</span><strong>$(Format-Number $Vehicle.Odometer)</strong><small>$(Html $Vehicle.Unit)</small></div>$($statusPills -join "`n")</div></div>
  <div><div class="garage-metrics"><div class="metric-pill"><span>Confirmed bills</span><strong>AED $(Format-Number $Vehicle.ConfirmedSpendAED 2)</strong></div><div class="metric-pill"><span>Estimated bills</span><strong>AED $(Format-Number $estimated 2)</strong></div></div><a class="open-car" href="$(Html $Vehicle.PageFile)">Open vehicle record &rarr;</a></div>
</article>
"@
}

function Render-HomePage {
    param($Data)
    $cards = foreach ($vehicle in @($Data.Vehicles)) { Render-GarageCard $vehicle }
    $styles = Get-CommonStyles
    return @"
<!doctype html><html lang="en" dir="ltr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>My Garage &mdash; Vehicle Status</title><style>$styles</style></head>
<body><header class="topbar"><div class="topbar-inner"><div class="brand"><strong>My Garage</strong><small>Private static vehicle records &middot; Updated $(Html $Data.GeneratedAt)</small></div></div></header>
<main class="wrap"><section class="garage-intro"><span class="eyebrow">DAILY VEHICLE STATUS</span><h1>My Garage</h1><p>Select a vehicle to see exactly what needs attention, confirmed and estimated ownership costs, complete service history and linked documents.</p></section><section class="garage-grid">$($cards -join "`n")</section></main>
<footer class="footer">Read-only dashboard. Updates are performed through the PowerShell-managed project files only.</footer></body></html>
"@
}

function Render-VehiclePage {
    param($Vehicle, $Data)
    $styles = Get-CommonStyles
    $photo = Html (Get-WebPath ([string]$Vehicle.PhotoPath))
    $policy = foreach ($line in @($Vehicle.OwnerPolicy)) { '<li>{0}</li>' -f (Html $line) }
    $dialog = Get-DocumentDialog
    $script = Get-InteractionScript
    return @"
<!doctype html><html lang="en" dir="ltr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>$(Html $Vehicle.DisplayName) &mdash; Vehicle Record</title><style>$styles</style></head>
<body class="theme-$(Html $Vehicle.Theme)">
<header class="topbar no-print"><div class="topbar-inner"><div class="brand"><strong>$(Html $Vehicle.DisplayName)</strong><small>Private read-only vehicle record</small></div><nav class="actions"><a href="Vehicle_Status.html">&larr; My Garage</a><button type="button" class="button primary print-button">Export / Print PDF</button></nav></div></header>
<main class="wrap">
  <section class="vehicle-hero textured" style="background-image:url('$photo')"><div><span class="eyebrow">$(Html $Vehicle.StorageMode) &middot; PROFESSIONAL VEHICLE HISTORY</span><h1>$(Html $Vehicle.DisplayName)</h1><p>$(Html $Vehicle.Subtitle)</p></div><div class="odometer"><span>Current odometer</span><strong>$(Format-Number $Vehicle.Odometer)</strong> <b>$(Html $Vehicle.Unit)</b><small>As of $(Html $Vehicle.AsOfDate)</small></div></section>
  <div class="source-strip"><span>Manufacturer source</span><strong>$(Html $Vehicle.SourceLock)</strong><span>Record mode</span><strong>STATIC READ ONLY</strong></div>
  <section class="counts">$(Render-CountCards $Vehicle)</section>
  <section class="panel"><div class="panel-title"><div><span class="eyebrow">DECISION CENTER</span><h2>What needs attention?</h2></div></div>$(Render-AttentionRows $Vehicle)</section>
  <section class="panel"><div class="panel-title"><div><span class="eyebrow">OWNERSHIP COST</span><h2>Bills and estimated history</h2></div></div>$(Render-CostSummary $Vehicle)<details open><summary>Financial history</summary>$(Render-History $Vehicle "FinancialHistory" "No financial history recorded.")</details></section>
  <section class="panel"><div class="panel-title"><div><span class="eyebrow">FULL STATUS</span><h2>Complete maintenance status</h2></div></div><div class="table-wrap"><table><thead><tr><th>Item</th><th>Status</th><th>Action</th><th>Next due</th><th>Reason</th></tr></thead><tbody>$(Render-AllMaintenance $Vehicle)</tbody></table></div></section>
  <section class="panel split"><div><span class="eyebrow">OWNER POLICY &mdash; SEPARATE</span><h2>Owner maintenance policy</h2><ul>$($policy -join "`n")</ul></div><div><span class="eyebrow">LOCKED SOURCE ONLY</span><h2>Manufacturer fluid specifications</h2><p>$(Html $Vehicle.FluidSpecificationState)</p></div></section>
  <section class="panel"><div class="panel-title"><div><span class="eyebrow">RECORDED WORK</span><h2>Maintenance history</h2></div></div>$(Render-History $Vehicle "MaintenanceHistory" "No maintenance history recorded.")</section>
  <section class="panel"><div class="panel-title"><div><span class="eyebrow">REPAIRS</span><h2>Repair history</h2></div></div>$(Render-History $Vehicle "RepairHistory" "No repair history recorded.")</section>
</main><footer class="footer">Generated $(Html $Data.GeneratedAt) &middot; Documents remain in local project folders and are referenced by link.</footer>$dialog$script</body></html>
"@
}

if (-not (Test-Path -LiteralPath $DataPath -PathType Leaf)) { throw "Dashboard data file was not found: $DataPath" }
$data = Get-Content -Raw -LiteralPath $DataPath | ConvertFrom-Json
if (@($data.Vehicles).Count -eq 0) { throw "Dashboard contains no vehicles." }

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory -PathType Container)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$existingOutputs = @($OutputPath, (Join-Path $outputDirectory "index.html")) + @($data.Vehicles | ForEach-Object { Join-Path $outputDirectory ([string]$_.PageFile) })
$existingOutputs = @($existingOutputs | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
if ($existingOutputs.Count -gt 0) {
    $backup = Join-Path $PSScriptRoot "Backups\HTML_$timestamp"
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    foreach ($file in $existingOutputs) { Copy-Item -LiteralPath $file -Destination (Join-Path $backup ([IO.Path]::GetFileName($file))) -Force }
}

$utf8 = [Text.UTF8Encoding]::new($true)
$homePageHtml = Render-HomePage $data
[IO.File]::WriteAllText($OutputPath, $homePageHtml, $utf8)
[IO.File]::WriteAllText((Join-Path $outputDirectory "index.html"), $homePageHtml, $utf8)
foreach ($vehicle in @($data.Vehicles)) {
    [IO.File]::WriteAllText((Join-Path $outputDirectory ([string]$vehicle.PageFile)), (Render-VehiclePage $vehicle $data), $utf8)
}

Write-Host "Vehicle dashboard updated successfully."
Write-Host "Home: $OutputPath"
foreach ($vehicle in @($data.Vehicles)) { Write-Host "$($vehicle.DisplayName): $(Join-Path $outputDirectory ([string]$vehicle.PageFile))" }
Write-Host "Data source: $DataPath"
