#!/bin/bash

# List of target IPs (failed IPs removed)
ips=(
10.212.135.85
10.212.135.237
10.212.107.90
10.212.174.185
10.212.107.106
10.212.174.148
10.212.113.19
10.212.113.132
10.212.113.11
10.212.107.83
10.212.107.71
10.212.113.138
10.212.113.25
10.212.113.52
10.212.113.87
10.212.113.98
10.212.113.73
10.212.107.82
10.212.135.178
10.212.135.87
10.212.135.36
10.212.135.82
10.212.113.16
10.212.107.96
10.212.113.80
10.212.107.98
10.212.135.221
10.212.135.99
10.212.135.35
10.212.135.229
10.212.107.73
)

# Passwords in order of preference
passwords=(
    "NcrbSecure@123456"
    "NcrbSecure@1234567"
    "NcrbSecure@12345"
)

for ip in "${ips[@]}"; do
    echo ">>> Trying to copy SSH key to $ip"
    success=0
    for pwd in "${passwords[@]}"; do
        echo "   Trying password: $pwd"
        if sshpass -p "$pwd" ssh-copy-id \
            -o StrictHostKeyChecking=no \
            cctnscloud@"$ip" > /dev/null 2>&1; then
            echo "   ✅ Success with password: $pwd"
            success=1
            break
        else
            echo "   ❌ Failed with password: $pwd"
        fi
    done
    if [ $success -eq 0 ]; then
        echo "!!! ERROR: Could not copy SSH key to $ip with any of the provided passwords."
    fi
    echo
done
