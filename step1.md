# 📝 Task: Write Script to List Static Pods

## Your Mission

Create a shell script named **`list-static-pods.sh`** in the home directory (`/root/`) that lists all static pods running in the cluster.



## Cluster Information:

- **Nodes:** controlplane, node01

 
## Try it
<details>
  
<summary>✅ Complete Solution</summary>

#### Key Concept:

- Static pods have the node name as a **suffix** in their pod name. So you can identify them by grepping for the node names in the pod list!

- Example:
 ```
 httpd-web-controlplane  → static pod on controlplane node
 ai-apps-node01          → static pod on node01 node
 ``` 

✅ **Static Pod Name Format (Short Notes)**

* Static Pods follow the format:

  ```
  <pod-name>-<node-name>
  ```

  *(or `<pod-name>-<host-name>`, both same)*

* Added **automatically by kubelet** when it registers the static pod to the API server (as a mirror pod).

* Purpose → To make pod names **unique** across nodes, since each node runs its own static pods.

**Example:**

| Node         | Manifest Name  | Actual Pod Name             |
| ------------ | -------------- | --------------------------- |
| controlplane | kube-apiserver | kube-apiserver-controlplane |
| node01       | ai-apps        | ai-apps-node01              |


```bash
echo "kubectl get pods -A | grep -E 'controlplane|node01'" > /root/list-static-pods.sh
chmod +x /root/list-static-pods.sh
/root/list-static-pods.sh
```
</details>
