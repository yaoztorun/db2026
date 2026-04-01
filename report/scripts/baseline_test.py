import requests
import time
import csv

URL = "http://yigit.switzerlandnorth.cloudapp.azure.com:8081/rest/meals"
OUTPUT_FILE = "../raw/rest-baseline.csv"

results = []

print("Starting baseline test...")

for i in range(120):
    start = time.time()
    response = requests.get(URL)
    end = time.time()

    latency = (end - start) * 1000  # ms
    results.append(latency)

    print(f"Request {i+1}: {latency:.3f} ms")
    time.sleep(1)

# Save to CSV
with open(OUTPUT_FILE, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["latency_ms"])
    for r in results:
        writer.writerow([r])

print("Saved results to", OUTPUT_FILE)

# Basic stats
avg = sum(results) / len(results)
min_v = min(results)
max_v = max(results)
p95 = sorted(results)[int(0.95 * len(results))]

print("\n--- Results ---")
print(f"Average latency: {avg:.3f} ms")
print(f"Min latency: {min_v:.3f} ms")
print(f"Max latency: {max_v:.3f} ms")
print(f"p95 latency: {p95:.3f} ms")