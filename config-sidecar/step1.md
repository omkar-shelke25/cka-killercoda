# 🔧 **CKA: Configure Pod with Sidecar Container**

📚 **Official Kubernetes Documentation**: 
- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Multi-container Pods](https://kubernetes.io/docs/tasks/access-application-cluster/communicate-containers-same-pod-shared-volume/)
- [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

### 🏢 **Context**

You are the platform engineer responsible for implementing centralized logging for your organization's applications. The web application team has deployed `web-app` in the `production` namespace, and it generates logs to `/var/log/app/app.log`.

Your task is to add a Fluentd sidecar container that will collect and forward these logs to your centralized logging infrastructure. The sidecar pattern allows you to add logging functionality without modifying the application code.

An existing Deployment named `web-app` is running in the namespace `production`.

### ❓ **Problem Statement**

**Task:** Update the existing Deployment to add a sidecar container that follows the Fluentd sidecar logging pattern.

**Requirements:**
* Do not modify the existing application container
* Add a new sidecar container named `log-agent`
* The sidecar container must use the image: `fluentd:latest`
* The sidecar container must continuously read application logs from: `/var/log/app/app.log`
* Logs must be shared using a volume mounted at `/var/log/app`
* The shared volume must be mounted in both containers
* The sidecar container must remain running
* Containers must be co-located in the same Pod
* Do not create new Pods or Deployments
* Do not change existing labels, selectors, or replica counts


### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: View current deployment**

```bash
kubectl get deployment web-app -n production -o yaml
```

Look at the current pod template to understand the structure.

**Step 2: Export deployment to a file**

```bash
kubectl get deployment web-app -n production -o yaml > web-app-deployment.yaml
```

**Step 3: Edit the deployment file**

Open the file and locate the `spec.template.spec` section. You need to add the sidecar container.

**Before (current state):**
```yaml
spec:
  template:
    spec:
      containers:
      - name: application
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "..."]
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      volumes:
      - name: log-volume
        emptyDir: {}
```

**After (with sidecar):**
```yaml
spec:
  template:
    spec:
      containers:
      - name: application
        image: busybox:latest
        command: ["/bin/sh"]
        args: ["-c", "..."]
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      - name: log-agent                    # ← New sidecar container
        image: fluentd:latest
        volumeMounts:
        - name: log-volume                 # ← Same volume as application
          mountPath: /var/log/app
      volumes:
      - name: log-volume
        emptyDir: {}
```

**Alternative Method: Edit directly**

```bash
kubectl edit deployment web-app -n production
```

Then add the sidecar container section as shown above.

**Alternative Method: Using kubectl patch**

This is more complex but useful for automation:

```bash
kubectl patch deployment web-app -n production --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/-",
    "value": {
      "name": "log-agent",
      "image": "fluentd:latest",
      "volumeMounts": [
        {
          "name": "log-volume",
          "mountPath": "/var/log/app"
        }
      ]
    }
  }
]'
```

**Step 4: Apply the changes**

If you edited the file:
```bash
kubectl apply -f web-app-deployment.yaml
```

**Step 5: Monitor the rollout**

```bash
kubectl rollout status deployment/web-app -n production
```

Wait for the message: `deployment "web-app" successfully rolled out`

**Step 6: Verify the deployment**

Check that new pods are running with 2 containers:

```bash
kubectl get pods -n production
```

You should see: `READY 2/2` for each pod.

**Step 7: Verify both containers exist**

Get a pod name:
```bash
POD=$(kubectl get pod -n production -l app=web-app -o jsonpath='{.items[0].metadata.name}')
echo "Testing pod: $POD"
```

Check container names:
```bash
kubectl get pod $POD -n production -o jsonpath='{.spec.containers[*].name}'
```

Should show: `application log-agent`

**Step 8: Test the shared volume**

Check application is writing logs:
```bash
kubectl exec -n production $POD -c application -- cat /var/log/app/app.log
```

Verify sidecar can read the same logs:
```bash
kubectl exec -n production $POD -c log-agent -- cat /var/log/app/app.log
```

Both commands should show the same log content!

**Step 9: Verify sidecar is processing logs**

Check sidecar logs to see if it's reading the log file:
```bash
kubectl logs -n production $POD -c log-agent
```

You should see the application logs being tailed.

**Step 10: Understanding the complete configuration**

The final deployment has:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-app
  namespace: production
  labels:
    app: web-app
    tier: frontend
spec:
  replicas: 2                          # Not changed
  selector:
    matchLabels:
      app: web-app                     # Not changed
  template:
    metadata:
      labels:
        app: web-app                   # Not changed
        tier: frontend
    spec:
      containers:
      # EXISTING APPLICATION CONTAINER (not modified)
      - name: application
        image: busybox:latest
        command: ["/bin/sh"]
        args:
        - -c
        - |
          mkdir -p /var/log/app
          echo "Application starting..." > /var/log/app/app.log
          while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - [INFO] Processing request $RANDOM" >> /var/log/app/app.log
            sleep 5
          done
        volumeMounts:
        - name: log-volume
          mountPath: /var/log/app
      
      # NEW SIDECAR CONTAINER (added)
      - name: log-agent
        image: fluentd:latest
        volumeMounts:
        - name: log-volume              # Same volume name
          mountPath: /var/log/app       # Same mount path
      
      volumes:
      - name: log-volume
        emptyDir: {}
```

**Key points:**
1. ✅ Application container unchanged
2. ✅ New `log-agent` container added
3. ✅ Both containers mount same volume (`log-volume`)
4. ✅ Both containers mount at same path (`/var/log/app`)
5. ✅ Sidecar remains running (infinite loop with `tail -f`)
6. ✅ Labels, selectors, replica count unchanged

**Verification checklist:**
- ✅ Deployment still named `web-app`
- ✅ Namespace is `production`
- ✅ Two containers per pod: `application` and `log-agent`
- ✅ Sidecar uses `fluentd:latest` image
- ✅ Volume `log-volume` exists
- ✅ Both containers mount volume at `/var/log/app`
- ✅ Sidecar can read `/var/log/app/app.log`
- ✅ Both containers are running
- ✅ Replica count is still 2
- ✅ Labels unchanged

</details>



