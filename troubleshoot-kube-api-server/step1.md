# 🧠 **CKA: Troubleshoot kube-apiserver Static Pod CPU Resources**

📚 **Official Kubernetes Documentation**: 
- [Static Pods](https://kubernetes.io/docs/tasks/configure-pod-container/static-pod/)
- [Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [Configure Quality of Service for Pods](https://kubernetes.io/docs/tasks/configure-pod-container/quality-service-pod/)


You are troubleshooting a cluster where the control plane is not healthy. On the node controlplane, the kube-apiserver process keeps failing to start.

Upon investigation, you discover that the static Pod manifest located under `/etc/kubernetes/manifests/kube-apiserver.yaml` contains incorrect CPU requests and limits, which exceed the node's total capacity. 

As a result, the kubelet refuses to run the Pod.

Your task is to correct the manifest so that the kube-apiserver uses 20% of the node’s total CPU for both `requests` and `limits`.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the node's CPU capacity**

```bash
kubectl describe node controlplane | grep -i capacity -A 5
```

You should see `cpu: 1` or `1000m` total capacity.

**Step 2: Check the current kube-apiserver status**

```bash
# Check if the Pod exists in kube-system namespace
kubectl get pods -n kube-system | grep apiserver

# Check container runtime for failed attempts
crictl ps -a | grep apiserver

# Check kubelet logs for errors
journalctl -u kubelet -n 50 --no-pager | grep -i "insufficient cpu"
```

You should see errors indicating insufficient CPU.

**Step 3: Examine the current manifest**

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 10 resources
```

You'll see the incorrect CPU request and limit of 4000m in both places:
```yaml
    resources:
      requests:
        cpu: 4000m
```

**Step 4: Calculate the correct CPU value**

Node total CPU: 1000m  
20% of 1000m = 200m


**Method: Manual editing with complete YAML structure**

```bash
sudo vi /etc/kubernetes/manifests/kube-apiserver.yaml
```

Find the resources section and update it to match this structure:

**BEFORE (Incorrect - 4000m exceeds node capacity):**
```yaml
spec:
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.28.0
    resources:
      requests:
        cpu: 4000m
      limits:
        cpu: 4000m
```

**AFTER (Correct - 200m is 20% of 1000m node capacity):**
```yaml
spec:
  containers:
  - name: kube-apiserver
    image: registry.k8s.io/kube-apiserver:v1.28.0
    resources:
      requests:
        cpu: 200m
      limits:
        cpu: 200m
```

**Complete resources section should look like:**
```yaml
    resources:
      requests:
        cpu: 200m
      limits:
        cpu: 200m
```

**Step 6: Verify the change**

```bash
cat /etc/kubernetes/manifests/kube-apiserver.yaml | grep -A 10 resources
```

You should now see:
```yaml
    resources:
      requests:
        cpu: 200m
      limits:
        cpu: 200m
```

**Step 7: Wait for kubelet to recreate the Pod**

The kubelet watches the `/etc/kubernetes/manifests/` directory and will automatically recreate the Pod.

```bash
# Watch for the Pod to come up
watch kubectl get pods -n kube-system -l component=kube-apiserver
```

Or check periodically:
```bash
kubectl get pods -n kube-system | grep apiserver
```

**Step 8: Verify the kube-apiserver is running**

```bash
# Check Pod status
kubectl get pods -n kube-system -l component=kube-apiserver

# Check container runtime
crictl ps | grep apiserver

# Verify cluster components are healthy
kubectl get cs
kubectl get nodes
```



</details>
