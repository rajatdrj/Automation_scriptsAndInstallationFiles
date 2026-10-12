for ip in \
10.212.174.226  10.212.174.237  10.212.174.228  10.212.174.229 10.212.174.235  10.212.174.227  10.212.174.233 10.212.135.93
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done

