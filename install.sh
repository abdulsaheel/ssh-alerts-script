#!/bin/bash

# ==============================
# SSH LOGIN ALERT INSTALLER
# (Discord Embed – FIXED)
# ==============================

SCRIPT_PATH="/usr/local/bin/ssh-alert.sh"
SSHRC_FILE="/etc/ssh/sshrc"
ICON_URL="https://www-assets.kolide.com/assets/inventory/device_properties/icons/ssh-keys-399db5d7.png"

# ---- Root check ----
if [ "$EUID" -ne 0 ]; then
  echo "[-] Run as root (sudo)."
  exit 1
fi

clear
echo "==========================================="
echo "   SSH LOGIN ALERT INSTALLER (EMBED)"
echo "==========================================="

# ---- User input ----
read -p "[?] Enter Discord Webhook URL: " WEBHOOK_URL
[ -z "$WEBHOOK_URL" ] && { echo "[-] Webhook URL cannot be empty."; exit 1; }

read -p "[?] Enter Server Name: " SERVER_NAME
[ -z "$SERVER_NAME" ] && { echo "[-] Server Name cannot be empty."; exit 1; }

echo "[*] Installing SSH alert script..."

# ---- Create trigger script (NO VARIABLE EXPANSION) ----
cat <<'EOF' > "$SCRIPT_PATH"
#!/bin/bash

WEBHOOK_URL="__WEBHOOK_URL__"
SERVER_NAME="__SERVER_NAME__"
ICON_URL="__ICON_URL__"

USER="$(whoami)"
HOST="$(hostname)"
TIME="$(date '+%H:%M:%S %d/%m/%Y')"

JSON_PAYLOAD=$(cat <<JSON
{
  "username": "SSH Monitor",
  "avatar_url": "$ICON_URL",
  "embeds": [
    {
      "author": {
        "name": "SSH Login Detected",
        "icon_url": "$ICON_URL"
      },
      "color": 15158332,
      "fields": [
        { "name": "Server", "value": "$SERVER_NAME", "inline": true },
        { "name": "Host", "value": "$HOST", "inline": true },
        { "name": "User", "value": "$USER", "inline": true },
        { "name": "Time", "value": "$TIME", "inline": false }
      ]
    }
  ]
}
JSON
)

/usr/bin/curl -s \
  -H "Content-Type: application/json" \
  -d "$JSON_PAYLOAD" \
  "$WEBHOOK_URL" > /dev/null

exit 0
EOF

# ---- Inject real values ----
sed -i "s|__WEBHOOK_URL__|$WEBHOOK_URL|g" "$SCRIPT_PATH"
sed -i "s|__SERVER_NAME__|$SERVER_NAME|g" "$SCRIPT_PATH"
sed -i "s|__ICON_URL__|$ICON_URL|g" "$SCRIPT_PATH"

# ---- Permissions ----
chmod 755 "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

# ---- Update sshrc ----
[ ! -f "$SSHRC_FILE" ] && touch "$SSHRC_FILE"

grep -qx "$SCRIPT_PATH" "$SSHRC_FILE" || echo "$SCRIPT_PATH" >> "$SSHRC_FILE"

echo "==========================================="
echo "   INSTALLATION COMPLETE"
echo "==========================================="
echo "[✓] Script: $SCRIPT_PATH"
echo "[✓] sshrc updated"
echo
echo "Test:"
echo "  $SCRIPT_PATH"
echo "Then SSH again."
