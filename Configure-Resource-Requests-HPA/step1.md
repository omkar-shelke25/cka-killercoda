# 🧠 **CKA: Configure Resource Requests and Limits for Deployment using HPA**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Managing Resources for Containers](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)

### 🏢 **Context**

You are working on a production deployment for the Jujutsu High platform. A Deployment named **tokyo-jutsu** in the **jujutsu-high** namespace is running without any CPU or memory resource settings. 

An HPA named **gojo-hpa** targets this Deployment and defines absolute CPU and memory values in millicores (m) and Mebibytes (Mi) instead of percentage-based metrics. 

Because the Deployment has no resource requests, the HPA cannot calculate utilization and remains in an Unknown state, preventing it from scaling the Pods appropriately.

The Deployment manifest is already stored at:
```bash
/Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml
```

### ❓ **Question**

Edit the Deployment manifest to configure proper resource requests and limits for the container so that the HPA can calculate utilization metrics correctly. 

The HPA is configured to monitor CPU at 512m and memory at 512Mi as average values. 

You must set the resource limits to match these values exactly, and set the resource requests to exactly half of those limits. 

Once you have edited the manifest, apply it to update the Deployment. You must not modify the HPA itself.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

First, check the current HPA status to see it's in Unknown state:
```bash
kubectl get hpa -n jujutsu-high
```

You should see output showing `<unknown>` for current metrics.

Check the existing Deployment manifest:
```bash
cat "/Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml"
```

Edit the Deployment manifest:
```bash
vi "/Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml"
```

Add the resources section under the container specification. Based on the HPA configuration (512m CPU and 512Mi memory), set limits to these values and requests to exactly half:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tokyo-jutsu
  namespace: jujutsu-high
  labels:
    environment: production
spec:
  replicas: 1
  selector:
    matchLabels:
      app: tokyo-jutsu
      environment: production
  template:
    metadata:
      labels:
        app: tokyo-jutsu
        environment: production
    spec:
      containers:
        - name: app
          image: nginx
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: 256m
              memory: 256Mi
            limits:
              cpu: 512m
              memory: 512Mi
```

Apply the updated Deployment:
```bash
kubectl apply -f "/Jujutsu Kaisen/jujutsu-kaisen-deployment.yaml"
```

Wait for the rollout to complete:
```bash
kubectl rollout status deployment/tokyo-jutsu -n jujutsu-high
```

Verify the Pod has the correct resource configuration:
```bash
kubectl get pod -n jujutsu-high -l app=tokyo-jutsu -o jsonpath='{.items[0].spec.containers[0].resources}' | jq
```

Check the HPA status again after a few moments:
```bash
kubectl get hpa -n jujutsu-high
```

The HPA should now show actual metric values instead of `<unknown>`.

You can also describe the HPA to see more details:
```bash
kubectl describe hpa gojo-hpa -n jujutsu-high
```

Expected result: The HPA metrics should now display actual CPU and memory values, enabling the HPA to scale the Deployment based on resource utilizat
