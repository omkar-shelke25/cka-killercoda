## 🧠 Configure HorizontalPodAutoscaler (HPA) for ISRO-JAXA Deployment

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Horizontal Pod Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

The ISRO–JAXA Lunar Communication Service is running a Deployment named `isro-jaxa-collab-deployment` inside the `isro-jaxa` namespace.This service is receiving continuous telemetry traffic from the lunar rover `lunar-robot-01`, causing fluctuating load on the application.

### 🛠️ Your tasks:

1. To ensure the application `isro-jaxa-collab-deployment` can automatically scale based on CPU load, create an HPA for the Deployment with:
   * 🎯 Target CPU utilization: `50%`
   * 🔽 Minimum replicas: `1`
   * 🔼 Maximum replicas: `5`

2. 🔍 Verify:
   * 📊 The HPA status
   * 🧩 The Deployment's replica count after the HPA is created

3. 🧮 Operations requires a quick resource audit: Using `top` command, calculate the total (sum) CPU and memory usage of all Pods in the `isro-jaxa` namespace and save the result to:
   `/isro-jaxa/space-details.txt`


**Note:** Wait 15-30 seconds after creating the HPA to allow metrics-server to collect data before performing the audit.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Task 1: Create HorizontalPodAutoscaler**

Create the HPA using kubectl:
```bash
kubectl autoscale deployment isro-jaxa-collab-deployment \
  --namespace isro-jaxa \
  --cpu=50% \
  --min=1 \
  --max=5
```

Alternatively, you can create an HPA using a YAML file:
```bash
cat > /tmp/hpa.yaml <<'EOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: isro-jaxa-collab-deployment
  namespace: isro-jaxa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: isro-jaxa-collab-deployment
  minReplicas: 1
  maxReplicas: 5
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
EOF

kubectl apply -f /tmp/hpa.yaml
```

**Task 2: Verify HPA**

Check HPA status:
```bash
kubectl get hpa -n isro-jaxa
```

Watch HPA in real-time:
```bash
kubectl get hpa -n isro-jaxa -w
```

Check detailed HPA information:
```bash
kubectl describe hpa isro-jaxa-collab-deployment -n isro-jaxa
```

Check Deployment replica count:
```bash
kubectl get deployment isro-jaxa-collab-deployment -n isro-jaxa
```

View Pods:
```bash
kubectl get pods -n isro-jaxa
```

View current resource usage:
```bash
kubectl top pods -n isro-jaxa
```

Calculate totals using the --sum flag and save to file:

```bash
# Get pod metrics sum
kubectl top pods -n isro-jaxa --sum=true > /isro-jaxa/space-details.txt
```

Verify the file:
```bash
cat /isro-jaxa/space-details.txt
```

</details>
