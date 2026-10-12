for ip in \
10.212.135.215 10.212.135.203 10.212.135.169 10.212.135.158 10.212.135.170 10.212.135.154  10.212.135.204  10.212.135.183 10.212.135.77  10.212.135.109  10.212.135.94 10.212.135.76 10.212.174.186 10.212.174.163
do
  echo ">>> Copying SSH key to $ip"
  sshpass -p 'NcrbSecure@123456' ssh-copy-id \
    -o StrictHostKeyChecking=no \
    cctnscloud@$ip
done
#master vms ip of the backend , frontend , jenkins , keyclock 
