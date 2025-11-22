# 🧠 **CKA: AlwaysDeny Authorization Mode Configuration**

📚 **Official Kubernetes Documentation**: 
- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [Authorization Modes](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#authorization-modules)
- [kube-apiserver Configuration](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)

### 🔧 **Context**

You are working 🧑‍💻 with a trainee Kubernetes engineer who is learning about authorization mechanisms in a lab cluster. 

To demonstrate how authorization modes are evaluated, they want to temporarily force the API server to **deny all API requests**.

**Task:**

On the control-plane node, modify the kube-apiserver static pod manifest to enable the `AlwaysDeny` authorization mode **as the first entry** in the `--authorization-mode` flag so that all API requests are rejected.

Requirements:

1. Add `AlwaysDeny` at the beginning of the `--authorization-mode` list (e.g., `AlwaysDeny,RBAC,...`).
2. Do **not** remove any existing authorization modes.
3. Save the file and allow the kubelet to automatically restart the kube-apiserver.
4. Verify that `kubectl get pods` now fails with a *Forbidden* error.
5. **Document** the error message in `/root/auth-debug/forbidden-error.txt`

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

### **1️⃣ Edit the kube-apiserver manifest**

Open:

```
/etc/kubernetes/manifests/kube-apiserver.yaml
```

---

### **2️⃣ Find the existing authorization-mode line**

Example:

```
- --authorization-mode=RBAC,Node
```

(Note: the current modes may differ; do not delete them.)

---

### **3️⃣ Prepend `AlwaysDeny` to the list**

Modify it to:

```
- --authorization-mode=AlwaysDeny,RBAC,Node
```

(Only add `AlwaysDeny` at the beginning.)

---

### **4️⃣ Save the file**

The kubelet automatically restarts the API server.

---

### **5️⃣ Verify it works**

Run any kubectl command:

```
kubectl get pods
```

You should see a **Forbidden** or **Unauthorized** error, confirming that **all API requests are denied**, regardless of user identity, credentials, or RBAC rules.




</details>

