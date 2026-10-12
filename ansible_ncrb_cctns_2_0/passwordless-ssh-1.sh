for ip in \
10.212.174.152 10.212.174.135 10.212.174.174 10.212.174.183
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done
