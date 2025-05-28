sudo systemctl stop edgecore.service
sudo keadm reset --force
sudo rm -rf /etc/kubeedge/ /var/lib/kubeedge/
sudo pkill -f edgecore || true

# Then re-run your script
./your-script.sh --token=YOUR_TOKEN --nodeip=YOUR_NODE_IP
