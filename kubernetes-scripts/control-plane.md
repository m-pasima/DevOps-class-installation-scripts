Kubernetes Control Plane Setup for Ubuntu EC2
This script initializes the Kubernetes control plane on an Ubuntu EC2 instance, sets up kubeconfig for the ubuntu user, and installs Calico (v3.30.2). It outputs a join command for worker nodes.
Prerequisites

Run common-setup.sh first (see common-setup.md).
EC2 instance meets control plane requirements (t3.medium or better).
Security groups allow port 6443 for API server access.
Run as root or with sudo.

Usage

Save this script as control-plane.sh in your repository.
Make it executable:chmod +x control-plane.sh


Run with sudo on the control plane node:sudo ./control-plane.sh


Save the kubeadm join command output for worker nodes.
Verify the cluster as the ubuntu user:kubectl get nodes



If You Lose the Join Token
The join token is valid for 24 hours. If lost or expired, generate a new one on the control plane as the ubuntu user:
export KUBECONFIG=/home/ubuntu/.kube/config
kubeadm token create --print-join-command

This outputs a new kubeadm join command (e.g., kubeadm join 172.31.35.209:6443 --token <new-token> --discovery-token-ca-cert-hash sha256:<hash>).
Script
#!/bin/bash

# Initialize control plane (use your pod CIDR; adjust for your network addon)
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.30.4

# Set up kubeconfig specifically for the ubuntu user (fixes connection refused for non-root user)
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config

# Export for current session (so kubectl works immediately in this script)
export KUBECONFIG=/home/ubuntu/.kube/config

# Install a pod network addon (updated to latest Calico v3.30.2)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml

# Untaint the control plane if you want to schedule pods on it (optional for single-node)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true  # Ignore if already untainted

# Generate join command
echo "Control plane initialized. Copy the 'kubeadm join' command below to join worker nodes:"
kubeadm token create --print-join-command

echo "To verify as ubuntu user: kubectl get nodes"
echo "If running as root, export KUBECONFIG=/home/ubuntu/.kube/config first."
echo "If join token is lost or expires, generate a new one with:"
echo "  export KUBECONFIG=/home/ubuntu/.kube/config"
echo "  kubeadm token create --print-join-command"

Command Explanations

Control Plane Initialization:
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.30.4: Initializes the control plane with Kubernetes v1.30.4 and Calico’s pod CIDR.


Kubeconfig Setup:
mkdir -p /home/ubuntu/.kube: Creates .kube directory for ubuntu user.
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config: Copies admin kubeconfig.
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config: Sets ownership for ubuntu user.
export KUBECONFIG=/home/ubuntu/.kube/config: Sets kubeconfig for the session.


Pod Network Addon:
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml: Deploys Calico v3.30.2.


Untaint Control Plane:
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true: Allows pods on the control plane (optional).


Join Command:
kubeadm token create --print-join-command: Outputs the worker join command.



Troubleshooting

kubectl connection refused: Check /home/ubuntu/.kube/config ownership (ls -l /home/ubuntu/.kube/config). Run export KUBECONFIG=/home/ubuntu/.kube/config if using root.
Calico issues: Verify pods with kubectl get pods -n kube-system -l k8s-app=calico-node. Ensure pod CIDR matches (192.168.0.0/16).
API server issues: Check logs with sudo journalctl -u kubelet or kubectl logs kube-apiserver-<node> -n kube-system.

Next Steps

Save the kubeadm join command.
Use worker-join.md to join worker nodes.
Verify with kubectl get nodes and kubectl get pods -n kube-system.
