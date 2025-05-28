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
CNI_VERSION="v1.6.2"
SUBNET="192.168.100.0/24"
CLOUDCORE_IP="3.6.40.95"

# --------------------------------------------
# 🔍 Auto-detect architecture (minimal fix for compatibility)
# --------------------------------------------
detect_arch() {
    local arch=$(uname -m)
    case $arch in
        x86_64)
            echo "amd64"
            ;;
        aarch64)
            echo "arm64"
            ;;
        armv7l|armv6l)
            echo "arm"
            ;;
        *)
            echo "❌ Unsupported architecture: $arch"
            exit 1
            ;;
    esac
}

ARCH=$(detect_arch)
echo "🖥️ Detected architecture: $ARCH"

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

# Validate required arguments
if [ -z "$TOKEN" ] || [ -z "$NODE_IP" ]; then
    echo "❌ Error: Both --token and --nodeip are required"
    echo "Usage: $0 --token=<TOKEN> --nodeip=<NODE_IP>"
    exit 1
fi

# --------------------------------------------
# 📦 Install containerd (via Docker repo) - EXACT SAME AS ORIGINAL
# --------------------------------------------
echo "📦 Updating package sources..."
sudo apt update
sudo rm -f /etc/apt/sources.list.d/docker.list
sudo mkdir -p /etc/apt/keyrings

echo "🔑 Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes

# Fix: Use proper architecture detection instead of hardcoded arm64
case $(uname -m) in
    x86_64) DOCKER_ARCH="amd64" ;;
    aarch64) DOCKER_ARCH="arm64" ;;
    armv7l) DOCKER_ARCH="armhf" ;;
    *) echo "❌ Unsupported architecture for Docker repo"; exit 1 ;;
esac

echo "➕ Adding Docker repo..."
echo "deb [arch=$DOCKER_ARCH signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "⬇️ Installing containerd v1.7.27..."
sudo apt-get update

# Try the exact version first, fallback if not available
if ! sudo apt-get install -y containerd.io=1.7.27-1; then
    echo "⚠️ Exact version 1.7.27-1 not available, trying any 1.7.27 version..."
    if ! sudo apt-get install -y containerd.io | grep "1.7.27"; then
        echo "⚠️ Version 1.7.27 not found, installing latest 1.7.x available..."
        # Get latest 1.7.x version to maintain stability
        AVAILABLE_VERSION=$(apt-cache madison containerd.io | grep "1.7" | head -1 | awk '{print $3}')
        if [ -n "$AVAILABLE_VERSION" ]; then
            sudo apt-get install -y containerd.io=$AVAILABLE_VERSION
        else
            echo "❌ No compatible containerd version found"
            exit 1
        fi
    fi
fi

echo "🔄 Resetting containerd config and restarting..."

# Fix: Stop containerd properly and clean up leftover processes
sudo systemctl stop containerd 2>/dev/null || true
sudo pkill -f containerd-shim || true
sleep 2

# Fix: Generate clean config instead of just deleting
sudo mkdir -p /etc/containerd
sudo containerd config default > /tmp/containerd-config.toml
# Fix: Set cgroupfs for better compatibility
sed -i 's/SystemdCgroup = true/SystemdCgroup = false/' /tmp/containerd-config.toml
sudo cp /tmp/containerd-config.toml /etc/containerd/config.toml
sudo rm -f /tmp/containerd-config.toml

sudo systemctl restart containerd

# Verify containerd started
if ! sudo systemctl is-active --quiet containerd; then
    echo "❌ containerd failed to start"
    sudo systemctl status containerd
    exit 1
fi

echo "✅ Done installing containerd"

# --------------------------------------------
# 🌐 Setup CNI Bridge Config - EXACT SAME AS ORIGINAL
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
# 🧩 Install keadm (KubeEdge CLI) - EXACT SAME AS ORIGINAL
# --------------------------------------------
echo "📥 Downloading keadm..."
wget https://github.com/kubeedge/kubeedge/releases/download/$KUBEEDGE_VERSION/keadm-${KUBEEDGE_VERSION}-linux-${ARCH}.tar.gz
tar -zxvf keadm-${KUBEEDGE_VERSION}-linux-${ARCH}.tar.gz
sudo cp keadm-${KUBEEDGE_VERSION}-linux-${ARCH}/keadm/keadm /usr/local/bin/keadm

# Clean up
rm -rf keadm-${KUBEEDGE_VERSION}-linux-${ARCH}*

# --------------------------------------------
# ⚙️ Install CNI plugins - EXACT SAME AS ORIGINAL
# --------------------------------------------
echo "🔌 Installing CNI plugins..."
sudo mkdir -p /opt/cni/bin
wget https://github.com/containernetworking/plugins/releases/download/$CNI_VERSION/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz
sudo rm -f cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz

# --------------------------------------------
# 🧹 Clean up any old KubeEdge configuration - ENHANCED
# --------------------------------------------
echo "🧹 Cleaning up old kubeedge config..."

# Stop EdgeCore service if running
sudo systemctl stop edgecore.service 2>/dev/null || true

# Reset any existing EdgeCore installation
sudo keadm reset --force 2>/dev/null || true

# Remove configuration directories
sudo rm -rf /etc/kubeedge/
sudo rm -rf /var/lib/kubeedge/

# Kill any leftover processes
sudo pkill -f edgecore || true
sleep 2

echo "✅ Cleanup completed"

# --------------------------------------------
# 🔗 Join Edge Node to CloudCore - MINIMAL FIX ADDED
# --------------------------------------------
echo "🔗 Joining edge node to cloudcore..."

# Fix: Add cgroupdriver and runtime endpoint for compatibility
sudo keadm join \
  --cloudcore-ipport=${CLOUDCORE_IP}:10000 \
  --token=${TOKEN} \
  --kubeedge-version=${KUBEEDGE_VERSION} \
  --runtimetype=remote \
  --remote-runtime-endpoint=unix:///run/containerd/containerd.sock \
  --cgroupdriver=cgroupfs

if [ $? -ne 0 ]; then
    echo "❌ Failed to join edge node to CloudCore"
    exit 1
fi

# --------------------------------------------
# 🖊️ Update edgecore config with hostname and nodeIP - EXACT SAME AS ORIGINAL
# --------------------------------------------
echo "🛠️ Patching edgecore.yaml with hostname and nodeIP..."
sudo sed -i "s/^\(\s*hostnameOverride:\).*/\1 $(awk '/Serial/ {print tolower($3)}' /proc/cpuinfo)-iot-pi/" /etc/kubeedge/config/edgecore.yaml
sudo sed -i "/^  edged:/a\ \ \ \ nodeIP: ${NODE_IP}" /etc/kubeedge/config/edgecore.yaml
sudo sed -i '/metaServer:/,/^[^ ]/s/^\(\s*\)enable:.*$/\1enable: true/' /etc/kubeedge/config/edgecore.yaml

# 🔁 Restart edgecore to apply config changes - EXACT SAME AS ORIGINAL
sudo systemctl restart edgecore.service

echo "✅ Edge node setup complete."
