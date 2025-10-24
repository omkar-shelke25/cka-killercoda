# 📝 CKA: Write Script to List Static Pods

💼 **Your Mission**

You are working as a **DevOps Engineer** in an AI company that runs multiple Kubernetes clusters. Your manager asks you to write a shell script that lists all static pods running on both the **control plane node** and the **worker nodes**.

📝 Create a shell script named **`list-static-pods.sh`** in the home directory (`/root/`) that lists all static pods running in the cluster.

---

🧾 **Expected Output Format by Manager**

The output of your script should list all static pods in the following format:

```bash
static-ns    static-pod   Running   0    12s
static-ns-1  static-pod2  Running   0    30m
```

💡 **Schema of the above format:** `namespace, pod name, pod status, restarts, age`.


## Try it yourself first!

<details> 
 
<summary>✅ Complete Solution</summary>

🔑 **Key Concept**

* 🧩 Static pods have the node name as a **suffix** in their pod name. So you can identify them by grepping for the node names in the pod list!

* 💡 **Example:**

  ```
  httpd-web-controlplane  → static pod on controlplane node
  ai-apps-node01          → static pod on node01 node
  ```

---

✅ **Static Pod Name Format**

* 📘 Static Pods follow the format:

  ```
  <pod-name>-<node-name>
  ```

  *(or `<pod-name>-<host-name>`, both are the same)*

* ⚙️ Added **automatically by kubelet** when it registers the static pod to the API server (as a mirror pod).

* 🎯 **Purpose** → To make pod names **unique** across nodes, since each node runs its own static pods.

---

📊 **Example Table**

| 🖥️ Node     | 📄 Manifest Name | 🚀 Actual Pod Name          |
| ------------ | ---------------- | --------------------------- |
| controlplane | kube-apiserver   | kube-apiserver-controlplane |
| node01       | ai-apps          | ai-apps-node01              |

---

💻 **Example Solution**

```bash
# Solution
echo "kubectl get pods -A | grep -E 'controlplane|node01'" > /root/list-static-pods.sh
chmod +x /root/list-static-pods.sh
/root/list-static-pods.sh
```

</details>
