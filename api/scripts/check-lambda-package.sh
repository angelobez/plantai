#!/usr/bin/env bash
#
# Runs the Lambda package (build/lambda, from `npm run lambda:package`) in the
# official Node.js 24 Lambda image and asks the API handler for
# `GET /v1/health` with a Function URL event. A `200` proves the package boots
# on Lambda's Linux: the native argon2 and sharp load, Nest starts and the
# handler reaches a real PostGIS (a throwaway container, as in the tests).
#
# The environment is a placeholder one (no SSM prefix, fake keys): health
# only reads the database. Needs Docker.

set -euo pipefail

api="$(cd "$(dirname "$0")/.." && pwd)"
package="$api/build/lambda"
lambda_image='public.ecr.aws/lambda/nodejs:24'
# Keep in sync with test/support/postgis.ts and compose.yaml.
postgis_image='postgis/postgis:17-3.5'
name="plantai-lambda-check-$$"
# The same NODE_OPTIONS the stack gives the functions (infra/api-stack.ts).
node_options='--experimental-require-module --enable-source-maps'

if [[ ! -f "$package/dist/lambda.js" ]]; then
  echo "[check-lambda-package] no package in $package; run npm run lambda:package" >&2
  exit 1
fi

cleanup() {
  docker rm -f "$name-fn" "$name-db" >/dev/null 2>&1 || true
  docker network rm "$name" >/dev/null 2>&1 || true
}
trap cleanup EXIT

docker network create "$name" >/dev/null
docker run -d --name "$name-db" --network "$name" --network-alias db \
  -e POSTGRES_PASSWORD=postgres "$postgis_image" >/dev/null

echo "[check-lambda-package] waiting for PostGIS"
for _ in $(seq 60); do
  # The image restarts Postgres after creating the extensions: wait for them.
  if docker exec "$name-db" psql -U postgres -tAc \
    "SELECT 1 FROM pg_extension WHERE extname = 'postgis'" 2>/dev/null |
    grep -q 1; then
    break
  fi
  sleep 1
done
sleep 2

docker run -d --name "$name-fn" --network "$name" --platform linux/amd64 \
  -p 127.0.0.1::8080 \
  -v "$package:/var/task:ro" \
  -e NODE_OPTIONS="$node_options" \
  -e DATABASE_URL=postgres://postgres:postgres@db:5432/postgres \
  -e MIN_APP_VERSION=0.0.0 \
  -e PLANTNET_API_KEY=placeholder \
  -e JWT_SECRET=placeholder-placeholder-placeholder-00 \
  -e GOOGLE_WEB_CLIENT_ID=placeholder \
  -e EMAIL_FROM='PlantAí <check@example.com>' \
  -e S3_BUCKET=placeholder \
  -e S3_REGION=us-east-1 \
  -e ANTHROPIC_API_KEY=placeholder \
  "$lambda_image" dist/lambda.handler >/dev/null
port="$(docker port "$name-fn" 8080/tcp | head -n1 | cut -d: -f2)"

# A Function URL request (payload format 2.0) for GET /v1/health.
event='{
  "version": "2.0",
  "routeKey": "$default",
  "rawPath": "/v1/health",
  "rawQueryString": "",
  "headers": { "host": "check.lambda-url.us-east-1.on.aws" },
  "requestContext": {
    "accountId": "anonymous",
    "apiId": "check",
    "domainName": "check.lambda-url.us-east-1.on.aws",
    "domainPrefix": "check",
    "http": {
      "method": "GET",
      "path": "/v1/health",
      "protocol": "HTTP/1.1",
      "sourceIp": "127.0.0.1",
      "userAgent": "check-lambda-package"
    },
    "requestId": "check",
    "routeKey": "$default",
    "stage": "$default",
    "time": "01/Jan/2026:00:00:00 +0000",
    "timeEpoch": 1767225600000
  },
  "isBase64Encoded": false
}'

echo "[check-lambda-package] invoking dist/lambda.handler"
response=''
for _ in $(seq 30); do
  if response="$(curl -sf -X POST \
    "http://127.0.0.1:$port/2015-03-31/functions/function/invocations" \
    -d "$event")"; then
    break
  fi
  sleep 1
done
echo "$response"

if ! echo "$response" | grep -q '"statusCode":200'; then
  echo "[check-lambda-package] FAILED: GET /v1/health did not answer 200" >&2
  docker logs "$name-fn" >&2 || true
  exit 1
fi
echo "[check-lambda-package] OK: GET /v1/health answered 200 on $lambda_image"
