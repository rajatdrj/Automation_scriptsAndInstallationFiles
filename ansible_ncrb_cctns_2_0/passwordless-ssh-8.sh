for ip in \
10.212.135.125 10.212.135.69 10.212.135.118 10.212.135.93 10.212.135.67 10.212.135.83 10.212.135.112 10.212.135.91
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done
