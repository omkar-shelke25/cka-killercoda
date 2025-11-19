# Kubernetes Downward API - Resource Monitoring with Sidecar

## Scenario

A Pod named `react-frontend-monitor` is running in the `react-frontend` namespace with two containers. The main container is `frontend-app` running nginx with defined resource requests and limits. A sidecar container named `monitor-agent` runs a monitoring script that logs the resource configuration of the main container.

The monitoring script is stored in a ConfigMap called `monitor-agent-cm` and mounted into the sidecar container at `/opt/monitor/monitor.sh`. When you examine the script, you notice it expects four environment variables to display the main container's resource specifications, but these environment variables are not currently defined in the sidecar container. As a result, the monitor prints empty values for CPU and memory.

The required environment variables that the script expects are:
- `APP_CPU_REQUEST` - should contain the CPU request in millicores
- `APP_CPU_LIMIT` - should contain the CPU limit in millicores  
- `APP_MEM_REQUEST` - should contain the memory request in mebibytes
- `APP_MEM_LIMIT` - should contain the memory limit in mebibytes

## Task

Your task is to configure the Downward API environment variables for the `monitor-agent` sidecar container so it can read the `frontend-app` container's resource requests and limits. The Pod manifest is located at `/app/react-ui.yaml`.

You must add the `env:` section to the `monitor-agent` container with the four required environment variables using the Kubernetes Downward API. Each environment variable should use `resourceFieldRef` to reference the appropriate resource field from the `frontend-app` container.

**Important requirements:**
- For CPU values, use `divisor: 1m` to get values in millicores
- For memory values, use `divisor: 1Mi` to get values in mebibytes
- Reference the correct container name: `frontend-app`
- Use the exact environment variable names expected by the monitoring script

After updating the manifest file, apply the changes to update the Pod. Once complete, verify that the monitor-agent logs now display the correct resource values instead of empty strings.

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

First, examine the monitoring script to identify required environment variables:
```bash
kubectl exec -n react-frontend react-frontend-monitor -c monitor-agent -- cat /opt/monitor/monitor.sh
```

You'll see the script expects: `APP_CPU_REQUEST`, `APP_CPU_LIMIT`, `APP_MEM_REQUEST`, and `APP_MEM_LIMIT`.

Edit the Pod manifest:
```bash
vi /app/react-ui.yaml
```

Add the `env:` section to the `monitor-agent` container. The complete Pod manifest should look like this:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: react-frontend-monitor
  namespace: react-frontend
  labels:
    app.kubernetes.io/name: react-frontend
    tier: frontend
spec:
  containers:
  - name: frontend-app
    image: nginx
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "500m"
        memory: "256Mi"
  - name: monitor-agent
    image: busybox:1.36
    command: ["/bin/sh", "/opt/monitor/monitor.sh"]
    env:
    - name: APP_CPU_REQUEST
      valueFrom:
        resourceFieldRef:
          containerName: frontend-app
          resource: requests.cpu 
          divisor: 1m
    - name: APP_CPU_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: frontend-app
          resource: limits.cpu 
          divisor: 1m
    - name: APP_MEM_REQUEST
      valueFrom:
        resourceFieldRef:
          containerName: frontend-app
          resource: requests.memory
          divisor: 1Mi
    - name: APP_MEM_LIMIT
      valueFrom:
        resourceFieldRef:
          containerName: frontend-app
          resource: limits.memory
          divisor: 1Mi
    volumeMounts:
      - name: monitor-script
        mountPath: /opt/monitor
        readOnly: true
  volumes:
    - name: monitor-script
      configMap:
        name: monitor-agent-cm
        defaultMode: 0755
```

Delete the existing Pod and apply the updated manifest:
```bash
kubectl delete pod react-frontend-monitor -n react-frontend
kubectl apply -f /app/react-ui.yaml
```

Wait for the Pod to be ready:
```bash
kubectl wait --for=condition=ready pod/react-frontend-monitor -n react-frontend --timeout=60s
```

Verify the monitor now displays resource values:
```bash
kubectl logs -n react-frontend react-frontend-monitor -c monitor-agent
```

Expected output:
```
========================================
 🚀 React Frontend Resource Monitor
========================================
 ⚙️  CPU Request  : 100m
 ⚙️  CPU Limit    : 500m
 🧠 Mem Request: 128Mi
 🧠 Mem Limit  : 256Mi
----------------------------------------
2025-01-15T10:30:45+00:00  ⚙️ CPU_REQ=100m | CPU_LIM=500m | 🧩 MEM_REQ=128Mi | MEM_LIM=256Mi
```

</details>
