# 🧠 **CKA: Horizontal Pod Autoscaler Configuration**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

### 🏢 **Context**

You are working 🧑‍💻 on an **IoT Sensor API Platform** that experiences variable traffic patterns throughout the day. The platform needs to scale automatically based on resource utilization to maintain performance while optimizing costs.

A Deployment named **`sensor-api`** is already running in the **`iot-sys`** namespace with **`12` replicas**. The metrics-server has been installed and configured for you.

### ❓ **Question**

A Deployment named **`sensor-api`** is running in the **`iot-sys`** namespace. 

You must configure autoscaling for this Deployment by creating an HPA called **`sensor-hpa`** that can scale between **`2` and `8` replicas**. 

The HPA should use **both CPU and memory utilization**, with each metric targeting **`80%` utilization**. 

Reduce the Deployment replicas from `12 to 2` because `12` pods are running unnecessarily without traffic, and add `stabilizationWindowSeconds: 5` in the HPA so it waits at least `5 seconds` before scaling down.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

Create the HPA YAML file:
```bash
vi /iot-platform/sensor-hpa.yaml
```

Add the following configuration:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: sensor-hpa
  namespace: iot-sys
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: sensor-api
  minReplicas: 2
  maxReplicas: 8
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 80
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 5
```

Apply the HPA:
```bash
kubectl apply -f /iot-platform/sensor-hpa.yaml
```

Verify the HPA creation:
```bash
kubectl get hpa sensor-hpa -n iot-sys
```

Check detailed HPA status:
```bash
kubectl describe hpa sensor-hpa -n iot-sys
```

Monitor the HPA behavior (you should see it scale down to 2 replicas):
```bash
watch -n 2 kubectl get hpa,deployment -n iot-sys
```

You can also check the current metrics:
```bash
kubectl top pods -n iot-sys
```

Expected result: The HPA should be created and will scale the deployment down from 15 to 2 replicas since there's minimal load on the pods.

</details>

