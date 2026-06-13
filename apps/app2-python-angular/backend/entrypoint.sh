#!/bin/sh
set -e
exec uvicorn app2.main:app --host 0.0.0.0 --port 8080 --proxy-headers --forwarded-allow-ips='*'
