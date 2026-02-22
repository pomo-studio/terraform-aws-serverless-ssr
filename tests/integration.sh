#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-}"
API_PATH="${API_PATH:-/api/health}"
GET_PATH="${GET_PATH:-/}"
EXPECT_GET_STATUS="${EXPECT_GET_STATUS:-200}"
EXPECT_POST_STATUS="${EXPECT_POST_STATUS:-200}"
EXPECT_API_CACHE_CONTROL="${EXPECT_API_CACHE_CONTROL:-no-store}"
LAMBDA_FUNCTION_URL="${LAMBDA_FUNCTION_URL:-}"
DEBUG="${DEBUG:-0}"

if [[ -z "$BASE_URL" ]]; then
  echo "ERROR: BASE_URL is required (CloudFront distribution URL)." >&2
  exit 1
fi

BASE_URL="${BASE_URL%/}"

_tmp_headers() { mktemp -t ssr-int-headers.XXXXXX; }
_tmp_body() { mktemp -t ssr-int-body.XXXXXX; }

request() {
  local method="$1"; shift
  local url="$1"; shift
  local data="${1:-}"

  local headers
  local body
  headers="$(_tmp_headers)"
  body="$(_tmp_body)"

  local status
  if [[ -n "$data" ]]; then
    status=$(curl -sS -o "$body" -D "$headers" -w "%{http_code}" -X "$method" \
      -H "Content-Type: application/json" \
      --data "$data" \
      "$url")
  else
    status=$(curl -sS -o "$body" -D "$headers" -w "%{http_code}" -X "$method" "$url")
  fi

  if [[ "$DEBUG" == "1" ]]; then
    {
      echo "--- $method $url"
      echo "Status: $status"
      echo "Headers:"; cat "$headers"
      echo "Body:"; head -n 20 "$body"
    } >&2
  fi

  echo "$status|$headers|$body"
}

expect_status() {
  local label="$1"; shift
  local expected="$1"; shift
  local status="$1"; shift
  if [[ "$status" != "$expected" ]]; then
    echo "FAIL: $label expected status $expected, got $status" >&2
    return 1
  fi
}

expect_header_contains() {
  local label="$1"; shift
  local headers="$1"; shift
  local header_name="$1"; shift
  local expected="$1"; shift

  local value
  value=$(grep -i "^${header_name}:" "$headers" | tail -n 1 | cut -d':' -f2- | tr -d '\r' | xargs || true)
  if [[ -z "$value" ]]; then
    echo "FAIL: $label missing header $header_name" >&2
    return 1
  fi
  if [[ "$value" != *"$expected"* ]]; then
    echo "FAIL: $label header $header_name expected to contain '$expected', got '$value'" >&2
    return 1
  fi
}

failures=0

# 1) CloudFront -> Lambda GET (validates OAC + InvokeFunction permissions)
result=$(request "GET" "$BASE_URL$GET_PATH")
status="${result%%|*}"
headers="${result#*|}"; headers="${headers%%|*}"
body="${result##*|}"
if ! expect_status "GET $GET_PATH" "$EXPECT_GET_STATUS" "$status"; then
  failures=$((failures+1))
fi

# 2) CloudFront -> Lambda POST /api/* (validates /api/* cache behavior + origin group bypass)
post_payload='{"ping":"pong"}'
result=$(request "POST" "$BASE_URL$API_PATH" "$post_payload")
status="${result%%|*}"
headers="${result#*|}"; headers="${headers%%|*}"
body="${result##*|}"
if ! expect_status "POST $API_PATH" "$EXPECT_POST_STATUS" "$status"; then
  failures=$((failures+1))
fi
if [[ -n "$EXPECT_API_CACHE_CONTROL" ]]; then
  if ! expect_header_contains "POST $API_PATH" "$headers" "Cache-Control" "$EXPECT_API_CACHE_CONTROL"; then
    failures=$((failures+1))
  fi
fi

# 3) Optional: Direct Function URL should be protected (AWS_IAM) -> 403 without signing
if [[ -n "$LAMBDA_FUNCTION_URL" ]]; then
  result=$(request "GET" "$LAMBDA_FUNCTION_URL")
  status="${result%%|*}"
  if [[ "$status" != "403" ]]; then
    echo "FAIL: Direct Lambda Function URL expected 403 (AWS_IAM), got $status" >&2
    failures=$((failures+1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "Integration tests failed ($failures)." >&2
  exit 1
fi

echo "Integration tests passed."
