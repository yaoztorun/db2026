import requests
import time
import csv
from concurrent.futures import ThreadPoolExecutor, as_completed
from statistics import mean

URL = "http://yigit.switzerlandnorth.cloudapp.azure.com:8081/rest/meals"
OUTPUT_FILE = "../raw/rest-burst.csv"
TIMEOUT_SECONDS = 10

PHASES = [
    ("low", 5, 50),
    ("spike", 100, 500),
    ("recovery", 10, 100),
]

def percentile(values, p):
    if not values:
        return None
    values = sorted(values)
    index = int(p * len(values)) - 1
    index = max(0, min(index, len(values) - 1))
    return values[index]

def single_request():
    start = time.time()
    try:
        response = requests.get(URL, timeout=TIMEOUT_SECONDS)
        end = time.time()
        return {
            "success": response.status_code == 200,
            "latency_ms": (end - start) * 1000
        }
    except requests.RequestException:
        end = time.time()
        return {
            "success": False,
            "latency_ms": (end - start) * 1000
        }

results = []

for phase_name, concurrency, total_requests in PHASES:
    print(f"\n=== Phase: {phase_name} | concurrency={concurrency}, requests={total_requests} ===")

    latencies = []
    failures = 0
    start_phase = time.time()

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(single_request) for _ in range(total_requests)]
        for future in as_completed(futures):
            result = future.result()
            if result["success"]:
                latencies.append(result["latency_ms"])
            else:
                failures += 1

    end_phase = time.time()
    duration = end_phase - start_phase
    throughput = len(latencies) / duration if duration > 0 else 0

    avg_latency = mean(latencies) if latencies else None
    min_latency = min(latencies) if latencies else None
    max_latency = max(latencies) if latencies else None
    p95_latency = percentile(latencies, 0.95) if latencies else None

    print(f"Average latency: {avg_latency:.3f} ms" if avg_latency else "No successful requests")
    print(f"Min latency: {min_latency:.3f} ms" if min_latency else "")
    print(f"Max latency: {max_latency:.3f} ms" if max_latency else "")
    print(f"p95 latency: {p95_latency:.3f} ms" if p95_latency else "")
    print(f"Throughput: {throughput:.3f} req/s")
    print(f"Failures: {failures}")

    results.append([
        phase_name,
        concurrency,
        total_requests,
        len(latencies),
        failures,
        f"{duration:.3f}",
        f"{throughput:.3f}",
        f"{avg_latency:.3f}" if avg_latency else "",
        f"{min_latency:.3f}" if min_latency else "",
        f"{max_latency:.3f}" if max_latency else "",
        f"{p95_latency:.3f}" if p95_latency else "",
    ])

with open(OUTPUT_FILE, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow([
        "phase", "concurrency", "total_requests", "successes", "failures",
        "duration_s", "throughput_rps", "avg_latency_ms", "min_latency_ms",
        "max_latency_ms", "p95_latency_ms"
    ])
    writer.writerows(results)

print(f"\nSaved burst results to {OUTPUT_FILE}")