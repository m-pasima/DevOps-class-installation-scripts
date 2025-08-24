# Kubernetes Worker Node Join for Ubuntu EC2

This script joins an **Ubuntu EC2 worker node** to a Kubernetes cluster using the **kubeadm join command** provided by the control plane.

---

## Prerequisites

* Run **`common-setup.sh`** first (see `common-setup.md`)
* EC2 instance: `t3.small` or better
* Security group allows required ports (see `common-setup.md`)
* Use the **kubeadm join command** output from the control plane
* Run as **root** or with **sudo**

---

## Usage

1. **Save** this as `worker-join.sh`
2. **Make it executable:**

   ```bash
   chmod +x worker-join.sh
   ```
3. **Run on each worker node with sudo:**

   ```bash
   sudo ./worker-join.sh
   ```
4. On the control plane, verify:

   ```bash
   kubectl get nodes
   ```

---

## If You Lose the Join Token

Tokens are valid for **24 hours**.
If lost/expired, generate a new one on the control plane (as `ubuntu`):

```bash
export KUBECONFIG=/home/ubuntu/.kube/config
kubeadm token create --print-join-command
```

Update the script with the **new join command** and re-run.

---

## Script (copy & run)

```bash
#!/bin/bash

# Join command from control plane output
sudo kubeadm join 172.31.35.209:6443 --token lj7jhn.o1tlmctqusmjbzcz --discovery-token-ca-cert-hash sha256:36f49f09fe31f75a24e475cdbf16faf204faeda04015945401116ce66ba081cd

echo "Worker node joined. On control plane (as ubuntu), run 'kubectl get nodes' to verify."
echo "If token expires, generate a new one on control plane with:"
echo "  export KUBECONFIG=/home/ubuntu/.kube/config"
echo "  kubeadm token create --print-join-command"
```

---

## Command Explanation

* **Join Cluster**

  ```bash
  sudo kubeadm join 172.31.35.209:6443 \
    --token lj7jhn.o1tlmctqusmjbzcz \
    --discovery-token-ca-cert-hash sha256:36f49f09fe31f75a24e475cdbf16faf204faeda04015945401116ce66ba081cd
  ```

  Joins the worker node to the control plane at `172.31.35.209:6443`, using the token and CA cert hash.

---

## Troubleshooting

* **Join command fails**

  * Verify token & CA cert hash
  * If expired, regenerate token (see above)
  * Ensure network connectivity to control plane `172.31.35.209:6443`

* **Node not appearing**

  * On control plane: `kubectl get nodes`
  * Worker logs: `sudo journalctl -u kubelet -f`

* **Calico issues**

  * Ensure pod CIDR (`192.168.0.0/16`) matches control plane
  * Verify pods:

    ```bash
    kubectl get pods -n kube-system -l k8s-app=calico-node
    ```

---

## Next Steps

* Run this on **all worker nodes**
* Verify cluster status on the control plane:

  ```bash
  kubectl get nodes
  kubectl get pods -n kube-system
  ```
* Monitor Calico pods for readiness

---

That’s your **full trilogy** now:
✅ `common-setup.sh` → base setup
✅ `control-plane.sh` → init + networking
✅ `worker-join.sh` → join workers



