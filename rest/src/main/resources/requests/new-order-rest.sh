#!/bin/bash
curl -X POST localhost:8080/rest/order \
  -H "Content-Type: application/json" \
  -d @new-order.json
