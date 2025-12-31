# 🔧 **CKA: Create DaemonSet with Resource Requests**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - DaemonSet](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)

### 🏢 **Context**

The operations team needs to deploy a monitoring agent across all nodes in the cluster, including control plane nodes. This agent must run as a DaemonSet to ensure every node has exactly one instance running.

---

### 🎯 **Your Task**

Create a DaemonSet in the `project-tiger` namespace with the following specifications:

**DaemonSet Requirements:**
* Name: `ds-important`
* Namespace: `project-tiger`
* Image: `httpd:2-alpine`
* Labels (on DaemonSet and Pods):
  * `id=ds-important`
  * `uuid=18426a0b-5f59-4e10-923f-c0e078e82462`

**Resource Requirements:**
* CPU request: `10m` (10 millicore)
* Memory request: `10Mi` (10 mebibyte)

**Scheduling Requirements:**
* Pods must run on **ALL nodes** including control plane nodes
* Add appropriate tolerations to schedule on control plane nodes

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Create the namespace**

```bash
kubectl create namespace project-tiger
```

**Step 2: Generate base DaemonSet YAML**

Start by generating a Deployment manifest and convert it to DaemonSet:

```bash
kubectl create deployment ds-important --image=httpd:2-alpine --namespace=project-tiger --dry-run=client -o yaml > ds-important.yaml
```

**Step 3: Edit the YAML file**

Edit the file to convert from Deployment to DaemonSet:

```bash
vi ds-important.yaml
```

**Step 4: Complete DaemonSet manifest**

The final manifest should look like this:

```yaml
apiVersion: apps/v1
kind: DaemonSet                                     # change from Deployment to DaemonSet
metadata:
  creationTimestamp: null
  labels:                                           # add
    id: ds-important                                # add
    uuid: 18426a0b-5f59-4e10-923f-c0e078e82462      # add
  name: ds-important
  namespace: project-tiger                          # important
spec:
  #replicas: 1                                      # remove (DaemonSets don't use replicas)
  selector:
    matchLabels:
      id: ds-important                              # add
      uuid: 18426a0b-5f59-4e10-923f-c0e078e82462    # add
  #strategy: {}                                     # remove (DaemonSets use updateStrategy)
  template:
    metadata:
      creationTimestamp: null
      labels:
        id: ds-important                            # add
        uuid: 18426a0b-5f59-4e10-923f-c0e078e82462  # add
    spec:
      containers:
      - image: httpd:2-alpine
        name: ds-important
        resources:
          requests:                                 # add
            cpu: 10m                                # add
            memory: 10Mi                            # add
      tolerations:                                  # add
      - effect: NoSchedule                          # add
        key: node-role.kubernetes.io/control-plane  # add
#status: {}
```

**Key Changes Explained:**

1. **kind**: Changed from `Deployment` to `DaemonSet`
2. **labels**: Added required labels to metadata, selector, and template
3. **replicas**: Removed (DaemonSets automatically run one Pod per node)
4. **strategy**: Removed (DaemonSets use `updateStrategy` instead)
5. **resources.requests**: Added CPU (10m) and memory (10Mi) requests
6. **tolerations**: Added to allow scheduling on control plane nodes

**Step 5: Apply the DaemonSet**

```bash
kubectl apply -f ds-important.yaml
```

**Step 6: Verify the DaemonSet**

Check DaemonSet status:
```bash
kubectl get daemonset -n project-tiger
```

Check Pods are running on all nodes:
```bash
kubectl get pods -n project-tiger -o wide
```

Verify Pods are running on control plane:
```bash
kubectl get pods -n project-tiger -o wide | grep controlplane
```

Check resource requests:
```bash
kubectl describe daemonset ds-important -n project-tiger | grep -A 5 "Requests"
```

Verify labels:
```bash
kubectl get daemonset ds-important -n project-tiger --show-labels
```

**Step 7: Validate tolerations**

```bash
kubectl get daemonset ds-important -n project-tiger -o jsonpath='{.spec.template.spec.tolerations}' | jq
```

Expected output should show the control plane toleration.

</details>

---
