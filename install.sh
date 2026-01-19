#!/bin/bash

# --- 1. INITIALIZATION ---
SCRIPT_PATH="/usr/local/sbin/sshd-login"
PAM_FILE="/etc/pam.d/sshd"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
  echo "[-] Error: Please run as root (use sudo)."
  exit 1
fi

clear
echo "==========================================="
echo "   SSH NOTIFICATION SETUP (OTP VERIFY)    "
echo "==========================================="

# --- 2. WEBHOOK INPUT & VALIDATION ---
while true; do
    read -p "[?] Enter Webhook URL: " WEBHOOK_URL
    
    if [[ -z "$WEBHOOK_URL" ]]; then
        echo "[-] Error: URL cannot be empty."
        continue
    fi

    # Generate a random 6-digit OTP
    OTP=$((100000 + RANDOM % 900000))
    
    echo "[*] Sending verification code to the provided URL..."
    
    # Attempt to send OTP and capture HTTP status code
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" -X POST \
        -H "Content-Type: application/json" \
        -d "{\"content\": \"### [SECURE SETUP] Verification Code: \`$OTP\`\nPlease enter this code in your terminal to continue.\"}" \
        "$WEBHOOK_URL")

    if [ "$HTTP_STATUS" -eq 200 ] || [ "$HTTP_STATUS" -eq 204 ]; then
        echo "[+] Message sent successfully!"
        break
    else
        echo "[-] Message sending failed (HTTP $HTTP_STATUS)."
        echo "[-] Likely an incorrect Webhook URL or network issue."
        read -p "[?] Press [R] to retry or [A] to abort: " CHOICE
        if [[ "$CHOICE" =~ ^[Aa]$ ]]; then exit 1; fi
    fi
done

# --- 3. OTP VERIFICATION LOOP ---
while true; do
    echo "-------------------------------------------"
    read -p "[?] Enter the 6-digit OTP from Discord/Slack: " USER_OTP
    
    if [ "$USER_OTP" == "$OTP" ]; then
        echo "[+] OTP Verified. Proceeding with installation..."
        break
    else
        echo "[-] Wrong OTP. Please check and re-enter."
        read -p "[?] Press [R] to retry or [A] to abort: " CHOICE
        if [[ "$CHOICE" =~ ^[Aa]$ ]]; then exit 1; fi
    fi
done

# --- 4. CREATE THE NOTIFICATION SCRIPT ---
echo "[*] Creating script at $SCRIPT_PATH..."
cat << EOF > $SCRIPT_PATH
#!/bin/bash
WEBHOOK_URL="$WEBHOOK_URL"
if [ "\$PAM_TYPE" != "open_session" ]; then exit 0; fi

USER_NAME="\$PAM_USER"
REMOTE_IP="\$PAM_RHOST"
TARGET_HOST=\$(hostname)
TIMESTAMP=\$(date "+%H:%M:%S %d/%m/%y")
TTY_DEVICE="\$PAM_TTY"

GEO_DATA=\$(curl -s "https://ipinfo.io/\${REMOTE_IP}/json")
CITY=\$(echo "\$GEO_DATA" | grep '"city"' | cut -d '"' -f 4)
REGION=\$(echo "\$GEO_DATA" | grep '"region"' | cut -d '"' -f 4)
COUNTRY=\$(echo "\$GEO_DATA" | grep '"country"' | cut -d '"' -f 4)
ISP=\$(echo "\$GEO_DATA" | grep '"org"' | cut -d '"' -f 4)

MESSAGE="### [!] SSH ACCESS DETECTED: \$TARGET_HOST
* **User:** \\\`\$USER_NAME\\\`
* **Source IP:** \\\`\$REMOTE_IP\\\`
* **TTY:** \\\`\$TTY_DEVICE\\\`
* **Location:** \$CITY, \$REGION, \$COUNTRY
* **Provider:** \$ISP
* **Time:** \$TIMESTAMP"

curl -s -X POST -H "Content-Type: application/json" -d "{\"content\": \"\$MESSAGE\"}" "\$WEBHOOK_URL" > /dev/null
EOF

# --- 5. PERMISSIONS & PAM ---
chmod 700 $SCRIPT_PATH
chown root:root $SCRIPT_PATH

if ! grep -q "$SCRIPT_PATH" "$PAM_FILE"; then
    echo "session optional pam_exec.so $SCRIPT_PATH" >> "$PAM_FILE"
    echo "[+] PAM configuration updated."
else
    echo "[!] PAM configuration already exists. Skipping."
fi

echo "==========================================="
echo "   INSTALLATION COMPLETE SUCCESSFUL      "
echo "==========================================="
