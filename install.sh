#!/bin/bash

# ==============================
# SSH LOGIN ALERT INSTALLER
# Logic: Ignore 10.x and 192.168.x
# Alert: EVERYTHING ELSE (including 127.0.0.1)
# ==============================

SCRIPT_PATH="/usr/local/bin/ssh-alert.sh"
SSHRC_FILE="/etc/ssh/sshrc"
ICON_URL="https://www-assets.kolide.com/assets/inventory/device_properties/icons/ssh-keys-399db5d7.png"

# ---- Root check ----
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this installer as root (sudo)."
  exit 1
fi

clear
echo "==========================================="
echo "   SSH LOGIN ALERT INSTALLER"
echo "==========================================="

# ---- User input ----
read -p "[?] Enter Discord Webhook URL: " WEBHOOK_URL
if [ -z "$WEBHOOK_URL" ]; then
  echo "[-] Webhook URL cannot be empty."
  exit 1
fi

read -p "[?] Enter Server Name: " SERVER_NAME
if [ -z "$SERVER_NAME" ]; then
  SERVER_NAME=$(hostname)
fi

echo "[*] Creating script (127.0.0.1 will now ALERT)..."

# ---- Create trigger script ----
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

# === CONFIGURATION ===
WEBHOOK_URL="REPLACE_WEBHOOK"
SERVER_NAME="REPLACE_SERVER"
ICON_URL="REPLACE_ICON"

# === IP DETECTION ===
# SSH_CLIENT: "IP PORT_REMOTE PORT_LOCAL"
REMOTE_IP=$(echo $SSH_CLIENT | awk '{print $1}')

# If REMOTE_IP is empty (happens on some local hops), set it to "Local/Unknown"
if [ -z "$REMOTE_IP" ]; then
    REMOTE_IP="Local-Terminal"
fi

# === THE SILENCER FILTERS ===
# We ONLY ignore the specific internal ranges you requested.
if [[ "$REMOTE_IP" =~ ^10\. ]] || [[ "$REMOTE_IP" =~ ^192\.168\. ]]; then
    exit 0
fi

# === DATA COLLECTION ===
USER=$(whoami)
HOST=$(hostname)
TIME=$(date '+%H:%M:%S %d/%m/%Y')
PROC_INFO=$(ps -o comm= -p $PPID)

# === SEND WEBHOOK ===
JSON_PAYLOAD=$(cat << JSON
{
  "username": "SSH Monitor",
  "avatar_url": "$ICON_URL",
  "embeds": [
    {
      "title": "SSH Login Detected",
      "color": 15158332,
      "fields": [
        { "name": "Server", "value": "$SERVER_NAME", "inline": true },
        { "name": "User", "value": "$USER", "inline": true },
        { "name": "Source IP", "value": "$REMOTE_IP", "inline": true },
        { "name": "Process", "value": "$PROC_INFO", "inline": true },
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

# ---- Inject Variables ----
sed -i "s|REPLACE_WEBHOOK|$WEBHOOK_URL|g" "$SCRIPT_PATH"
sed -i "s|REPLACE_SERVER|$SERVER_NAME|g" "$SCRIPT_PATH"
sed -i "s|REPLACE_ICON|$ICON_URL|g" "$SCRIPT_PATH"

# ---- Permissions ----
chmod 755 "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

# ---- Update sshrc ----
if [ ! -f "$SSHRC_FILE" ]; then
  touch "$SSHRC_FILE"
fi

if ! grep -q "$SCRIPT_PATH" "$SSHRC_FILE"; then
  echo "$SCRIPT_PATH" >> "$SSHRC_FILE"
fi

echo "==========================================="
echo "    INSTALLATION COMPLETE"
echo "==========================================="
echo "[✓] Ignored: 10.x.x.x and 192.168.x.x"
echo "[✓] ALERTING ON: 127.0.0.1 and all Public IPs"
