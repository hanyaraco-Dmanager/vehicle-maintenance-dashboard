# ChatGPT-managed update workflow

Use this repository only as the development source. Real vehicle data belongs in the private runtime and encrypted backup.

For every new odometer reading, service, inspection, repair or expense:

1. Read the private runtime's project instructions, resume record, canonical JSON, garage HTML and target vehicle HTML.
2. Summarize the target vehicle's current status before requesting new evidence.
3. Ask only for missing facts required to record the event accurately.
4. If evidence exists, ask the owner to place the original in `Inbox/<vehicle>/New`; otherwise label the source as an owner statement and leave unknown values unknown.
5. Distinguish completed work from quotations, recommendations and declined work. Distinguish inspection, top-up, replacement, repair and diagnosis.
6. Create a complete timestamped backup before mutation.
7. Use PowerShell only to update canonical JSON atomically. Never hand-edit generated HTML.
8. Preserve confirmed bills separately from estimates. Never present an estimate as paid spending.
9. Do not change manufacturer schedules, source locks or fluid specifications. Never invent a specification.
10. Regenerate every HTML page and validate navigation, totals, evidence links, encoding and read-only behavior.
11. Update the permanent resume record with the timestamp, evidence hash, files changed, tests, current checkpoint and open issues.
12. Move the original from `New` to `Processed/<year>` only after full success; never delete it.

Do not commit private runtime data, generated private HTML, evidence, backups or logs. Do not push to GitHub until `tests/Test-Repository.ps1` passes.

