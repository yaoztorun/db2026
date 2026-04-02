import requests
import time
import csv
from concurrent.futures import ThreadPoolExecutor, as_completed
from statistics import mean

URL = "http://yigit.switzerlandnorth.cloudapp.azure.com:8081/rest/meals"
OUTPUT_FILE = "../raw/rest-endurance.csv"
CONCURRENCY = 20
DURATION_SECONDS = 600   # 10 minutes
TIMEOUT_SECONDS = 10

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
            "latency_ms": (end - start) * 1000,
            "timestamp": end
        }
    except requests.RequestException:
        end = time.time()
        return {
            "success": False,
            "latency_ms": (end - start) * 1000,
            "timestamp": end
        }

start_total = time.time()
latencies = []
failures = 0
count = 0

print("Starting endurance test...")

with ThreadPoolExecutor(max_workers=CONCURRENCY) as executor:
    futures = set()

    while time.time() - start_total < DURATION_SECONDS:
        while len(futures) < CONCURRENCY:
            futures.add(executor.submit(single_request))

        done = {f for f in futures if f.done()}
        for future in done:
            futures.remove(future)
            result = future.result()
            count += 1
            if result["success"]:
                latencies.append(result["latency_ms"])
            else:
                failures += 1

end_total = time.time()
duration = end_total - start_total
throughput = len(latencies) / duration if duration > 0 else 0

with open(OUTPUT_FILE, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["latency_ms"])
    for x in latencies:
        writer.writerow([x])

if latencies:
    print("\n--- Results ---")
    print(f"Successful requests: {len(latencies)}")
    print(f"Failures: {failures}")
    print(f"Duration: {duration:.3f} s")
    print(f"Throughput: {throughput:.3f} req/s")
    print(f"Average latency: {mean(latencies):.3f} ms")
    print(f"Min latency: {min(latencies):.3f} ms")
    print(f"Max latency: {max(latencies):.3f} ms")
    print(f"p95 latency: {percentile(latencies, 0.95):.3f} ms")
else:
    print("No successful requests.")