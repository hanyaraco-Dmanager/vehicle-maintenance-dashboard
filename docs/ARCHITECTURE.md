# Architecture

The solution deliberately separates public-safe development files from private runtime records.

## Development repository

- `src/Update-VehicleStatusPage.ps1`: deterministic HTML renderer.
- `sample/Data/Vehicle_Status_Data.example.json`: fictional schema example.
- `sample/Assets/*.svg`: text-based placeholder artwork.
- `scripts/Install-Dashboard.ps1`: safe runtime bootstrap/update.
- `tests/Test-Repository.ps1`: rendering and privacy checks.
- `docs/`: workflow and recovery documentation.

## Private runtime

- `Data/Vehicle_Status_Data.json`: canonical owner record.
- `Vehicle_Status.html`, `index.html` and per-vehicle HTML: generated read-only views.
- `Evidence/`: preserved local supporting documents.
- `Inbox/<vehicle>/New`: documents waiting for review.
- `Inbox/<vehicle>/Processed/<year>`: originals preserved after successful processing.
- `Backups/`: timestamped pre-update and generated-page backups.
- `DASHBOARD_RESUME.md`: permanent operational checkpoint.

The private runtime is intentionally excluded from Git. The HTML files may contain private values even though they are static, so they must also stay out of the repository.

## Data flow

1. The owner reports a vehicle event in chat.
2. ChatGPT reviews the latest private state and evidence.
3. A complete runtime backup is created.
4. PowerShell atomically updates the canonical JSON.
5. The renderer generates static HTML.
6. Tests verify totals, links, read-only behavior and unaffected vehicles.
7. The resume record is updated and evidence is archived.

