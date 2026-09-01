#!/bin/bash
set -e

SERVICE_NAME="lan-music-backend.service"
TARGET_DIR="$HOME/.config/systemd/user"
SOURCE_FILE="/media/tharun/App/Music_player/backend/lan-music-backend.service"

echo "Setting up auto-start for LAN Music Server..."

mkdir -p "$TARGET_DIR"
cp "$SOURCE_FILE" "$TARGET_DIR/$SERVICE_NAME"

systemctl --user daemon-reload
systemctl --user enable "$SERVICE_NAME"
systemctl --user restart "$SERVICE_NAME"

# Enable lingering so service runs at boot even before logging in via GUI
loginctl enable-linger "$USER" || true

echo "================================================="
echo "SUCCESS: LAN Music Server is now configured to start automatically whenever your laptop turns on!"
echo "Status check command: systemctl --user status $SERVICE_NAME"
echo "================================================="
