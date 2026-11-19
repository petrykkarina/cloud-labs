#!/usr/bin/env bash
# One-command load test.
#
#   ./loadtest/run.sh <label>                 e.g. ./loadtest/run.sh no-cache
#   VUS=40 ./loadtest/run.sh calibration      override any parameter
#
# Needs only Docker (k6 runs from the pinned grafana/k6 image).
# BASE_URL defaults to the Terraform output of terraform/main.
set -euo pipefail
cd "$(dirname "$0")"

LABEL="${1:-run}"
export LABEL
export BASE_URL="${BASE_URL:-$(terraform -chdir=../terraform/main output -raw public_url)}"
export VUS="${VUS:-30}" RAMP="${RAMP:-3m}" STEADY="${STEADY:-5m}" DOWN="${DOWN:-2m}" THINK_TIME="${THINK_TIME:-1}"
K6_IMAGE="grafana/k6:2.4.0"

mkdir -p results
echo "Target: $BASE_URL | VUS=$VUS ramp=$RAMP steady=$STEADY down=$DOWN think=${THINK_TIME}s | label=$LABEL"

# Start from zero cache counters so the hit ratio belongs to this run only.
curl -fsS -X POST "$BASE_URL/cache/stats/reset" -o /dev/null || true

started_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
docker run --rm -i \
  -v "$PWD:/loadtest" -w /loadtest \
  -e BASE_URL -e VUS -e RAMP -e STEADY -e DOWN -e THINK_TIME -e LABEL \
  "$K6_IMAGE" run script.js || echo "k6 finished with failed thresholds"
finished_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

curl -fsS "$BASE_URL/cache/stats" > "results/$LABEL-cache.json" || true
cat > "results/$LABEL-meta.json" <<JSON
{"label": "$LABEL", "base_url": "$BASE_URL", "vus": $VUS, "ramp": "$RAMP", "steady": "$STEADY",
 "down": "$DOWN", "think_time_s": $THINK_TIME, "started_at": "$started_at", "finished_at": "$finished_at"}
JSON

echo
echo "== Report ($LABEL) =="
python3 report.py "results/$LABEL-summary.json"
echo
echo "Cache: $(cat "results/$LABEL-cache.json")"
echo "Window (UTC): $started_at .. $finished_at"
