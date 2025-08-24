Common Setup for Kubernetes on Ubuntu EC2
This script prepares an Ubuntu EC2 instance (control plane or worker node) for a Kubernetes cluster. It installs prerequisites, containerd, and Kubernetes components, setting the sandbox image to registry.k8s.io/pause:3.9 to prevent mismatches.
Prerequisites

EC2 Instance:
Control plane: t3.medium or better (2 vCPU, 4GB RAM).
Worker nodes: t3.small or better.
20GB+ root volume.
Security groups allowing:
6443 (API server)
2379-2380 (etcd)
10250-10259 (kubelet)
179 (BGP for Calico)
4789 (VXLAN for Calico, if used)
22 (SSH)


Nodes in the same VPC/subnet or with network connectivity.


System:
Ubuntu 22.04 or 24.04 LTS.
Internet access for package downloads.
Run as root or with sudo.
Swap disabled (handled by script).


User:
Assumes ubuntu user (default on EC2). Adjust paths for other users.



How to Use

Save this as common-setup.sh in your repository.
Make it executable:chmod +x common-setup.sh


Run with sudo on all nodes:sudo ./common-setup.sh


Next, use control-plane.md for the control plane or worker-join.md for worker nodes.

Script
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

What Each Command Does

System Updates:
sudo apt update && sudo apt upgrade -y: Refreshes package lists and updates installed packages.


Required Tools:
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release: Installs utilities for secure downloads and repository management.


Swap Disable:
sudo swapoff -a: Turns off swap memory.
sudo sed -i ...: Disables swap in /etc/fstab for reboots.


Kernel Modules:
cat <<EOF ...: Adds overlay and br_netfilter modules for containerd networking.
sudo modprobe ...: Loads these modules.


Network Settings:
cat <<EOF ...: Configures IPv4 forwarding and bridged traffic.
sudo sysctl --system: Applies network settings.


Containerd Setup:
curl ... | sudo gpg ...: Adds Docker’s GPG key.
echo "deb ..." | sudo tee ...: Adds Docker’s repository.
sudo apt install -y containerd.io: Installs containerd.
containerd config default ...: Generates containerd configuration.
sudo sed -i ... SystemdCgroup ...: Enables systemd cgroup for Kubernetes.
sudo sed -i ... sandbox_image ...: Sets pause image to registry.k8s.io/pause:3.9.
sudo systemctl restart/enable containerd: Restarts and enables containerd.


Kubernetes Repository:
curl ... | sudo gpg ...: Adds Kubernetes GPG key.
echo 'deb ...' ...: Adds Kubernetes v1.30 repository.


Kubernetes Components:
sudo apt install -y kubelet=1.30.4-1.1 ...: Installs pinned Kubernetes tools.
sudo apt-mark hold ...: Locks versions to prevent upgrades.


Image Pre-pull:
sudo kubeadm config images pull ...: Downloads Kubernetes images in advance.



Troubleshooting

Package installation fails: Check internet access; retry sudo apt update.
Containerd issues: View logs with sudo journalctl -u containerd.
Sandbox image mismatch: Confirm pause:3.9 in /etc/containerd/config.toml using sudo crictl images | grep pause.

