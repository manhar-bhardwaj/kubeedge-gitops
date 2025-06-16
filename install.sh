#!/bin/bash

#GET THE TOKEN FROM THE SERVER USING THIS  sudo keadm gettoken --kube-config /etc/rancher/k3s/k3s.yaml

# ------------------------------------------------------------------------------
# 🔧 Edge Node Setup Script for KubeEdge (ARM64)
# Installs containerd, CNI plugins, keadm, and joins the edge node to the cloud
# ------------------------------------------------------------------------------

# --------------------------------------------
# 📌 Configurable variables
# --------------------------------------------
KUBEEDGE_VERSION="v1.15.0"
ARCH="arm64"
CNI_VERSION="v1.6.2"
SUBNET="192.168.100.0/24"
CLOUDCORE_IP="3.6.40.95"
# --------------------------------------------
# 🧩 Parse arguments
# --------------------------------------------
for arg in "$@"; do
  case $arg in
    --token=*)
      TOKEN="${arg#*=}"
      shift
      ;;
    --nodeip=*)
      NODE_IP="${arg#*=}"
      shift
      ;;
    *)
      echo "❌ Unknown argument: $arg"
      echo "Usage: $0 --token=<TOKEN> --nodeip=<NODE_IP>"
      exit 1
      ;;
  esac
done

# --------------------------------------------
# 📦 Install containerd (via Docker repo)
# --------------------------------------------
echo "📦 Updating package sources..."
sudo apt update
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo mkdir -p /etc/apt/keyrings

echo "🔑 Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo "➕ Adding Docker repo..."
echo "deb [arch=arm64 signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "⬇️ Installing containerd v1.7.27..."
sudo apt-get update
sudo apt-get install -y containerd.io=1.7.27-1

echo "🔄 Resetting containerd config and restarting..."
sudo rm -f /etc/containerd/config.toml
sudo systemctl restart containerd

echo "✅ Done installing containerd"

# --------------------------------------------
# 🌐 Setup CNI Bridge Config
# --------------------------------------------
echo "🌉 Configuring CNI bridge..."
sudo mkdir -p /etc/cni/net.d

sudo tee /etc/cni/net.d/10-bridge.conf > /dev/null <<EOF
{
  "cniVersion": "0.4.0",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "subnet": "$SUBNET",
    "routes": [
      { "dst": "0.0.0.0/0" }
    ]
  }
}
EOF

# --------------------------------------------
# 🧩 Install keadm (KubeEdge CLI)
# --------------------------------------------
echo "📥 Downloading keadm..."
wget https://github.com/kubeedge/kubeedge/releases/download/$KUBEEDGE_VERSION/keadm-${KUBEEDGE_VERSION}-linux-${ARCH}.tar.gz
tar -zxvf keadm-${KUBEEDGE_VERSION}-linux-${ARCH}.tar.gz
sudo cp keadm-${KUBEEDGE_VERSION}-linux-${ARCH}/keadm/keadm /usr/local/bin/keadm

# --------------------------------------------
# ⚙️ Install CNI plugins
# --------------------------------------------
echo "🔌 Installing CNI plugins..."
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/$CNI_VERSION/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz
sudo rm -f cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz

# --------------------------------------------
# 🧹 Clean up any old KubeEdge configuration
# --------------------------------------------
echo "🧹 Cleaning up old kubeedge config..."
sudo rm -rf /etc/kubeedge/

# --------------------------------------------
# 🔗 Join Edge Node to CloudCore
# --------------------------------------------
echo "🔗 Joining edge node to cloudcore..."
sudo keadm join \
  --cloudcore-ipport=${CLOUDCORE_IP}:10000 \
  --token=${TOKEN} \
  --kubeedge-version=${KUBEEDGE_VERSION}

# --------------------------------------------
# 🖊️ Update edgecore config with hostname and nodeIP
# --------------------------------------------
echo "🛠️ Patching edgecore.yaml with hostname and nodeIP..."
sudo sed -i "s/^\(\s*hostnameOverride:\).*/\1 $(awk '/Serial/ {print tolower($3)}' /proc/cpuinfo)-iot-pi/" /etc/kubeedge/config/edgecore.yaml
sudo sed -i "/^  edged:/a\ \ \ \ nodeIP: ${NODE_IP}" /etc/kubeedge/config/edgecore.yaml
sudo sed -i '/metaServer:/,/^[^ ]/s/^\(\s*\)enable:.*$/\1enable: true/' /etc/kubeedge/config/edgecore.yaml


# 🔁 Restart edgecore to apply config changes
sudo systemctl restart edgecore.service
echo "✅ Edge node setup complete."
