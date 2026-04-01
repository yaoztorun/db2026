import requests
import time
import csv
from concurrent.futures import ThreadPoolExecutor, as_completed
from statistics import mean

URL = "http://yigit.switzerlandnorth.cloudapp.azure.com:8081/rest/meals"
OUTPUT_FILE = "../raw/rest-increasing-load.csv"

CONCURRENCY_LEVELS = [5, 10, 25, 50]
REQUESTS_PER_CLIENT = 20
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
        latency_ms = (end - start) * 1000
        return {
            "success": response.status_code == 200,
            "status_code": response.status_code,
            "latency_ms": latency_ms
        }
    except requests.RequestException:
        end = time.time()
        latency_ms = (end - start) * 1000
        return {
            "success": False,
            "status_code": None,
            "latency_ms": latency_ms
        }

def run_round(concurrency, requests_per_client):
    total_requests = concurrency * requests_per_client
    latencies = []
    failures = 0
    successes = 0

    start_round = time.time()

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        futures = [executor.submit(single_request) for _ in range(total_requests)]

        for future in as_completed(futures):
            result = future.result()
            if result["success"]:
                successes += 1
                latencies.append(result["latency_ms"])
            else:
                failures += 1

    end_round = time.time()
    duration = end_round - start_round
    throughput = successes / duration if duration > 0 else 0

    if latencies:
        avg_latency = mean(latencies)
        min_latency = min(latencies)
        max_latency = max(latencies)
        p95_latency = percentile(latencies, 0.95)
    else:
        avg_latency = min_latency = max_latency = p95_latency = None

    return {
        "concurrency": concurrency,
        "total_requests": total_requests,
        "successes": successes,
        "failures": failures,
        "duration_s": duration,
        "throughput_rps": throughput,
        "avg_latency_ms": avg_latency,
        "min_latency_ms": min_latency,
        "max_latency_ms": max_latency,
        "p95_latency_ms": p95_latency,
    }

def main():
    all_results = []

    print("Starting increasing load test...\n")

    for concurrency in CONCURRENCY_LEVELS:
        print(f"=== Testing concurrency: {concurrency} ===")
        result = run_round(concurrency, REQUESTS_PER_CLIENT)
        all_results.append(result)

        print(f"Total requests: {result['total_requests']}")
        print(f"Successful requests: {result['successes']}")
        print(f"Failed requests: {result['failures']}")
        print(f"Duration: {result['duration_s']:.3f} s")
        print(f"Throughput: {result['throughput_rps']:.3f} req/s")

        if result["avg_latency_ms"] is not None:
            print(f"Average latency: {result['avg_latency_ms']:.3f} ms")
            print(f"Min latency: {result['min_latency_ms']:.3f} ms")
            print(f"Max latency: {result['max_latency_ms']:.3f} ms")
            print(f"p95 latency: {result['p95_latency_ms']:.3f} ms")
        else:
            print("No successful responses recorded.")

        print()

    with open(OUTPUT_FILE, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "concurrency",
            "total_requests",
            "successes",
            "failures",
            "duration_s",
            "throughput_rps",
            "avg_latency_ms",
            "min_latency_ms",
            "max_latency_ms",
            "p95_latency_ms"
        ])

        for r in all_results:
            writer.writerow([
                r["concurrency"],
                r["total_requests"],
                r["successes"],
                r["failures"],
                f"{r['duration_s']:.3f}",
                f"{r['throughput_rps']:.3f}",
                f"{r['avg_latency_ms']:.3f}" if r["avg_latency_ms"] is not None else "",
                f"{r['min_latency_ms']:.3f}" if r["min_latency_ms"] is not None else "",
                f"{r['max_latency_ms']:.3f}" if r["max_latency_ms"] is not None else "",
                f"{r['p95_latency_ms']:.3f}" if r["p95_latency_ms"] is not None else "",
            ])

    print(f"Saved results to {OUTPUT_FILE}")

if __name__ == "__main__":
    main()