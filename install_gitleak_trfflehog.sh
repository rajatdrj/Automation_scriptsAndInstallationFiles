#!/bin/bash

set -e

INSTALL_DIR="/usr/local/bin"
TMP_DIR="/tmp/security-tools"

mkdir -p "$TMP_DIR"
cd "$TMP_DIR"

echo "========================================"
echo " Installing Gitleaks"
echo "========================================"

LATEST_GITLEAKS=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep '"tag_name"' | cut -d '"' -f4)

echo "Latest Gitleaks Version: $LATEST_GITLEAKS"

curl -L -o gitleaks.tar.gz \
https://github.com/gitleaks/gitleaks/releases/download/${LATEST_GITLEAKS}/gitleaks_${LATEST_GITLEAKS#v}_linux_x64.tar.gz

tar -xzf gitleaks.tar.gz

install -m 755 gitleaks ${INSTALL_DIR}/gitleaks

echo
echo "Installed:"
${INSTALL_DIR}/gitleaks version

echo
echo "========================================"
echo " Installing TruffleHog"
echo "========================================"

curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh | sh

install -m 755 ./bin/trufflehog ${INSTALL_DIR}/trufflehog

echo
echo "Installed:"
${INSTALL_DIR}/trufflehog --version

echo
echo "========================================"
echo " Cleaning Up"
echo "========================================"

cd /
rm -rf "$TMP_DIR"

echo
echo "========================================"
echo " Installation Successful"
echo "========================================"

echo
echo "Binary Locations:"
ls -l ${INSTALL_DIR}/gitleaks
ls -l ${INSTALL_DIR}/trufflehog

echo
echo "Versions:"
${INSTALL_DIR}/gitleaks version
${INSTALL_DIR}/trufflehog --version
