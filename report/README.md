# Assignment 3 Report Scaffold

This folder stores reproducible performance evidence for the KU Leuven Distributed Systems cloud deployment assignment.

## Directory Layout

- `report/raw/`
  - Place raw test outputs here (CSV files produced by `tests/load-rest.sh`, `tests/load-soap.sh`, and `tests/load-rmi.sh`, plus optional smoke logs and VM monitor CSVs).
  - Suggested naming:
    - `load-rest-baseline-<timestamp>.csv`
    - `load-rest-increasing-<timestamp>.csv`
    - `load-rest-stress-<timestamp>.csv`
    - `load-soap-baseline-<timestamp>.csv`
    - `load-soap-increasing-<timestamp>.csv`
    - `load-rmi-baseline-<timestamp>.csv`
    - `load-rmi-increasing-<timestamp>.csv`
    - `load-rmi-stress-<timestamp>.csv`
    - `rest-monitor-<timestamp>.csv`
    - `soap-monitor-<timestamp>.csv`
    - `rmi-monitor-<timestamp>.csv`
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
   - `tests/smoke-rmi.sh`
2. Run load tests (REST priority):
   - SOAP baseline/increasing (lighter scenarios)
   - RMI baseline/increasing/stress
   - baseline mode
   - increasing mode
   - stress mode (optional but recommended)
3. Copy or move generated CSV files from `tests/results/` into `report/raw/`.
4. Optional but recommended: while a load test is running, capture CPU/memory on the Azure VM:
   - start monitor:
     - `AZURE_HOST=... AZURE_USER=... MONITOR_PORT=8081 MONITOR_LABEL=rest ./deploy/azure/start-monitor.sh`
   - run your load test
   - stop monitor:
     - `AZURE_HOST=... AZURE_USER=... MONITOR_LABEL=rest ./deploy/azure/stop-monitor.sh`
   - fetch CSV locally:
     - `AZURE_HOST=... AZURE_USER=... MONITOR_LABEL=rest ./deploy/azure/fetch-monitor.sh`
5. Generate graphs from files in `report/raw/` and save to `report/graphs/`.
6. Reference both raw CSV and graphs in your final written report.

## Four-VM Matrix

For a reproducible four-VM Assignment 3 setup, use:

- `Poland` as the shared `REST` + `SOAP` service host
- `Sweden` as the shared `RMI` service host
- `France` and `Norway` as client/load-generator VMs

Recommended main matrix:

- `France -> Poland REST`: baseline, increasing, stress
- `Norway -> Poland REST`: baseline, increasing, stress
- `France -> Poland SOAP`: baseline, increasing
- `Norway -> Poland SOAP`: baseline, increasing
- `France -> Sweden RMI`: baseline, increasing
- `Norway -> Sweden RMI`: baseline, increasing

Use the helper scripts:

1. Run the matrix from the local repo:
   - `tests/run-4vm-main-matrix.sh`
2. Summarize all fetched CSV files:
   - `tests/summarize-4vm-results.sh --input-dir tests/results/4vm-<run-id> --output report/raw/4vm-summary.csv`

Notes:

- `tests/run-4vm-main-matrix.sh` syncs `tests/` and `rmi/bin/` to the client VMs before running.
- `REST` stress is included by default because it is the main overload dataset.
- `RMI` runs with `BUILD_BEFORE_RUN=0` on client VMs and uses the synced `rmi/bin` classes.
- The recommended report uses the four-VM matrix as the main dataset and local-to-Azure tests only as supporting geographic-effect data.

## Reproducibility Notes

- Do not hardcode credentials or host-specific values in scripts.
- Keep target endpoints configurable via environment variables or CLI flags.
- Include run metadata in your written report:
  - VM region and size
  - Java version (`17`)
  - date/time (UTC)
  - test mode and client levels
  - endpoint under test
