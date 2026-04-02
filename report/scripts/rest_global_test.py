import requests
import time
import csv
from statistics import mean

URL = "http://yigit.switzerlandnorth.cloudapp.azure.com:8081/rest/meals"
OUTPUT_FILE = "../raw/rest-global.csv"
REQUEST_COUNT = 50
TIMEOUT_SECONDS = 10

latencies = []
failures = 0

def percentile(values, p):
    if not values:
        return None
    values = sorted(values)
    index = int(p * len(values)) - 1
    index = max(0, min(index, len(values) - 1))
    return values[index]

print("Starting global access test...")

start_total = time.time()

for i in range(REQUEST_COUNT):
    try:
        start = time.time()
        response = requests.get(URL, timeout=TIMEOUT_SECONDS)
        end = time.time()

        latency_ms = (end - start) * 1000

        if response.status_code == 200:
            latencies.append(latency_ms)
            print(f"Request {i+1}: {latency_ms:.3f} ms")
        else:
            failures += 1
            print(f"Request {i+1}: FAILED status={response.status_code}")
    except requests.RequestException as e:
        failures += 1
        print(f"Request {i+1}: FAILED {e}")

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
    print(f"Average latency: {mean(latencies):.3f} ms")
    print(f"Min latency: {min(latencies):.3f} ms")
    print(f"Max latency: {max(latencies):.3f} ms")
    print(f"p95 latency: {percentile(latencies, 0.95):.3f} ms")
    print(f"Throughput: {throughput:.3f} req/s")
    print(f"Failures: {failures}")
else:
    print("No successful requests.")