Kubernetes Common Setup for Ubuntu EC2
This script prepares an Ubuntu EC2 instance (control plane or worker node) for a Kubernetes cluster by installing prerequisites, containerd, and Kubernetes components. It sets the sandbox image to registry.k8s.io/pause:3.9 to avoid mismatches.
Prerequisites

EC2 Instance:
Control plane: At least t3.medium (2 vCPU, 4GB RAM).
Worker nodes: At least t3.small.
20GB+ root volume.
Security groups allowing ports: 6443 (API server), 2379-2380 (etcd), 10250-10259 (kubelet), 179 (BGP for Calico), 4789 (VXLAN for Calico, if used), and 22 (SSH).
Same VPC/subnet or network connectivity between nodes.


System:
Ubuntu 22.04 or 24.04 LTS.
Internet access for package downloads.
Run as root or with sudo.
Swap disabled (script handles this).


User:
Assumes ubuntu user (default on EC2). Adjust paths if using a different user.



Usage

Save this script as common-setup.sh in your repository.
Make it executable:chmod +x common-setup.sh


Run with sudo on each node (control plane and workers):sudo ./common-setup.sh


After completion, proceed to control-plane.md for the control plane node or worker-join.md for worker nodes.

Script
#!/bin/bash

# Update and upgrade system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release

# Disable swap
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# Load kernel modules for containerd
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Set sysctl params for Kubernetes
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

# Configure containerd with SystemdCgroup and correct pause image
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -i 's/            SystemdCgroup = false/            SystemdCgroup = true/' /etc/containerd/config.toml
sudo sed -i 's/sandbox_image = "registry.k8s.io\/pause:3.8"/sandbox_image = "registry.k8s.io\/pause:3.9"/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd

# Add Kubernetes apt repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update

# Install Kubernetes components (pin to version 1.30.4 for stability)
sudo apt install -y kubelet=1.30.4-1.1 kubeadm=1.30.4-1.1 kubectl=1.30.4-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# Pre-pull images (optional but recommended)
sudo kubeadm config images pull --kubernetes-version=1.30.4

echo "Common setup complete. Sandbox image fixed to pause:3.9. Now run the control plane or worker script as appropriate."

Command Explanations

System Updates:
sudo apt update && sudo apt upgrade -y: Updates package lists and upgrades installed packages.


Required Packages:
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release: Installs tools for secure package downloads and repository management.


Swap Disable:
sudo swapoff -a: Disables swap immediately.
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab: Disables swap permanently.


Kernel Modules:
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf: Configures overlay and br_netfilter for containerd.
sudo modprobe overlay br_netfilter: Loads these modules.


Sysctl Settings:
cat <<EOF | sudo tee /etc/sysctl.d/99-kubernetes-cri.conf: Enables IPv4 forwarding and bridged traffic.
sudo sysctl --system: Applies sysctl changes.


Containerd Installation:
curl ... | sudo gpg --dearmor ...: Adds Docker’s GPG key.
echo "deb ..." | sudo tee ...: Adds Docker’s apt repository.
sudo apt install -y containerd.io: Installs containerd.


Containerd Configuration:
containerd config default | sudo tee /etc/containerd/config.toml: Generates default config.
sudo sed -i ... SystemdCgroup ...: Enables systemd cgroup driver.
sudo sed -i ... sandbox_image ...: Sets pause image to registry.k8s.io/pause:3.9.
sudo systemctl restart containerd: Restarts containerd.
sudo systemctl enable containerd: Ensures containerd starts on boot.


Kubernetes Repository:
curl ... | sudo gpg --dearmor ...: Adds Kubernetes GPG key.
echo 'deb ...' | sudo tee ...: Adds Kubernetes apt repository.


Kubernetes Components:
sudo apt install -y kubelet=1.30.4-1.1 kubeadm=1.30.4-1.1 kubectl=1.30.4-1.1: Installs pinned Kubernetes tools.
sudo apt-mark hold ...: Prevents accidental upgrades.


Image Pre-pull:
sudo kubeadm config images pull --kubernetes-version=1.30.4: Pre-pulls Kubernetes images.



Troubleshooting

Apt errors: Ensure internet access; retry sudo apt update.
Containerd issues: Check logs with sudo journalctl -u containerd.
Pause image mismatch: Verify registry.k8s.io/pause:3.9 in /etc/containerd/config.toml using sudo crictl images | grep pause.
