> Pages deployment exception (2026-09-09): The owner explicitly authorized publication of the current four HTML views and two generated vehicle images, including displayed maintenance records, costs and existing local invoice links. These six exact files are hash-locked in tests/Published-Snapshot.json. This exception supersedes the general generated-HTML restriction below only for this reviewed snapshot. Canonical JSON, VINs, owner identity/contact details, documents, Evidence, Inbox and Backups remain excluded. Local invoice links are intentionally preserved and may not work online.

# Backup and recovery

Use a 3-2-1 strategy:

- Copy 1: the active private runtime on the main computer.
- Copy 2: a scheduled backup on a BitLocker-protected external drive.
- Copy 3: an off-site encrypted copy, such as OneDrive Personal Vault or another end-to-end encrypted storage location.

GitHub is the development and code backup. It is not the private vehicle-record backup.

## Minimum private recovery set

- Canonical `Data` folder.
- `Evidence` and `Inbox` folders.
- `DASHBOARD_RESUME.md` and private ChatGPT Project instructions.
- Any private artwork required by the current generated pages.
- At least the latest known-good full dashboard backup.

## Recovery drill

At least quarterly, test recovery into a temporary folder:

1. Clone the GitHub repository.
2. Run the sample installer.
3. Restore a copy of the private recovery set.
4. Run the renderer.
5. Open all pages and verify totals, links and PDF printing.

Keep a written record of the last successful recovery test. A backup is not considered reliable until restoration has been tested.

