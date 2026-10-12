#!/bin/bash

set -e

ANSIBLE_DIR="/home/cctnscloud/ansible"
SSH_SCRIPT="${ANSIBLE_DIR}/scripts/setup-jenkins-ssh.sh"
PLAYBOOK="${ANSIBLE_DIR}/playbooks/install-jenkins.yml"
INVENTORY="${ANSIBLE_DIR}/inventory/jenkins_target"

echo ""
echo "=========================================="
echo "       Jenkins Installation Automation"
echo "=========================================="
echo ""

echo "Step 1: Configuring SSH and Ansible connectivity..."
echo ""

"${SSH_SCRIPT}"

echo ""
echo "=========================================="
echo "Step 2: Running Jenkins Ansible Playbook"
echo "=========================================="
echo ""

ansible-playbook \
    -i "${INVENTORY}" \
    "${PLAYBOOK}"

echo ""
echo "=========================================="
echo " Jenkins Pre-Installation Completed"
echo "=========================================="
echo ""
echo "No Jenkins installation has been performed yet."
echo "The next stage will download and install Jenkins."
echo ""
