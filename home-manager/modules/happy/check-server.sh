#!/usr/bin/env bash
# Checks WebSocket availability of the happy-coder server using real credentials.
# Mirrors the exact connection the daemon makes (socket.io, /v1/updates, machine-scoped auth).
#
# Usage: ./check-server.sh [--watch INTERVAL_SECONDS]
#        ./check-server.sh --watch 30   (poll every 30s, default 60s)

HAPPY_DIR="${HOME}/.happy"
LOG_FILE="${HAPPY_DIR}/server-availability.log"
WATCH_INTERVAL=60
NODE=$(which node)
HAPPY_NODE="/nix/store/9hm0b65blknfvqyvd706r03w2zfcslf7-happy-coder-0.11.2/lib/node_modules/happy-coder"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

check_ws() {
  "$NODE" --input-type=module <<'EOF'
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const HAPPY_NODE = process.env.HAPPY_NODE;
const HAPPY_DIR  = process.env.HAPPY_DIR;

const require = createRequire(`${HAPPY_NODE}/dist/index.mjs`);
const { io } = require('socket.io-client');

const creds    = JSON.parse(readFileSync(`${HAPPY_DIR}/access.key`, 'utf8'));
const settings = JSON.parse(readFileSync(`${HAPPY_DIR}/settings.json`, 'utf8'));

const socket = io('https://api.cluster-fluster.com', {
  transports: ['websocket'],
  auth: { token: creds.token, clientType: 'machine-scoped', machineId: settings.machineId },
  path: '/v1/updates',
  reconnection: false,
});

const start = Date.now();
socket.on('connect', () => {
  process.stdout.write(`OK ${((Date.now()-start)/1000).toFixed(3)}\n`);
  socket.disconnect();
  process.exit(0);
});
socket.on('connect_error', (e) => {
  process.stdout.write(`FAIL ${((Date.now()-start)/1000).toFixed(3)} ${e.message}\n`);
  process.exit(1);
});
setTimeout(() => { process.stdout.write('FAIL 10.000 timeout\n'); process.exit(1); }, 10000);
EOF
}

run_checks() {
  local ts
  ts=$(timestamp)

  local result status elapsed detail
  result=$(HAPPY_NODE="$HAPPY_NODE" HAPPY_DIR="$HAPPY_DIR" check_ws)
  status=$(awk '{print $1}' <<< "$result")
  elapsed=$(awk '{print $2}' <<< "$result")
  detail=$(awk '{$1=$2=""; print $0}' <<< "$result" | xargs)

  local label
  if [[ "$status" == "OK" ]]; then
    label="OK"
  else
    label="DOWN${detail:+ ($detail)}"
  fi

  local line="[$ts] $label | WS connect=${elapsed}s"
  echo "$line"
  echo "$line" >> "$LOG_FILE"
}

if [[ "$1" == "--watch" ]]; then
  WATCH_INTERVAL="${2:-60}"
  echo "Polling wss://api.cluster-fluster.com/v1/updates every ${WATCH_INTERVAL}s — logging to ${LOG_FILE}"
  echo "Press Ctrl+C to stop."
  while true; do
    run_checks
    sleep "$WATCH_INTERVAL"
  done
else
  run_checks
fi
