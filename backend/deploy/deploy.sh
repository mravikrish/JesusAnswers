#!/usr/bin/env bash
# Uploads the backend to the server and (re)starts it. Run from Git Bash on your PC:
#   bash backend/deploy/deploy.sh ubuntu@<server-ip> <path-to-private-key>
# The first run also does the one-time server setup. The server's .env is never touched.
set -euo pipefail
host=${1:?usage: deploy.sh ubuntu@<server-ip> <private-key>}
key=${2:?usage: deploy.sh ubuntu@<server-ip> <private-key>}
backend="$(cd "$(dirname "$0")/.." && pwd)"
ssh_opts=(-i "$key" -o StrictHostKeyChecking=accept-new)

echo "Uploading..."
tar -C "$backend" --exclude=./target --exclude=./.env --exclude=./deploy/.env -czf - . \
  | ssh "${ssh_opts[@]}" "$host" 'mkdir -p ~/jesusanswers && tar -C ~/jesusanswers -xzf -'

ssh "${ssh_opts[@]}" "$host" 'bash ~/jesusanswers/deploy/setup-server.sh'

echo "Building and starting (the first build takes a few minutes)..."
# A fresh login so the docker group from setup applies.
ssh "${ssh_opts[@]}" "$host" 'cd ~/jesusanswers/deploy && sg docker -c "docker compose -f compose.prod.yaml up -d --build --remove-orphans && docker image prune -f >/dev/null"'

domain=$(ssh "${ssh_opts[@]}" "$host" "grep '^API_DOMAIN=' ~/jesusanswers/deploy/.env | cut -d= -f2")
echo "Waiting for https://$domain ..."
for _ in $(seq 1 60); do
  # Checked from the server, so antivirus HTTPS scanning on this PC can't get in the way.
  if ssh "${ssh_opts[@]}" "$host" "curl -fsS https://$domain/actuator/health" 2>/dev/null | grep -q UP; then
    echo "Live: https://$domain"
    exit 0
  fi
  sleep 5
done
echo "Not answering yet. Logs: ssh -i $key $host 'cd ~/jesusanswers/deploy && docker compose -f compose.prod.yaml logs --tail 80'"
exit 1
