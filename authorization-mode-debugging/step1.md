# 🧠 **CKA: AlwaysDeny Authorization Mode Configuration**

📚 **Official Kubernetes Documentation**: 
- [Authorization Overview](https://kubernetes.io/docs/reference/access-authn-authz/authorization/)
- [Authorization Modes](https://kubernetes.io/docs/reference/access-authn-authz/authorization/#authorization-modules)
- [kube-apiserver Configuration](https://kubernetes.io/docs/reference/command-line-tools-reference/kube-apiserver/)
- [Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)

### 🔧 **Context**

You are working 🧑‍💻 with a trainee Kubernetes engineer who is learning about authorization mechanisms in a lab cluster.

To demonstrate how authorization modes are evaluated, they want to temporarily force the API server to deny all API requests.

### **Task:**

On the control-plane node, modify the `kube-apiserver` static pod manifest so that the `--authorization-mode` flag includes **`AlwaysDeny`** immediately after **`Node`**, and remove the **`RBAC`** mode from the list.

Use `crictl ps` to verify which static pods were restarted.

Verify that `kubectl get pods` now fails with a **Forbidden** error.

Record the resulting error message in:

```
/root/auth-debug/forbidden-error.txt
```

Use stderr redirection so the error gets saved in `/root/auth-debug/forbidden-error.txt`.


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
- --authorization-mode=Node,RBAC
```


---

### **3️⃣ Add `AlwaysDeny` after NODE and remove RBAC from  the list**

Modify it to:

```
- --authorization-mode=Node,AlwaysDeny
```

---

### **4️⃣ Save the file**

The kubelet automatically restarts the API server.

---

### **5️⃣ Verify it works**

Run any kubectl command:

```
kubectl get pods 2> /root/auth-debug/forbidden-error.txt
```

You should see a **Forbidden** or **Unauthorized** error, confirming that **all API requests are denied**, regardless of user identity, credentials, or RBAC rules.


</details>

