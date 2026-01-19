#!/bin/bash

# ==============================
# SSH LOGIN ALERT INSTALLER
# ==============================

SCRIPT_PATH="/usr/local/bin/ssh-alert.sh"
SSHRC_FILE="/etc/ssh/sshrc"

# ---- Root check ----
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run this installer as root (sudo)."
  exit 1
fi

clear
echo "==========================================="
echo "      SSH LOGIN ALERT INSTALLER"
echo "==========================================="

# ---- User input ----
read -p "[?] Enter Discord Webhook URL: " WEBHOOK_URL
if [ -z "$WEBHOOK_URL" ]; then
  echo "[-] Webhook URL cannot be empty."
  exit 1
fi

read -p "[?] Enter Server Name: " SERVER_NAME
if [ -z "$SERVER_NAME" ]; then
  echo "[-] Server Name cannot be empty."
  exit 1
fi

echo "[*] Installing SSH alert script..."

# ---- Create trigger script ----
cat << EOF > "$SCRIPT_PATH"
#!/bin/bash

# === CONFIGURATION ===
WEBHOOK_URL="$WEBHOOK_URL"
SERVER_NAME="$SERVER_NAME"

# === DATA COLLECTION ===
USER="\$(whoami)"
HOST="\$(hostname)"
TIME="\$(date '+%H:%M:%S %d/%m/%Y')"

# === MESSAGE (JSON SAFE) ===
CONTENT="### SSH LOGIN DETECTED\nServer: \${SERVER_NAME}\nHost: \${HOST}\nUser: \${USER}\nTime: \${TIME}"

JSON_PAYLOAD=\$(printf '{"content":"%s"}' "\$(printf '%s' "\$CONTENT" | sed 's/"/\\\\\"/g')")

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
if [ ! -f "$SSHRC_FILE" ]; then
  touch "$SSHRC_FILE"
fi

if ! grep -q "$SCRIPT_PATH" "$SSHRC_FILE"; then
  echo "$SCRIPT_PATH" >> "$SSHRC_FILE"
  echo "[+] /etc/ssh/sshrc updated."
else
  echo "[!] sshrc already contains alert script. Skipping."
fi

echo "==========================================="
echo "   INSTALLATION COMPLETE"
echo "==========================================="
echo "[✓] Script installed at: $SCRIPT_PATH"
echo "[✓] SSH hook added via: $SSHRC_FILE"
echo
echo "➡️  Test manually:"
echo "    $SCRIPT_PATH"
echo
echo "➡️  Then SSH again to verify alert."
