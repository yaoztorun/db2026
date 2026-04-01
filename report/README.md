# Assignment 3 Report Scaffold

This folder stores reproducible performance evidence for the KU Leuven Distributed Systems cloud deployment assignment.

## Directory Layout

- `report/raw/`
  - Place raw test outputs here (CSV files produced by `tests/load-rest.sh` and `tests/load-soap.sh`, plus optional smoke logs).
  - Suggested naming:
    - `load-rest-baseline-<timestamp>.csv`
    - `load-rest-increasing-<timestamp>.csv`
    - `load-rest-stress-<timestamp>.csv`
    - `load-soap-baseline-<timestamp>.csv`
    - `load-soap-increasing-<timestamp>.csv`
- `report/graphs/`
  - Place generated figures here (PNG/SVG/PDF) derived from CSV data.
  - Suggested figures:
    - latency vs concurrent clients
    - throughput vs concurrent clients
    - error rate vs concurrent clients

## Data Collection Flow

1. Run smoke tests first:
   - `tests/smoke-rest.sh`
   - `tests/smoke-soap.sh`
2. Run load tests (REST priority):
   - SOAP baseline/increasing (lighter scenarios)
   - baseline mode
   - increasing mode
   - stress mode (optional but recommended)
3. Copy or move generated CSV files from `tests/results/` into `report/raw/`.
4. Generate graphs from files in `report/raw/` and save to `report/graphs/`.
5. Reference both raw CSV and graphs in your final written report.

## Reproducibility Notes

- Do not hardcode credentials or host-specific values in scripts.
- Keep target endpoints configurable via environment variables or CLI flags.
- Include run metadata in your written report:
  - VM region and size
  - Java version (`17`)
  - date/time (UTC)
  - test mode and client levels
  - endpoint under test
