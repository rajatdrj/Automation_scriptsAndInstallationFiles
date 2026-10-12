#!/bin/bash

set -e

ANSIBLE_DIR="/home/cctnscloud/ansible"
INVENTORY_FILE="${ANSIBLE_DIR}/inventory/jenkins_target"
SSH_KEY="${HOME}/.ssh/id_rsa.pub"

echo "=========================================="
echo " Jenkins Server SSH Setup"
echo "=========================================="

read -rp "Enter Jenkins Server IP: " JENKINS_IP
read -rp "Enter SSH Username: " SSH_USER

echo ""
echo "Target Server : ${JENKINS_IP}"
echo "SSH User      : ${SSH_USER}"
echo ""

if [ ! -f "${SSH_KEY}" ]; then
    echo "ERROR: SSH public key not found:"
    echo "${SSH_KEY}"
    exit 1
fi

echo "Checking passwordless SSH to ${JENKINS_IP}..."

if ssh -o BatchMode=yes \
       -o ConnectTimeout=5 \
       "${SSH_USER}@${JENKINS_IP}" "echo SSH_OK" >/dev/null 2>&1; then

    echo "Passwordless SSH is already configured."
    echo "SSH connectivity: SUCCESS"

else

    echo "Passwordless SSH is not configured."
    echo "SSH password is required to configure the public key."
    echo ""

    ssh-copy-id -i "${SSH_KEY}" \
        "${SSH_USER}@${JENKINS_IP}"

    echo ""
    echo "Testing passwordless SSH again..."

    if ssh -o BatchMode=yes \
           -o ConnectTimeout=5 \
           "${SSH_USER}@${JENKINS_IP}" "echo SSH_OK" >/dev/null 2>&1; then

        echo "Passwordless SSH configuration: SUCCESS"

    else

        echo "ERROR: Passwordless SSH configuration failed."
        exit 1

    fi

fi

echo ""
echo "Updating Ansible inventory..."

cat > "${INVENTORY_FILE}" <<EOF
[jenkins_target]
jenkins_server ansible_host=${JENKINS_IP} ansible_user=${SSH_USER}
EOF

echo "Inventory updated:"
echo ""
cat "${INVENTORY_FILE}"

echo ""
echo "Testing Ansible connectivity..."

if ansible \
    -i "${INVENTORY_FILE}" \
    jenkins_target \
    -m ping; then

    echo ""
    echo "=========================================="
    echo " SSH + Ansible Setup Successful"
    echo "=========================================="
    echo "Target Server : ${JENKINS_IP}"
    echo "SSH User      : ${SSH_USER}"
    echo "Ansible       : SUCCESS"
    echo "=========================================="

else

    echo ""
    echo "ERROR: Ansible connectivity failed."
    exit 1

fi
