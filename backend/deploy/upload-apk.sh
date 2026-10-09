#!/usr/bin/env bash
# Puts the app on the server, for the "Get the app" button of an invite link. Run from Git Bash on your PC
# after building it (flutter build apk --release --split-per-abi):
#   bash backend/deploy/upload-apk.sh ubuntu@<server-ip> <path-to-private-key> [apk]
# It is then at https://<API_DOMAIN>/download/ask-jesus.apk. The arm64 APK fits almost every phone.
set -euo pipefail
host=${1:?usage: upload-apk.sh ubuntu@<server-ip> <private-key> [apk]}
key=${2:?usage: upload-apk.sh ubuntu@<server-ip> <private-key> [apk]}
root="$(cd "$(dirname "$0")/../.." && pwd)"
apk=${3:-$root/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk}
[ -f "$apk" ] || { echo "No APK at $apk: build it first."; exit 1; }
ssh_opts=(-i "$key" -o StrictHostKeyChecking=accept-new)

ssh "${ssh_opts[@]}" "$host" 'mkdir -p ~/jesusanswers/deploy/download'
# Uploaded under another name first, so nobody downloads half a file.
scp "${ssh_opts[@]}" "$apk" "$host:jesusanswers/deploy/download/ask-jesus.apk.part"
ssh "${ssh_opts[@]}" "$host" 'mv ~/jesusanswers/deploy/download/ask-jesus.apk.part ~/jesusanswers/deploy/download/ask-jesus.apk'
domain=$(ssh "${ssh_opts[@]}" "$host" "grep '^API_DOMAIN=' ~/jesusanswers/deploy/.env | cut -d= -f2")
echo "The app: https://$domain/download/ask-jesus.apk"
