#!/bin/bash

# ==============================
# SSH LOGIN ALERT INSTALLER
# (Discord Embed Version)
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
echo "   SSH LOGIN ALERT INSTALLER (EMBED)"
echo "==========================================="

# ---- User input ----
read -p "[?] Enter Discord Webhook URL: " WEBHOOK_URL
[ -z "$WEBHOOK_URL" ] && { echo "[-] Webhook URL cannot be empty."; exit 1; }

read -p "[?] Enter Server Name: " SERVER_NAME
[ -z "$SERVER_NAME" ] && { echo "[-] Server Name cannot be empty."; exit 1; }

echo "[*] Creating SSH alert script..."

# ---- Create trigger script ----
cat <<EOF > "$SCRIPT_PATH"
#!/bin/bash

# === CONFIGURATION ===
WEBHOOK_URL="$WEBHOOK_URL"
SERVER_NAME="$SERVER_NAME"
ICON_URL="$ICON_URL"

# === DATA COLLECTION ===
USER="\$(whoami)"
HOST="\$(hostname)"
TIME="\$(date '+%H:%M:%S %d/%m/%Y')"

# === EMBED JSON (SAFE) ===
JSON_PAYLOAD=\$(cat <<JSON
{
  "username": "SSH Monitor",
  "avatar_url": "\$ICON_URL",
  "embeds": [
    {
      "author": {
        "name": "SSH Login Detected",
        "icon_url": "\$ICON_URL"
      },
      "color": 15158332,
      "fields": [
        { "name": "Server", "value": "\$SERVER_NAME", "inline": true },
        { "name": "Host", "value": "\$HOST", "inline": true },
        { "name": "User", "value": "\$USER", "inline": true },
        { "name": "Time", "value": "\$TIME", "inline": false }
      ]
    }
  ]
}
JSON
)

# === SEND WEBHOOK ===
/usr/bin/curl -s \\
  -H "Content-Type: application/json" \\
  -d "\$JSON_PAYLOAD" \\
  "\$WEBHOOK_URL" > /dev/null

exit 0
EOF

# ---- Permissions ----
chmod 755 "$SCRIPT_PATH"
chown root:root "$SCRIPT_PATH"

# ---- Update sshrc safely ----
[ ! -f "$SSHRC_FILE" ] && touch "$SSHRC_FILE"

if ! grep -qx "$SCRIPT_PATH" "$SSHRC_FILE"; then
  echo "$SCRIPT_PATH" >> "$SSHRC_FILE"
  echo "[+] /etc/ssh/sshrc updated."
else
  echo "[!] sshrc already contains alert script. Skipping."
fi

echo "==========================================="
echo "   INSTALLATION COMPLETE"
echo "==========================================="
echo "[✓] Script installed at: $SCRIPT_PATH"
echo "[✓] Discord embed alerts enabled"
echo
echo "➡️  Test manually:"
echo "    $SCRIPT_PATH"
echo
echo "➡️  Then SSH again to verify alert."
