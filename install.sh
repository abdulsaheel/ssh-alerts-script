#!/bin/bash

# ==============================
# SSH LOGIN ALERT INSTALLER
# Filter: Excludes ONLY 10.x.x.x
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

echo "[*] Creating SSH alert script (Excluding 10.x.x.x)..."

# ---- Create trigger script ----
# We use 'EOF' in quotes to prevent the current shell from evaluating variables
cat << 'EOF' > "$SCRIPT_PATH"
#!/bin/bash

# === CONFIGURATION ===
WEBHOOK_URL="REPLACE_WEBHOOK"
SERVER_NAME="REPLACE_SERVER"
ICON_URL="REPLACE_ICON"

# === IP DETECTION ===
# SSH_CLIENT variable contains: "REMOTE_IP REMOTE_PORT LOCAL_PORT"
REMOTE_IP=$(echo $SSH_CLIENT | awk '{print $1}')

# === EXCLUSION LOGIC ===
# Exit silently ONLY if the IP starts with 10.
if [[ "$REMOTE_IP" =~ ^10\. ]]; then
    exit 0
fi

# If IP is empty (like a local sudo su), we can choose to exit or continue.
# Currently set to continue so you see all non-10.x activity.

# === DATA COLLECTION ===
USER=$(whoami)
HOST=$(hostname)
TIME=$(date '+%H:%M:%S %d/%m/%Y')

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
        { "name": "Remote IP", "value": "$REMOTE_IP", "inline": true },
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

# ---- Inject Variables into the created script ----
sed -i "s|REPLACE_WEBHOOK|$WEBHOOK_URL|g" "$SCRIPT_PATH"
sed -i "s|REPLACE_SERVER|$SERVER_NAME|g" "$SCRIPT_PATH"
sed -i "s|REPLACE_ICON|$ICON_URL|g" "$SCRIPT_PATH"

# ---- Permissions ----
chmod 755 "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

# ---- Update sshrc safely ----
if [ ! -f "$SSHRC_FILE" ]; then
  touch "$SSHRC_FILE"
fi

if ! grep -q "$SCRIPT_PATH" "$SSHRC_FILE"; then
  echo "$SCRIPT_PATH" >> "$SSHRC_FILE"
  echo "[+] /etc/ssh/sshrc updated."
else
  echo "[!] sshrc already linked. Updated script content."
fi

echo "==========================================="
echo "    INSTALLATION COMPLETE"
echo "==========================================="
echo "[✓] Alerts for 10.x.x.x are SILENCED"
echo "[✓] Alerts for 192.168.x.x and Public IPs are ENABLED"
