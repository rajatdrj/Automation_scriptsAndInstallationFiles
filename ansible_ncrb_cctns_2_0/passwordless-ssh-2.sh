for ip in \
10.212.174.138 10.212.174.136 10.212.174.188 10.212.174.173 10.212.174.143 10.212.174.153 10.212.174.187 10.212.174.141
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done
