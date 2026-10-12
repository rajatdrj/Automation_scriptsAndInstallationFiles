for ip in \
10.212.135.70  10.212.135.120 10.212.135.92 10.212.135.101 10.212.135.105
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done

