#!/bin/bash

# ============================================================
# Script Name : create-postgres-rsync.sh
# Description: Automates PostgreSQL log synchronization from
#               remote database servers to the central log
#               server for centralized ELK monitoring.
#
# Features    :
#   - Accepts environment, database ID, target IP, and log path.
#   - Configures SSH key authentication and host verification.
#   - Supports remote sudo for protected PostgreSQL log files.
#   - Generates an rsync script for each database server.
#   - Creates a systemd service and a 30-second timer.
#   - Stores logs under /logs/<environment>/<database-id>/.
#   - Applies readable permissions to synchronized log files.
#   - Validates connectivity and protects existing configurations.
#
# Requirements:
#   - Bash, SSH, rsync, Python 3, and systemd.
#   - Existing root SSH key: /root/.ssh/id_ed25519
#   - Authorized remote sudo access for rsync.
#
# Usage       :
#   sudo bash /home/cctnscloud/create-postgres-rsync.sh
#
# Maintainer : DevOps / Platform Engineering
# ============================================================
set -Eeuo pipefail

# ============================================================
# PostgreSQL Log Rsync Generator
# Central log server: dblogs
# SSH private key:   /root/.ssh/id_ed25519
# Timer interval:    30 seconds
# ============================================================

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run as root:"
    echo "sudo bash /home/cctnscloud/create-postgres-rsync.sh"
    exit 1
fi

BASE_LOG_DIR="/logs"
BIN_DIR="/usr/local/bin"
SYSTEMD_DIR="/etc/systemd/system"

SSH_DIR="/etc/rsync-postgres"
KNOWN_HOSTS="${SSH_DIR}/known_hosts"
SSH_PRIVATE_KEY="/root/.ssh/id_ed25519"
SSH_PUBLIC_KEY="/root/.ssh/id_ed25519.pub"

SSH_TIMEOUT=10
RSYNC_TIMEOUT=60

# -------------------- Check dependencies --------------------

for CMD in ssh ssh-keyscan ssh-keygen ssh-copy-id rsync \
           systemctl systemd-analyze python3 awk; do
    if ! command -v "$CMD" >/dev/null 2>&1; then
        echo "ERROR: Required command missing: $CMD"
        exit 1
    fi
done

# -------------------- Check existing SSH key ----------------

if [[ ! -f "$SSH_PRIVATE_KEY" || ! -f "$SSH_PUBLIC_KEY" ]]; then
    echo "ERROR: Existing SSH key pair not found."
    echo "Expected:"
    echo "  $SSH_PRIVATE_KEY"
    echo "  $SSH_PUBLIC_KEY"
    echo "No new key will be generated automatically."
    exit 1
fi

if [[ "$(stat -c '%U' "$SSH_PRIVATE_KEY")" != "root" ]]; then
    echo "ERROR: SSH private key must be owned by root."
    exit 1
fi

chmod 600 "$SSH_PRIVATE_KEY"
chmod 644 "$SSH_PUBLIC_KEY"

# -------------------- Collect configuration -----------------

echo
echo "================================================"
echo " PostgreSQL Log Rsync Service Generator"
echo "================================================"
echo

read -rp "Environment (uat/qa/dev/prod): " ENVIRONMENT
read -rp "Database identifier (e.g. ch-113-132): " DB_ID
read -rp "Target PostgreSQL server IP: " DB_IP
read -rp "Remote PostgreSQL log directory: " REMOTE_PATH
read -rp "Remote SSH user [cctnscloud]: " REMOTE_USER

REMOTE_USER="${REMOTE_USER:-cctnscloud}"
ENVIRONMENT="${ENVIRONMENT,,}"

# -------------------- Validate inputs -----------------------

if [[ ! "$ENVIRONMENT" =~ ^[a-z0-9-]+$ ]]; then
    echo "ERROR: Invalid environment."
    exit 1
fi

if [[ ! "$DB_ID" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]]; then
    echo "ERROR: Invalid database identifier."
    exit 1
fi

if [[ ! "$DB_IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||
   ! python3 -c \
     'import ipaddress,sys; ipaddress.IPv4Address(sys.argv[1])' \
     "$DB_IP" 2>/dev/null; then
    echo "ERROR: Invalid IPv4 address."
    exit 1
fi

if [[ ! "$REMOTE_PATH" =~ ^/[a-zA-Z0-9_./-]+$ ]] ||
   [[ "$REMOTE_PATH" == *"/../"* ]] ||
   [[ "$REMOTE_PATH" == *"/.." ]]; then
    echo "ERROR: Provide a safe absolute remote directory path."
    exit 1
fi

if [[ ! "$REMOTE_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ ]]; then
    echo "ERROR: Invalid SSH username."
    exit 1
fi

SERVICE="rsync-${ENVIRONMENT}-postgres-${DB_ID}"
RSYNC_SCRIPT="${BIN_DIR}/${SERVICE}.sh"
SERVICE_FILE="${SYSTEMD_DIR}/${SERVICE}.service"
TIMER_FILE="${SYSTEMD_DIR}/${SERVICE}.timer"
DEST_DIR="${BASE_LOG_DIR}/${ENVIRONMENT}/${DB_ID}"

echo
echo "Source      : ${REMOTE_USER}@${DB_IP}:${REMOTE_PATH}/"
echo "Destination : ${DEST_DIR}/"
echo "SSH key     : ${SSH_PRIVATE_KEY}"
echo "Service     : ${SERVICE}.service"
echo "Timer       : ${SERVICE}.timer"
echo

# -------------------- Protect existing services --------------

for FILE in "$RSYNC_SCRIPT" "$SERVICE_FILE" "$TIMER_FILE"; do
    if [[ -e "$FILE" ]]; then
        echo "ERROR: File already exists: $FILE"
        echo "Inspect the existing configuration before proceeding."
        exit 1
    fi
done

# -------------------- Prepare known_hosts --------------------

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

touch "$KNOWN_HOSTS"
chmod 600 "$KNOWN_HOSTS"

SSH_OPTIONS=(
    -i "$SSH_PRIVATE_KEY"
    -o IdentitiesOnly=yes
    -o BatchMode=yes
    -o "ConnectTimeout=${SSH_TIMEOUT}"
    -o StrictHostKeyChecking=yes
    -o "UserKnownHostsFile=${KNOWN_HOSTS}"
)

echo "Checking SSH host key for ${DB_IP}..."

if ! ssh-keygen -F "$DB_IP" -f "$KNOWN_HOSTS" \
    >/dev/null 2>&1; then

    TEMP_KEYS=$(mktemp)
    trap 'rm -f "${TEMP_KEYS:-}"' EXIT

    if ! ssh-keyscan -T "$SSH_TIMEOUT" "$DB_IP" \
        > "$TEMP_KEYS" 2>/dev/null; then
        echo "ERROR: Unable to retrieve SSH host key."
        exit 1
    fi

    if ! grep -qE '^[^#].*ssh-' "$TEMP_KEYS"; then
        echo "ERROR: No SSH host key received."
        exit 1
    fi

    echo
    echo "Retrieved host key fingerprints:"
    ssh-keygen -lf "$TEMP_KEYS" || true
    echo
    echo "Verify these fingerprints with the database administrator."
    read -rp "Trust and save these host keys? [y/N]: " TRUST_KEY

    if [[ ! "$TRUST_KEY" =~ ^[Yy]$ ]]; then
        echo "Aborted. Host key was not trusted."
        exit 1
    fi

    # Add only keys returned for the requested IP.
    awk -v ip="$DB_IP" '$1 == ip {print}' "$TEMP_KEYS" \
        >> "$KNOWN_HOSTS"

    rm -f "$TEMP_KEYS"
    trap - EXIT

    chmod 600 "$KNOWN_HOSTS"

    if ! ssh-keygen -F "$DB_IP" -f "$KNOWN_HOSTS" \
        >/dev/null 2>&1; then
        echo "ERROR: Failed to save host key."
        exit 1
    fi
else
    echo "Host key already exists in ${KNOWN_HOSTS}."
fi

# -------------------- Optional public-key installation -------

echo
echo "Your existing public key:"
cat "$SSH_PUBLIC_KEY"
echo

echo "The following step can install this public key on the"
echo "database server using ssh-copy-id."
echo "It may request the remote account password."
echo

read -rp "Attempt SSH public-key installation now? [y/N]: " INSTALL_KEY

if [[ "$INSTALL_KEY" =~ ^[Yy]$ ]]; then
    if ! ssh-copy-id \
        -i "$SSH_PUBLIC_KEY" \
        -o "UserKnownHostsFile=${KNOWN_HOSTS}" \
        -o StrictHostKeyChecking=yes \
        -o "IdentityFile=${SSH_PRIVATE_KEY}" \
        -o IdentitiesOnly=yes \
        "${REMOTE_USER}@${DB_IP}"; then
        echo
        echo "ERROR: Public-key installation failed."
        echo "Ask the database administrator to authorize:"
        echo "  ${SSH_PUBLIC_KEY}"
        exit 1
    fi
fi

# -------------------- Test SSH and directory access ---------

echo
echo "Testing non-interactive SSH authentication..."

if ! ssh "${SSH_OPTIONS[@]}" \
    "${REMOTE_USER}@${DB_IP}" \
    "sudo -n test -d '${REMOTE_PATH}' && sudo -n test -r '${REMOTE_PATH}' && sudo -n /usr/bin/rsync --version >/dev/null"; then

    echo
    echo "ERROR: SSH authentication or remote directory access failed."
    echo
    echo "Verify:"
    echo "1. Public key is authorized on the database server."
    echo "2. The key can be used without interactive input."
    echo "3. Remote SSH access is permitted."
    echo "4. Remote log directory exists and is readable."
    echo
    echo "No rsync service or timer has been created."
    exit 1
fi

echo "SSH authentication and remote directory check passed."

# -------------------- Generate rsync script -----------------

mkdir -p "$DEST_DIR"
chmod 0750 "$DEST_DIR"

cat > "$RSYNC_SCRIPT" <<EOF
#!/bin/bash
set -Eeuo pipefail

exec /usr/bin/rsync \\
    --archive \\
    --no-owner \
    --no-group \
    --chmod=D755,F644 \
    --partial \\
    --update \\
    --human-readable \\
    --timeout=${RSYNC_TIMEOUT} \\
    --rsync-path="sudo -n /usr/bin/rsync" \\
    --rsh="/usr/bin/ssh -i ${SSH_PRIVATE_KEY} -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=${SSH_TIMEOUT} -o StrictHostKeyChecking=yes -o UserKnownHostsFile=${KNOWN_HOSTS}" \\
    "${REMOTE_USER}@${DB_IP}:${REMOTE_PATH}/" \\
    "${DEST_DIR}/"
EOF

chmod 0750 "$RSYNC_SCRIPT"

# -------------------- Generate systemd service ---------------

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Sync PostgreSQL Logs from ${DB_IP} (${DB_ID})
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
Group=root
UMask=0027
ExecStart=${RSYNC_SCRIPT}
EOF

chmod 0644 "$SERVICE_FILE"

# -------------------- Generate systemd timer -----------------

cat > "$TIMER_FILE" <<EOF
[Unit]
Description=Run PostgreSQL Log Rsync for ${DB_ID} Every 30 Seconds

[Timer]
OnBootSec=30s
OnUnitActiveSec=30s
AccuracySec=1s
Unit=${SERVICE}.service

[Install]
WantedBy=timers.target
EOF

chmod 0644 "$TIMER_FILE"

# -------------------- Validate and activate -----------------

echo
echo "Validating systemd units..."

if ! systemd-analyze verify "$SERVICE_FILE" "$TIMER_FILE"; then
    echo "ERROR: systemd validation failed."
    echo "Inspect the generated files before continuing."
    exit 1
fi

systemctl daemon-reload
systemctl enable --now "${SERVICE}.timer"

# -------------------- Initial synchronization ----------------

echo
read -rp "Run the first rsync immediately? [Y/n]: " RUN_NOW

if [[ ! "$RUN_NOW" =~ ^[Nn]$ ]]; then
    if systemctl start "${SERVICE}.service"; then
        echo "Initial rsync completed successfully."
    else
        echo "WARNING: Initial rsync failed."
        echo "Check: journalctl -u ${SERVICE}.service -n 50"
    fi
fi

# -------------------- Summary --------------------------------

echo
echo "================================================"
echo " PostgreSQL Rsync Setup Complete"
echo "================================================"
echo "Source      : ${REMOTE_USER}@${DB_IP}:${REMOTE_PATH}/"
echo "Destination : ${DEST_DIR}/"
echo "Service     : ${SERVICE}.service"
echo "Timer       : ${SERVICE}.timer"
echo
echo "Check timer:"
echo "  systemctl status ${SERVICE}.timer"
echo
echo "Check service:"
echo "  systemctl status ${SERVICE}.service"
echo
echo "View logs:"
echo "  journalctl -u ${SERVICE}.service -n 50 --no-pager"
echo
echo "Check synchronized files:"
echo "  ls -lah '${DEST_DIR}/'"
echo "================================================"
