for ip in \
10.212.113.131 10.212.113.132 10.212.113.134 10.212.174.230 10.212.174.231 10.212.174.232  10.212.135.102 10.212.135.113 10.212.135.122 10.212.135.72
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done

