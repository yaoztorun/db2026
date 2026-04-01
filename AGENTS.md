# Project Context

This repository contains KU Leuven Distributed Systems assignments.

Current focus: Assignment 3 — Cloud-based deployment with IaaS.

Goal:
- Deploy SOAP and REST services on an Azure Ubuntu VM
- Make services publicly accessible via DNS + open ports
- Evaluate performance (latency, throughput) under load
- Produce reproducible experiments and a structured report

Services:
- REST (Spring Boot, Maven) → port 8081
- SOAP (Spring Boot, Maven) → port 8082
- RMI (Java RMI, Ant) → included but not main focus

---

# Development Workflow

- Development happens locally on Ubuntu VM
- Deployment happens via SSH to Azure VM
- Codebase is single source of truth (do NOT diverge local vs remote)
- Use bash scripts for all repetitive tasks

---

# Key Requirements

- Java 17 must be used everywhere
- Services must run on different ports
- No hardcoded IP addresses, DNS, or credentials
- All deployments must be script-based and reproducible
- Tests must simulate multiple clients and multiple requests

---

# Project Structure Rules

- `soap/`, `rest/`, `rmi/` → service code only
- `deploy/azure/` → deployment + remote execution scripts
- `deploy/local/` → local run scripts
- `tests/` → all testing scripts (smoke + load)
- `report/` → notes, measurements, graphs

Do NOT mix responsibilities across folders.

---

# Testing Strategy (High-Level Plan)

We evaluate performance using controlled scenarios:

1. Baseline
   - Single client, small number of requests
   - Measure raw latency

2. Increasing Load
   - Multiple concurrent clients (e.g. 1 → 5 → 10 → 20)
   - Measure latency + throughput

3. Stress Test
   - Push system until degradation or failure
   - Observe error rate and response time increase

4. Geographic Effect
   - Local Ubuntu → Azure VM
   - (Optional) Azure → Azure

Focus on:
- Average latency
- Throughput (requests/sec)
- Stability under load

---

# Codex Guidelines

When modifying this repository:

- Prefer simple, reproducible bash scripts over complex tools
- Keep scripts idempotent (safe to run multiple times)
- Do not introduce unnecessary frameworks
- Do not refactor unrelated code
- Always keep deployment + testing in mind

When adding features:
- Ensure they can be tested remotely via HTTP or RMI
- Provide corresponding test scripts

When generating code:
- Be explicit with ports and endpoints
- Keep configurations transparent and minimal

---

# Expected Outputs

- Working SOAP and REST services on Azure
- Public endpoints:
  - REST (HATEOAS)
  - SOAP (WSDL)
- Test scripts for load and performance evaluation
- Data for report (latency, throughput, observations)

---

# Notes

- REST performance testing is priority
- SOAP testing can be simpler but must still be measurable
- RMI is secondary for this assignment
