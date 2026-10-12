#!/bin/bash

# List of target IPs (failed IPs removed)
ips=(
    10.212.135.102
    10.212.174.184
    10.212.174.170
    10.212.174.133
    10.212.113.31
    10.212.174.185
    10.212.174.182
    10.212.135.138
    10.212.174.146
    10.212.174.140
    10.212.174.144
    10.212.113.73
    10.212.113.99
    10.212.113.11
    10.212.174.132
    10.212.174.177
    10.212.107.121
    10.212.174.156
    10.212.174.130
    10.212.174.167
    10.212.174.164
    10.212.174.231
    10.212.174.181
    10.212.113.132
    10.212.135.149
    10.212.135.66
    10.212.135.113
    10.212.113.119
    10.212.135.70
    10.212.174.145
    10.212.174.165
    10.212.174.162
    10.212.174.163
    10.212.107.66
    10.212.135.35
    10.212.174.175
    10.212.113.134
    10.212.174.148
    10.212.174.135
    10.212.174.155
    10.212.135.221
    10.212.174.154
    10.212.174.147
    10.212.174.169
    10.212.135.229
    10.212.174.142
    10.212.107.98
    10.212.174.139
    10.212.107.96
    10.212.174.179
    10.212.113.77
    10.212.174.232
    10.212.174.149
    10.212.113.16
    10.212.113.80
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
