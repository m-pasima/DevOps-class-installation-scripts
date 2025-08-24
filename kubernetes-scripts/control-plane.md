# Control Plane Setup for Kubernetes on Ubuntu EC2

This script sets up the **Kubernetes control plane** on an Ubuntu EC2 instance, configures **kubeconfig** for the `ubuntu` user, and installs **Calico (v3.30.2)** for networking. It also provides a **join command** for worker nodes.

---

## Prerequisites

* Complete **`common-setup.sh`** first (see `common-setup.md`)
* EC2 instance: `t3.medium` or better
* Security group allows **port 6443** (API server)
* Run as **root** or with **sudo**

---

## How to Use

1. **Save** this as `control-plane.sh`
2. **Make it executable:**

   ```bash
   chmod +x control-plane.sh
   ```
3. **Run on the control plane node with sudo:**

   ```bash
   sudo ./control-plane.sh
   ```
4. **Save the kubeadm join command** (printed at the end) for worker nodes
5. **Verify cluster as `ubuntu`:**

   ```bash
   kubectl get nodes
   ```

---

## If the Join Token Is Lost

Tokens expire after **24 hours**.
Generate a new one from the control plane as `ubuntu`:

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubeadm token create --print-join-command
```

This prints a fresh **kubeadm join** command for workers.

---

## Script copy & run)

```bash
#!/bin/bash

# Initialize control plane
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --kubernetes-version=1.30.4

# Configure kubeconfig for ubuntu user
mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
export KUBECONFIG=/home/ubuntu/.kube/config

# Install Calico networking (v3.30.2)
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml

# Allow pods on control plane (optional)
kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true

# Output join command for worker nodes
echo "Control plane initialized. Use this to join worker nodes:"
kubeadm token create --print-join-command
echo
echo "Verify cluster as ubuntu user: kubectl get nodes"
echo "If using root, run: export KUBECONFIG=/home/ubuntu/.kube/config"
echo "If token expires, regenerate with:"
echo "  export KUBECONFIG=/home/ubuntu/.kube/config"
echo "  kubeadm token create --print-join-command"
```

---

## What Each Command Does

* **Control Plane Initialization**
  `sudo kubeadm init ...` → bootstraps control plane with Kubernetes **v1.30.4** using Calico pod CIDR `192.168.0.0/16`

* **Kubeconfig Setup**

  * `mkdir -p /home/ubuntu/.kube` → make kube dir
  * `sudo cp -i /etc/kubernetes/admin.conf ...` → copy admin kubeconfig
  * `sudo chown ubuntu:ubuntu ...` → set ownership
  * `export KUBECONFIG=...` → enable `kubectl` in this session

* **Networking**
  `kubectl apply -f calico.yaml` → installs **Calico v3.30.2** networking

* **Untaint Control Plane (optional)**
  `kubectl taint nodes --all node-role.kubernetes.io/control-plane- || true` → allows scheduling pods on control plane node

* **Join Command**
  `kubeadm token create --print-join-command` → outputs worker join command

---

## Troubleshooting

* **kubectl errors**
  Check kubeconfig permissions:

  ```bash
  ls -l /home/ubuntu/.kube/config
  ```

  For root usage:

  ```bash
  export KUBECONFIG=/home/ubuntu/.kube/config
  ```

* **Calico issues**
  Verify pods:

  ```bash
  kubectl get pods -n kube-system -l k8s-app=calico-node
  ```

  Ensure pod CIDR = `192.168.0.0/16`

* **API server issues**

  * Kubelet logs: `sudo journalctl -u kubelet -f`
  * API logs: `kubectl logs kube-apiserver-<node> -n kube-system`

---

## Next Steps

* Save the `kubeadm join` command
* Proceed with **`worker-join.md`** for worker nodes
* Verify cluster health:

  ```bash
  kubectl get nodes
  kubectl get pods -n kube-system
  ```

---


