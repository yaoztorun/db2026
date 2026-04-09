# Test Summary

This file summarizes the main tests executed for Assignment 3, the corresponding CSV files, what each test type measures, and the main conclusions.

It is intentionally selective. The repository contains many exploratory reruns under `tests/results/`; this document points to the final or most useful datasets for the report.

## Test Categories

We ran five broad groups of tests:

1. Local functional and load tests
2. Local method-level latency probes
3. Public laptop-to-Azure tests
4. Azure VM-to-VM tests
5. Azure VM resource monitoring during load

## 1. Local Functional And Load Tests

Purpose:
- Verify correctness before any cloud deployment
- Check that the services build and respond on the expected ports
- Establish a local performance baseline without WAN effects

Main files:
- REST local load:
  - [load-rest-baseline-20260328T190720Z.csv](/home/parallels/Desktop/dsgt/tests/results/load-rest-baseline-20260328T190720Z.csv)
  - [load-rest-increasing-20260328T190720Z.csv](/home/parallels/Desktop/dsgt/tests/results/load-rest-increasing-20260328T190720Z.csv)
  - [load-rest-stress-20260328T190720Z.csv](/home/parallels/Desktop/dsgt/tests/results/load-rest-stress-20260328T190720Z.csv)
- SOAP local load:
  - [load-soap-baseline-20260328T190720Z.csv](/home/parallels/Desktop/dsgt/tests/results/load-soap-baseline-20260328T190720Z.csv)
  - [load-soap-increasing-20260328T190720Z.csv](/home/parallels/Desktop/dsgt/tests/results/load-soap-increasing-20260328T190720Z.csv)
- RMI local load:
  - [load-rmi-baseline-check.csv](/home/parallels/Desktop/dsgt/tests/results/load-rmi-baseline-check.csv)
  - [load-rmi-increasing-check.csv](/home/parallels/Desktop/dsgt/tests/results/load-rmi-increasing-check.csv)
  - [load-rmi-stress-check.csv](/home/parallels/Desktop/dsgt/tests/results/load-rmi-stress-check.csv)

Smoke/correctness scripts used:
- [smoke-rest.sh](/home/parallels/Desktop/dsgt/tests/smoke-rest.sh)
- [smoke-soap.sh](/home/parallels/Desktop/dsgt/tests/smoke-soap.sh)
- [smoke-rmi.sh](/home/parallels/Desktop/dsgt/tests/smoke-rmi.sh)

What these tests mean:
- `baseline`: one client, few requests, raw response time
- `increasing`: `1`, `5`, `10`, `20` clients
- `stress`: higher concurrency to observe degradation/failures

Main local conclusions:
- All three services worked correctly locally.
- REST and SOAP were stable locally.
- RMI also worked locally and passed both smoke and load checks.
- Local results were useful as a sanity baseline, but they are not the main dataset for the report because Assignment 3 focuses on cloud deployment and remote access.

## 2. Method-Level Latency Probes

Purpose:
- Compare individual operations rather than whole-service averages
- Check whether one specific method is disproportionately expensive

Main files:
- REST:
  - [norway-rest-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/norway-rest-method-latency.csv)
  - [france-rest-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/france-rest-method-latency.csv)
- SOAP:
  - [norway-soap-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/norway-soap-method-latency.csv)
  - [france-soap-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/france-soap-method-latency.csv)
- RMI:
  - [norway-rmi-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/norway-rmi-method-latency.csv)
  - [france-rmi-method-latency.csv](/home/parallels/Desktop/dsgt/tests/results/france-rmi-method-latency.csv)

What these tests mean:
- Repeat a single method call multiple times
- Record min, average, p50, p95, max
- Separate protocol cost from whole-system stress behavior

Main conclusions:
- RMI methods were all in the same latency band; no single RMI method explained the later high-concurrency failures.
- REST reads were close together; `addOrder` was slightly slower than pure reads.
- SOAP `getMeal` showed the worst tail behavior among the SOAP methods.
- These probes support the conclusion that the major differences under stress are due to concurrency behavior and implementation limits, not one obviously slow endpoint.

## 3. Public Laptop-To-Azure Tests

Purpose:
- Measure realistic end-user/public internet behavior from the local Ubuntu VM
- Compare public-path performance against Azure-to-Azure measurements

### Main Public Dataset

Chosen primary public dataset:
- Laptop -> Poland REST/SOAP
- Laptop -> Sweden RMI

Files:
- Poland REST:
  - [local-to-poland-rest-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-rest-baseline.csv)
  - [local-to-poland-rest-increasing.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-rest-increasing.csv)
  - [local-to-poland-rest-stress.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-rest-stress.csv)
- Poland SOAP:
  - [local-to-poland-soap-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-soap-baseline.csv)
  - [local-to-poland-soap-increasing.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-soap-increasing.csv)
  - [local-to-poland-soap-stress.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-poland-soap-stress.csv)
- Sweden RMI:
  - [local-to-sweden-rmi-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-sweden-rmi-baseline.csv)
  - [local-to-sweden-rmi-increasing.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-sweden-rmi-increasing.csv)
  - [local-to-sweden-rmi-stress.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402/local-to-sweden-rmi-stress.csv)

Main conclusions:
- RMI was fastest on the public path:
  - `20c`: `226.244 req/s`, avg `48.825 ms`
  - stress `40c`: `495.786 req/s`, avg `40.805 ms`
- REST was the strongest HTTP protocol overall:
  - stress `20c`: `182.083 req/s`, `0` errors
  - stress `40c`: `291.545 req/s`, `0` errors
  - stress `80c`: degraded strongly with `458` errors
- SOAP looked competitive in the lighter Poland runs, but under stress it was clearly weaker:
  - stress `20c`: `17` errors
  - stress `40c`: `37` errors

Interpretation:
- SOAP was not actually better than REST overall.
- It only looked slightly better in one moderate-load slice.
- Once stress was included, REST clearly handled load better than SOAP.

### Additional Public Baseline Coverage

To cover the other deployed service hosts, we also ran local baselines against France and Norway.

Files:
- France:
  - [local-to-france-rest-baseline-rerun.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-france-rest-baseline-rerun.csv)
  - [local-to-france-soap-baseline-rerun.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-france-soap-baseline-rerun.csv)
  - [local-to-france-rmi-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-france-rmi-baseline.csv)
- Norway:
  - [local-to-norway-rest-baseline-rerun.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-norway-rest-baseline-rerun.csv)
  - [local-to-norway-soap-baseline-rerun.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-norway-soap-baseline-rerun.csv)
  - [local-to-norway-rmi-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra/local-to-norway-rmi-baseline.csv)

Important note:
- Some of these services initially failed on the public path and had to be redeployed before rerunning.
- The `*-rerun.csv` files are the valid baselines to use, not the earlier failed files.

## 4. Azure VM-To-VM Tests

Purpose:
- Remove most of the local/public internet noise
- Compare services from Azure client VMs to Azure service VMs
- Use this as the main performance dataset for the report

### 2-VM Directional Tests

Early bidirectional tests between Norway and France:
- Corrected REST files:
  - [norway-to-france-20260331-restfix/load-rest-baseline.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-france-20260331-restfix/load-rest-baseline.csv)
  - [norway-to-france-20260331-restfix/load-rest-increasing.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-france-20260331-restfix/load-rest-increasing.csv)
  - [norway-to-france-20260331-restfix/load-rest-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-france-20260331-restfix/load-rest-stress.csv)
- Earlier bidirectional set:
  - [norway-to-france-20260331-bidi](/home/parallels/Desktop/dsgt/tests/results/norway-to-france-20260331-bidi)
  - [vm2vm-20260331](/home/parallels/Desktop/dsgt/tests/results/vm2vm-20260331)

Important note:
- The first bidirectional REST set had a measurement bug where `HTTP 000` was initially counted as success.
- The corrected REST conclusions come from `*-restfix`.

Main conclusions from the 2-VM phase:
- REST and SOAP were stable up to moderate load.
- RMI was very fast at low load but showed hard failure under higher concurrency.
- These runs motivated the cleaner 4-VM matrix.

### 4-VM Main Matrix

This is the main Azure-to-Azure dataset for the report.

Summary file:
- [4vm-summary-20260402T142553Z.csv](/home/parallels/Desktop/dsgt/report/raw/4vm-summary-20260402T142553Z.csv)

Raw directory:
- [4vm-20260402T142553Z](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z)

Topology:
- France and Norway as client/load VMs
- Poland as REST/SOAP host
- Sweden as RMI host

Files of particular interest:
- France -> Poland REST:
  - [france-to-poland-rest-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-poland-rest-baseline-r1.csv)
  - [france-to-poland-rest-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-poland-rest-increasing-r1.csv)
  - [france-to-poland-rest-stress-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-poland-rest-stress-r1.csv)
- Norway -> Poland REST:
  - [norway-to-poland-rest-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-poland-rest-baseline-r1.csv)
  - [norway-to-poland-rest-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-poland-rest-increasing-r1.csv)
  - [norway-to-poland-rest-stress-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-poland-rest-stress-r1.csv)
- France -> Poland SOAP:
  - [france-to-poland-soap-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-poland-soap-baseline-r1.csv)
  - [france-to-poland-soap-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-poland-soap-increasing-r1.csv)
- Norway -> Poland SOAP:
  - [norway-to-poland-soap-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-poland-soap-baseline-r1.csv)
  - [norway-to-poland-soap-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-poland-soap-increasing-r1.csv)
- France -> Sweden RMI:
  - [france-to-sweden-rmi-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-sweden-rmi-baseline-r1.csv)
  - [france-to-sweden-rmi-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/france-to-sweden-rmi-increasing-r1.csv)
- Norway -> Sweden RMI:
  - [norway-to-sweden-rmi-baseline-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-sweden-rmi-baseline-r1.csv)
  - [norway-to-sweden-rmi-increasing-r1.csv](/home/parallels/Desktop/dsgt/tests/results/4vm-20260402T142553Z/norway-to-sweden-rmi-increasing-r1.csv)

Main 4-VM conclusions:
- REST was the best-balanced protocol.
- SOAP was stable and close to REST under moderate load.
- RMI was fastest at low load but failed completely at `20` clients in both directions.
- Norway was generally the better client region.

Representative 4-VM observations:
- Norway -> Poland REST `20c`: `90.285 req/s`, avg `67.719 ms`, `0` errors
- France -> Poland REST `20c`: `76.959 req/s`, avg `70.963 ms`, `0` errors
- Norway -> Poland SOAP `20c`: `68.046 req/s`, avg `80.952 ms`, `0` errors
- France -> Sweden RMI `20c`: `0/1000` success
- Norway -> Sweden RMI `20c`: `0/1000` success

## 5. Resource Monitoring During Load

Purpose:
- Record CPU usage, memory usage, and thread counts on the service VM during load
- Strengthen the report beyond latency/throughput only

### Norway Monitored Runs

Main summary:
- [norway-monitored-summary-20260331.csv](/home/parallels/Desktop/dsgt/tests/results/norway-monitored-summary-20260331.csv)

Representative source files:
- REST:
  - [rest-norway-increasing-20260331T163237Z-load.csv](/home/parallels/Desktop/dsgt/tests/results/rest-norway-increasing-20260331T163237Z-load.csv)
  - [rest-norway-increasing-20260331T163237Z-20260331T163237Z.csv](/home/parallels/Desktop/dsgt/tests/results/rest-norway-increasing-20260331T163237Z-20260331T163237Z.csv)
- SOAP:
  - [soap-norway-increasing-20260331T163613Z-load.csv](/home/parallels/Desktop/dsgt/tests/results/soap-norway-increasing-20260331T163613Z-load.csv)
  - [soap-norway-increasing-20260331T163613Z-20260331T163613Z.csv](/home/parallels/Desktop/dsgt/tests/results/soap-norway-increasing-20260331T163613Z-20260331T163613Z.csv)
- RMI:
  - [rmi-norway-increasing-20260331T163646Z-load.csv](/home/parallels/Desktop/dsgt/tests/results/rmi-norway-increasing-20260331T163646Z-load.csv)
  - [rmi-norway-increasing-20260331T163646Z-20260331T163646Z.csv](/home/parallels/Desktop/dsgt/tests/results/rmi-norway-increasing-20260331T163646Z-20260331T163646Z.csv)

Main conclusions:
- SOAP was the most CPU-intensive service.
- REST used the most memory among the Norway monitored runs.
- RMI had the smallest memory footprint and the best latency/throughput in that monitored rerun.
- None of the services appeared memory-bound in those runs.

Representative resource observations:
- REST: about `177-179 MB` RSS
- SOAP: about `167-169 MB` RSS, highest CPU
- RMI: about `72-75 MB` RSS

### Norway-To-All Stress Monitoring

This is the strongest stress-and-monitoring dataset because it combines:
- one fixed client region: Norway
- multiple target service regions
- target-side CPU/memory monitoring

Raw directory:
- [norway-to-all-stress-20260402T153801Z](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z)

Load CSVs:
- [norway-to-france-rest-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-rest-stress.csv)
- [norway-to-france-soap-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-soap-stress.csv)
- [norway-to-france-rmi-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-rmi-stress.csv)
- [norway-to-poland-rest-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-poland-rest-stress.csv)
- [norway-to-poland-soap-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-poland-soap-stress.csv)
- [norway-to-sweden-rmi-stress.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-sweden-rmi-stress.csv)

Matching monitor CSVs:
- [norway-to-france-rest-20260402T153801Z-20260402T153803Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-rest-20260402T153801Z-20260402T153803Z.csv)
- [norway-to-france-soap-20260402T153801Z-20260402T154204Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-soap-20260402T153801Z-20260402T154204Z.csv)
- [norway-to-france-rmi-20260402T153801Z-20260402T154343Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-france-rmi-20260402T153801Z-20260402T154343Z.csv)
- [norway-to-poland-rest-20260402T153801Z-20260402T154907Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-poland-rest-20260402T153801Z-20260402T154907Z.csv)
- [norway-to-poland-soap-20260402T153801Z-20260402T155314Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-poland-soap-20260402T153801Z-20260402T155314Z.csv)
- [norway-to-sweden-rmi-20260402T153801Z-20260402T155441Z.csv](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z/norway-to-sweden-rmi-20260402T153801Z-20260402T155441Z.csv)

Main conclusions:
- REST was the strongest stress performer overall.
- SOAP was usable but weaker under stress.
- RMI failed completely at high concurrency in both France and Sweden, even though CPU and memory remained low.
- That suggests an RMI concurrency/timeout design limit rather than raw CPU or memory exhaustion.

Representative stress findings:
- Norway -> France REST:
  - `20c`: `2000/2000` success
  - `40c`: `3996/4000` success
  - `80c`: `7710/8000` success
- Norway -> Poland REST:
  - `20c`: `2000/2000` success
  - `40c`: `3999/4000` success
  - `80c`: `7552/8000` success
- Norway -> France SOAP:
  - `20c`: `1598/1600` success
  - `40c`: `3197/3200` success
- Norway -> Poland SOAP:
  - `20c`: `1594/1600` success
  - `40c`: `3198/3200` success
- Norway -> France RMI:
  - `20c`: `0/2000` success
  - `40c`: `0/4000` success
- Norway -> Sweden RMI:
  - `20c`: `0/2000` success
  - `40c`: `0/4000` success

Representative resource findings:
- France REST: avg CPU about `13.17%`, max CPU about `92.98%`, avg RSS about `158.87 MB`
- France SOAP: avg CPU about `23.34%`, max CPU about `87.74%`, avg RSS about `166.70 MB`
- France RMI: avg CPU near `0%`, avg RSS about `60.42 MB`
- Poland REST: avg CPU about `3.56%`, avg RSS about `166.05 MB`
- Poland SOAP: avg CPU about `5.67%`, avg RSS about `178.07 MB`
- Sweden RMI: avg CPU near `0%`, avg RSS about `80.69 MB`

## Overall Conclusions

Across the full test campaign:

- `RMI` was the fastest at low load and for single-call latency.
- `REST` was the best-balanced protocol overall, especially once stress and error behavior were included.
- `SOAP` was often closer to REST than expected under moderate load, but it degraded earlier under stress.
- `Azure VM -> Azure VM` measurements are the main benchmark dataset and should be emphasized in the final report.
- `Laptop -> Azure` measurements are still useful, but they should be presented as public-path or end-user perspective data.
- The strongest evidence that RMI has a scalability problem is that it failed at high concurrency even when CPU and memory remained low.

## Suggested Report Usage

Use these datasets in the final report:

1. Main performance section:
- [4vm-summary-20260402T142553Z.csv](/home/parallels/Desktop/dsgt/report/raw/4vm-summary-20260402T142553Z.csv)

2. Stress and resource section:
- [norway-to-all-stress-20260402T153801Z](/home/parallels/Desktop/dsgt/tests/results/norway-to-all-stress-20260402T153801Z)

3. Public internet perspective:
- [local-public-20260402](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402)
- [local-public-20260402-extra](/home/parallels/Desktop/dsgt/tests/results/local-public-20260402-extra)

4. Optional supporting material:
- method-level latency CSVs
- Norway monitored summary

If needed, the older exploratory CSVs under `tests/results/` can still be cited as intermediate validation, but the files listed above are the clearest final evidence.
