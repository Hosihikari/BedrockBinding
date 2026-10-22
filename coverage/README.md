# Coverage and provenance

- `manifest.jsonl` is the flat coverage record: one line per declaration or member, with its surface, configuration, status, emitters, and skip reason.
- `summary.json` aggregates bounds, exclusions, and the manifest hash used by `NativeMethods` provenance checks.
- `provenance.json` records the generator version, IR version and manifest hash, carrier identity and input hashes, emitted configurations, dispatch mode, table version, and shim function count.
- `baseline.json` is the floor checked by `scripts/verify_generated.py`; update it only after reviewing an intentional coverage change.
- `generated.sha256` hashes every generated Interop file, both generated shim directories, and the coverage manifest/summary. `verify_generated.py` rejects missing, extra, or modified files.

Regeneration needs the proprietary 1.21.3.01 debug symbols and a LeviLamina v0.13.5 checkout; see the repository README. The committed artifacts are a snapshot keyed by the carrier hashes in `provenance.json`.
