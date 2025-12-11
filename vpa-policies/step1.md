# 🧠 **CKA: Configure Vertical Pod Autoscaler**

📚 **Official Kubernetes Documentation**: 
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [VPA API Reference](https://github.com/kubernetes/autoscaler/blob/master/vertical-pod-autoscaler/pkg/apis/autoscaling.k8s.io/v1/types.go)
- [Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

### 🎯 **Context**

You are managing a Kubernetes cluster where application workloads have varying resource requirements over time. A deployment named `app-deployment` exists in the `vpa-demo` namespace with a container named `application`. Currently, the resources are manually configured, but you need to implement automatic resource optimization using Vertical Pod Autoscaler (VPA).

The VPA should monitor actual resource usage and automatically adjust both CPU and memory requests and limits, while ensuring they stay within safe operational boundaries.

### ❓ **Task**

Create a **VerticalPodAutoscaler** resource named `app-vpa` in the `vpa-demo` namespace that manages the `app-deployment` deployment.

**Requirements:**

1. **Target the deployment**: `app-deployment` in namespace `vpa-demo`

2. **Update mode**: Set to `Recreate`

3. **Resource policy** for the container named `application`:
   - Update both **CPU and memory** requests **AND** limits
   - **Minimum bounds**:
     - CPU: `100m`
     - Memory: `128Mi`
   - **Maximum bounds**:
     - CPU: `2` (2 cores)
     - Memory: `2Gi`

4. The VPA should control both `RequestsAndLimits` for the container

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the existing deployment**

```bash
kubectl get deployment -n vpa-demo
kubectl describe deployment app-deployment -n vpa-demo
```

Check current resource configuration:
```bash
kubectl get deployment app-deployment -n vpa-demo -o yaml | grep -A 10 resources
```

**Step 2: Verify VPA components are installed**

```bash
kubectl get pods -n kube-system | grep vpa
```

You should see:
- vpa-admission-controller
- vpa-recommender
- vpa-updater

**Step 3: Create the VerticalPodAutoscaler manifest**

Create a file named `app-vpa.yaml`:

```bash
cat > app-vpa.yaml <<EOF
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa
  namespace: vpa-demo
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  updatePolicy:
    updateMode: Recreate
  resourcePolicy:
    containerPolicies:
    - containerName: application
      controlledResources:
      - cpu
      - memory
      controlledValues: RequestsAndLimits
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 2Gi
EOF
```

**Understanding the configuration:**

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: app-vpa                    # VPA resource name
  namespace: vpa-demo              # Same namespace as target deployment
spec:
  targetRef:                       # Target deployment
    apiVersion: apps/v1
    kind: Deployment
    name: app-deployment
  updatePolicy:
    updateMode: Recreate           # Recreate pods to apply recommendations
  resourcePolicy:
    containerPolicies:             # Policies for specific containers
    - containerName: application   # Target container name
      controlledResources:         # Resources to manage
      - cpu
      - memory
      controlledValues: RequestsAndLimits  # Update both requests and limits
      minAllowed:                  # Minimum resource bounds
        cpu: 100m
        memory: 128Mi
      maxAllowed:                  # Maximum resource bounds
        cpu: 2
        memory: 2Gi
```

**Step 4: Apply the VPA configuration**

```bash
kubectl apply -f app-vpa.yaml
```

**Step 5: Verify the VPA was created**

```bash
kubectl get vpa -n vpa-demo
```

Check VPA details:
```bash
kubectl describe vpa app-vpa -n vpa-demo
```

**Step 6: View VPA recommendations**

After a few moments, the VPA will start providing recommendations:

```bash
kubectl get vpa app-vpa -n vpa-demo -o yaml
```

Look for the `status` section with recommendations:
```bash
kubectl get vpa app-vpa -n vpa-demo -o jsonpath='{.status.recommendation}' | jq '.'
```

**Step 7: Monitor the VPA behavior**

Watch for pod recreation (if recommendations differ from current values):
```bash
kubectl get pods -n vpa-demo -w
```

Check updated resource requests and limits:
```bash
kubectl get deployment app-deployment -n vpa-demo -o yaml | grep -A 10 resources
```

**Step 8: Verify the VPA configuration**

```bash
# Check update mode
kubectl get vpa app-vpa -n vpa-demo -o jsonpath='{.spec.updatePolicy.updateMode}'

# Check resource policy
kubectl get vpa app-vpa -n vpa-demo -o jsonpath='{.spec.resourcePolicy.containerPolicies[0]}' | jq '.'
```

</details>
