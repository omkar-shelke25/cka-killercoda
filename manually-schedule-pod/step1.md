
# 🚀 **CKA: Manual Scheduling and Service Exposure**

### 🧠 **Context**

A developer has requested an **`nginx`** Pod to be deployed for internal testing in the **`japan`** namespace.
However, due to special scheduling policies, ⚙️ **Pods cannot be automatically scheduled** in this namespace.
You must therefore **manually assign the Pod to a specific node** and then **expose it to external traffic**.

---

### 🎯 **Your Task**

Create a Pod named **`tokoyo`** in the namespace **`japan`** using the **`public.ecr.aws/nginx/nginx:stable-perl`** image that listens on port **80**.

The Pod **must be manually scheduled** on the node **`controlplane`**, **without relying on the default Kubernetes scheduler**.

Then, expose this Pod using a **Service** of type  **`NodePort`** on port **80**, making it externally accessible via **nodePort `30099`**.

