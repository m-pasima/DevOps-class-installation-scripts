# Common Setup for Kubernetes on Ubuntu EC2

This prepares an Ubuntu EC2 instance (control plane **or** worker node) for a Kubernetes cluster. It installs prerequisites, containerd, and Kubernetes components, and sets the containerd sandbox image to `registry.k8s.io/pause:3.9` to prevent mismatches.

---

## Prerequisites

### EC2 Instance

* **Control plane:** `t3.medium` or better (2 vCPU, 4 GB RAM)
* **Workers:** `t3.small` or better
* **Disk:** 20 GB+ root volume
* **Security groups (ingress):**

  * `6443` (Kubernetes API server)
  * `2379-2380` (etcd)
  * `10250-10259` (kubelet, components)
  * `179` (BGP for Calico)
  * `4789` (VXLAN for Calico, if used)
  * `22` (SSH)
* Nodes should be in the same VPC/subnet or have L3 connectivity.

### System

* Ubuntu **22.04** or **24.04** LTS
* Internet access for package downloads
* Run as **root** or with **sudo**
* Swap disabled (**script handles this**)

### User

* Assumes the default **`ubuntu`** user on EC2 (adjust paths if using another user)

---

## How to Use

1. **Save** the script below as `common-setup.sh`
2. **Make it executable:**

   ```bash
   chmod +x common-setup.sh
   ```
3. **Run on all nodes with sudo:**

   ```bash
   sudo ./common-setup.sh
   ```
4. Next steps:

   * Control plane: follow your `control-plane.md`
   * Workers: follow your `worker-join.md`

---

## Script (copy & run)

```bash
#!/bin/bash

# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required tools
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Configure kernel modules for containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF
sudo modprobe overlay
sudo modprobe br_netfilter

# Set network parameters for Kubernetes
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF
sudo sysctl --system

# Install containerd
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install -y containerd.io

# Configure containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's/sandbox_image = "registry.k8s.io\/pause:3.8"/sandbox_image = "registry.k8s.io\/pause:3.9"/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

# Install Kubernetes components (version 1.30.4)
sudo apt install -y kubelet=1.30.4-1.1 kubeadm=1.30.4-1.1 kubectl=1.30.4-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# Pre-pull Kubernetes images
sudo kubeadm config images pull --kubernetes-version=1.30.4

echo "Common setup complete. Sandbox image set to pause:3.9. Proceed to control plane or worker setup."
```

---

## What Each Command Does (quick reference)

* **System Updates**

  * `sudo apt update && sudo apt upgrade -y` — refresh & upgrade packages
* **Required Tools**

  * `apt-transport-https ca-certificates curl gnupg lsb-release` — repo & TLS utilities
* **Swap Disable**

  * `sudo swapoff -a` — turn off swap now
  * `sed -i ... /etc/fstab` — keep swap off after reboot
* **Kernel Modules**

  * `/etc/modules-load.d/containerd.conf` — ensure `overlay` & `br_netfilter` load
  * `modprobe overlay br_netfilter` — load immediately
* **Network Settings**

  * `/etc/sysctl.d/99-kubernetes-cri.conf` — enable iptables on bridges & IP forwarding
  * `sudo sysctl --system` — apply settings
* **Containerd Setup**

  * Add Docker’s GPG key & repo → `containerd.io` install
  * `containerd config default` → write `/etc/containerd/config.toml`
  * `SystemdCgroup = true` — required for kubelet + systemd
  * `sandbox_image = "registry.k8s.io/pause:3.9"` — prevent image mismatch
  * `systemctl restart/enable containerd` — start & persist
* **Kubernetes Repository**

  * Add v1.30 apt repo & GPG key
* **Kubernetes Components**

  * Install **pinned** `kubelet`, `kubeadm`, `kubectl` **1.30.4-1.1**
  * `apt-mark hold` — avoid accidental upgrades
* **Image Pre-pull**

  * `kubeadm config images pull --kubernetes-version=1.30.4` — cache images

---

## Troubleshooting

* **Package installation fails**

  * Check internet/DNS; re-run `sudo apt update`
* **Containerd issues**

  * Logs: `sudo journalctl -u containerd -f`
* **Sandbox image mismatch**

  * Verify: `sudo crictl images | grep pause`
  * Config file: `/etc/containerd/config.toml` should show `pause:3.9`

---

## Notes & Best Practices

* Keep **control plane** and **workers** on the **same minor version** (1.30.x) during setup.
* If you later change Kubernetes versions, **update the apt repo** and **remove holds** selectively:

  ```bash
  sudo apt-mark unhold kubelet kubeadm kubectl
  sudo apt update
  sudo apt install -y kubeadm=<new> kubelet=<new> kubectl=<new>
  sudo apt-mark hold kubelet kubeadm kubectl
  ```
* After reboot, re-check:

  ```bash
  lsmod | grep br_netfilter
  sysctl net.ipv4.ip_forward
  systemctl status containerd
  kubeadm version && kubectl version --client
  ```


