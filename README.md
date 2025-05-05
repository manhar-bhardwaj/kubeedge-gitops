---

# 🚀 KubeEdge Edge Node Setup Guide (ARM64)

This guide documents how to set up an edge node using KubeEdge (`v1.15.0`) with ARM64 architecture. It also includes instructions for configuring GitHub Container Registry (GHCR), accessing Argo CD via port-forwarding, and VPN setup.

---

## 📦 Prerequisites

* K3s installed on the CloudCore node (with access to `/etc/rancher/k3s/k3s.yaml`)
* Edge node running Debian-based ARM64 OS (like Raspberry Pi OS 64-bit)
* VPN configuration file (`setupvpn`) if needed
* Internet access on the edge node

---

## 🧪 1. Get Token from CloudCore

On the CloudCore (K3s master) node:

```bash
sudo keadm gettoken --kube-config /etc/rancher/k3s/k3s.yaml
```

Copy this token. It’s required for joining the edge node.

---

## 📁 2. Setup VPN (Optional)

If your edge node connects over VPN:

```bash
./setupvpn
```

Ensure it connects before proceeding.

---

## 🛠️ 3. Install Edge Node with Custom Script

Copy your token and the edge node's local IP and run:

```bash
./install.sh --token=<YOUR_TOKEN> --nodeip=<EDGE_NODE_IP>
```

This script will:

* Install `containerd v1.7.27`
* Setup CNI (`v1.6.2`) with subnet `192.168.100.0/24`
* Download and install `keadm v1.15.0` (ARM64)
* Join the edge node to your CloudCore
* Patch `edgecore.yaml` with hostname and IP
* Restart the `edgecore` service

> ⚠️ Script assumes the CloudCore IP is `3.6.40.95`. Change in the script if needed.

---

## 🔐 4. Login to GitHub Container Registry (GHCR)

On your machine or CI/CD pipeline:

```bash
echo <YOUR_GITHUB_TOKEN> | docker login ghcr.io -u <YOUR_GITHUB_USERNAME> --password-stdin
```

---

## 🧰 5. Create GHCR Secret in Kubernetes

Replace `namespace` with your actual namespace:

```bash
kubectl create secret docker-registry ghcr-secret \
  --docker-server=ghcr.io \
  --docker-username=manhar400 \
  --docker-password=<YOUR_GITHUB_TOKEN> \
  --docker-email=your@email.com \
  -n <namespace>
```

---

## 🚪 6. Port-Forward to Access Argo CD

Access Argo CD UI on port `8989` locally:

```bash
kubectl port-forward svc/argocd-server -n argocd 8989:443
```

Then go to `https://localhost:8989`.

---

## 📦 Versions Used

| Component    | Version                                     |
| ------------ | ------------------------------------------- |
| KubeEdge     | v1.15.0                                     |
| CNI Plugins  | v1.6.2                                      |
| Containerd   | v1.7.27                                     |
| Architecture | ARM64                                       |
| OS           | Debian-based (e.g., Raspberry Pi OS 64-bit) |

---

## ✅ Result

Once complete, your ARM64 edge node will be securely connected to the CloudCore, able to pull images from GHCR, and manageable via Argo CD.

---
