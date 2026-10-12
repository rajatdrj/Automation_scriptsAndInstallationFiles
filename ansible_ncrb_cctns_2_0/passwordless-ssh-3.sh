for ip in \
10.212.174.176 10.212.174.172
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done
