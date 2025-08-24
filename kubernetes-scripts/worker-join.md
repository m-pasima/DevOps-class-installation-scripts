Kubernetes Worker Node Join for Ubuntu EC2
This script joins an Ubuntu EC2 worker node to a Kubernetes cluster using the kubeadm join command from your control plane output.
Prerequisites

Run common-setup.sh first (see common-setup.md).
EC2 instance meets worker node requirements (t3.small or better).
Security groups allow necessary ports (see common-setup.md).
Use the kubeadm join command from the control plane output.
Run as root or with sudo.

Usage

Save this script as worker-join.sh in your repository.
Make it executable:chmod +x worker-join.sh


Run with sudo on each worker node:sudo ./worker-join.sh


On the control plane, verify with:kubectl get nodes



If You Lose the Join Token
The join token is valid for 24 hours. If lost or expired, generate a new one on the control plane as the ubuntu user:
export KUBECONFIG=/home/ubuntu/.kube/config
kubeadm token create --print-join-command

This outputs a new kubeadm join command. Update the script with the new command and re-run.
Script
#!/bin/bash

# Join command from control plane output
sudo kubeadm join 172.31.35.209:6443 --token lj7jhn.o1tlmctqusmjbzcz --discovery-token-ca-cert-hash sha256:36f49f09fe31f75a24e475cdbf16faf204faeda04015945401116ce66ba081cd

echo "Worker node joined. On control plane (as ubuntu), run 'kubectl get nodes' to verify."
echo "If token expires, generate a new one on control plane with:"
echo "  export KUBECONFIG=/home/ubuntu/.kube/config"
echo "  kubeadm token create --print-join-command"

Command Explanations

Join Cluster:
sudo kubeadm join 172.31.35.209:6443 --token lj7jhn.o1tlmctqusmjbzcz --discovery-token-ca-cert-hash sha256:36f49f09fe31f75a24e475cdbf16faf204faeda04015945401116ce66ba081cd: Joins the worker node to the cluster at the control plane’s IP and port, using the provided token and CA cert hash.



Troubleshooting

Join command fails: Verify token and CA cert hash. If expired, generate a new token (see above). Check network connectivity to 172.31.35.209:6443.
Node not appearing: On control plane, run kubectl get nodes. Check worker logs with sudo journalctl -u kubelet.
Calico issues: Ensure pod CIDR (192.168.0.0/16) matches control plane. Check pods with kubectl get pods -n kube-system -l k8s-app=calico-node.

Next Steps

Join all worker nodes.
Verify cluster status on control plane:kubectl get nodes
kubectl get pods -n kube-system


Monitor Calico pods for readiness.
