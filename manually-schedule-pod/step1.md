
# 🚀 **CKA: Manual Scheduling and Service Exposure**

### 🧠 **Context**

A developer has requested an **`nginx`** Pod to be deployed for internal testing in the **`japan`** namespace.
However, due to special scheduling policies, ⚙️ **Pods cannot be automatically scheduled** in this namespace.
You must therefore **manually assign the Pod to a specific node** and then **expose it to external traffic**.

---

### 🎯 **Your Task**

Create a Pod named **`tokoyo`** in the namespace **`japan`** using the **`public.ecr.aws/nginx/nginx:stable-perl`** image that listens on port **80**.

The Pod **must be manually scheduled** on the node **`controlplane`**, **without relying on the default Kubernetes scheduler**.

Then, expose this Pod using a **Service** of type  **`NodePort`** on port **`80`**, making it externally accessible via **nodePort `30099`**.


### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

##### 🧩 **Step 1: Generate the Pod manifest (dry-run)**



```bash
kubectl run tokoyo --image=public.ecr.aws/nginx/nginx:stable-perl --port=80 -n japan --dry-run=client -o yaml > tokoyo.yaml
```

---

##### 🧾 **Step 2: Edit the YAML to schedule manually on `controlplane`**

Open the file:

```bash
vi tokoyo.yaml
```

Then modify it to include `nodeName: controlplane` under `spec:` 👇

Manual Scheduling means you explicitly choose the node where a Pod runs by specifying the nodeName field — thereby bypassing the Kubernetes scheduler’s automatic placement process.

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    run: tokoyo
  name: tokoyo
  namespace: japan
spec:
  nodeName: controlplane   # 👈 Manual scheduling (bypasses scheduler)
  containers:
  - name: tokoyo
    image: public.ecr.aws/nginx/nginx:stable-perl
    ports:
    - containerPort: 80
  dnsPolicy: ClusterFirst
  restartPolicy: Always
```

---

##### ⚙️ **Step 3: Apply the Pod**

```bash
kubectl apply -f tokoyo.yaml
```

Verify it’s running on the controlplane:

```bash
kubectl get pod tokoyo -n japan -o wide
```

✅ Expected:

```
NAME      READY   STATUS    NODE           PORT
tokoyo    1/1     Running   controlplane   80
```

---

##### 🌐 **Step 4: Expose the Pod using a NodePort Service**

```bash
kubectl expose pod tokoyo -n japan --type=NodePort --port=80 --name=tokoyo --dry-run=client -o yaml > tokoyo-svc.yaml
```

Then edit `tokoyo-svc.yaml` to set the `nodePort` explicitly to `30099` 👇

```yaml
apiVersion: v1
kind: Service
metadata:
  name: tokoyo
  namespace: japan
spec:
  type: NodePort
  selector:
    run: tokoyo
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30099
```

---

##### 🚀 **Step 5: Apply the Service**

```bash
kubectl apply -f tokoyo-svc.yaml
```

Verify:

```bash
kubectl get svc -n japan
```

✅ Expected output:

```bash
NAME      TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
tokoyo    NodePort   10.96.23.45    <none>        80:30099/TCP   5s
```

---

##### ✅ **Final Verification**

Access the app from your browser or via `curl`:

```bash
curl http://localhost:30099
```
</details>
