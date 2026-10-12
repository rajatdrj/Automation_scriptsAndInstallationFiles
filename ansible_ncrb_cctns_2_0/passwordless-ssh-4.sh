for ip in \
10.212.135.159 10.212.135.172 10.212.135.173 10.212.135.219 10.212.135.98 10.212.135.79 10.212.135.119 10.212.135.115
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done

