  GNU nano 7.2                                                                                 installv7.sh                                                                                           
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
                                                                                          [ Read 219 lines ]
^G Help           ^O Write Out      ^W Where Is       ^K Cut            ^T Execute        ^C Location       M-U Undo          M-A Set Mark      M-] To Bracket    M-Q Previous      ^B Back
^X Exit           ^R Read File      ^\ Replace        ^U Paste          ^J Justify        ^/ Go To Line     M-E Redo          M-6 Copy          ^Q Where Was      M-W Next          ^F Forward
