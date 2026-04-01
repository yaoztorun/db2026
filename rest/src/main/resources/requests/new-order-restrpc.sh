#!/bin/bash
curl -X POST localhost:8080/restrpc/order \
  -H "Content-Type: application/json" \
  -d @new-order.json
