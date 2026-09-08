# Vehicle Maintenance Dashboard

A private-first, read-only vehicle maintenance dashboard. PowerShell renders a garage home page and separate vehicle pages from a local JSON record. The browser UI never writes data or sends information over the network.

## What belongs in Git

- PowerShell renderer and installation tools.
- Sanitized sample data.
- Text-based sample artwork.
- Tests and operating documentation.

## What must never be committed

- Real vehicle identification numbers or owner details.
- Real service histories, odometers, costs or invoice references.
- Invoices, receipts, evidence, inbox files, exports or backups.
- Runtime logs or generated private HTML pages.

The `.gitignore` and privacy test enforce these boundaries, but always run the test before pushing.

## Install a safe sample

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-Dashboard.ps1
```

By default this creates a local runtime under the current user's Documents folder. It copies the renderer and sample SVG artwork, creates private folders, installs the sanitized example data only when no canonical data exists, and renders the pages.

For an existing private runtime, provide its path:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Install-Dashboard.ps1 -DashboardRoot 'E:\PrivateVehicleDashboard'
```

The installer does not overwrite an existing canonical data file.

## Update a vehicle

The owner starts a ChatGPT conversation such as `يلا نحدث الهوندا`. ChatGPT first reviews the latest canonical JSON, generated HTML and resume record. If evidence exists, the owner places it in the vehicle's `Inbox/<vehicle>/New` folder. ChatGPT reviews it, makes a complete backup, updates the JSON with PowerShell only, regenerates all pages, validates both vehicles and archives the original document after success.

See [docs/CHATGPT_WORKFLOW.md](docs/CHATGPT_WORKFLOW.md) for the complete operating contract.

## Verify before every push

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Repository.ps1
```

The test parses the sample JSON, renders all sample pages, checks read-only behavior and scans the repository for common private-data and binary-file mistakes.

## Recovery on another computer

GitHub restores the code, not the owner's records. Keep the private runtime in a separate encrypted backup. On a replacement computer:

1. Clone this repository.
2. Run `scripts/Install-Dashboard.ps1` to create the runtime structure.
3. Restore `Data`, `Evidence`, `Inbox`, the resume record and any private assets from the encrypted backup.
4. Run the renderer and privacy-safe validation.

See [docs/RECOVERY.md](docs/RECOVERY.md) for the recommended 3-2-1 backup model.

## License

No public license is granted. This repository is intended for private owner use unless a license is added later.
