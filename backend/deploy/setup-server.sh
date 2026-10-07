#!/usr/bin/env bash
# One-time setup of a fresh Ubuntu server (Oracle Cloud Always Free). Safe to run again.
# Installs Docker, opens ports 80/443, adds swap on small machines, writes the secrets file,
# and schedules a nightly database backup. Run on the server: bash ~/jesusanswers/deploy/setup-server.sh
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v docker >/dev/null; then
  echo "Installing Docker..."
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
fi

# Oracle's Ubuntu images reject everything except SSH in iptables, even when the cloud firewall allows it.
for port in 80 443; do
  sudo iptables -C INPUT -p tcp --dport "$port" -j ACCEPT 2>/dev/null \
    || sudo iptables -I INPUT -p tcp --dport "$port" -j ACCEPT
done
if command -v netfilter-persistent >/dev/null; then sudo netfilter-persistent save; fi

# The 1 GB micro machines need swap to build and run Java next to PostgreSQL.
mem_mb=$(free -m | awk '/^Mem:/ {print $2}')
if [ "$mem_mb" -lt 4000 ] && [ ! -f /swapfile ]; then
  echo "Adding 4 GB swap..."
  sudo fallocate -l 4G /swapfile && sudo chmod 600 /swapfile
  sudo mkswap /swapfile && sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab >/dev/null
fi

# Secrets: made once, never overwritten. Back this file up somewhere safe —
# losing JOURNEY_ENCRYPTION_KEY makes stored journeys and circle requests unreadable.
if [ ! -f .env ]; then
  ip=$(curl -fsS https://api.ipify.org)
  cat > .env <<EOF
# Server secrets. Do not share or commit. Back this file up.
# Free HTTPS name for this server's IP; replace with your own domain later if you get one.
API_DOMAIN=${ip//./-}.sslip.io
DATABASE_PASSWORD=$(openssl rand -hex 24)
JOURNEY_ENCRYPTION_KEY=$(openssl rand -base64 32)
COMMUNITY_SALT=$(openssl rand -base64 24)
# Placeholder until you create a Firebase project (needed only for journey sync)
FIREBASE_PROJECT_ID=jesusanswers-dev
# Add your key from https://console.anthropic.com to enable live answers (billed per answer)
ANTHROPIC_API_KEY=
CLAUDE_MODEL=claude-opus-5-5
CLAUDE_EFFORT=medium
ANSWERS_PER_HOUR=30
VOICE_SOURCES=
EOF
  chmod 600 .env
  echo "Wrote $(pwd)/.env"
fi

# Nightly backup at 02:30 server time, keeping the last 14.
mkdir -p ~/backups
cron_line="30 2 * * * cd $(pwd) && docker compose -f compose.prod.yaml exec -T postgres pg_dump -U jesusanswers jesusanswers | gzip > ~/backups/db-\$(date +\%F).sql.gz && ls -1t ~/backups/db-*.sql.gz | tail -n +15 | xargs -r rm"
( crontab -l 2>/dev/null | grep -v 'pg_dump -U jesusanswers' ; echo "$cron_line" ) | crontab -

echo "Setup done."
