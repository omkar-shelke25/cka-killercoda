# CKA: Create Restartable Sidecar Init Container for Logging

**Official Kubernetes Documentation**:
- [Sidecar Containers](https://kubernetes.io/docs/concepts/workloads/pods/sidecar-containers/)
- [Init Containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/)
- [Pods](https://kubernetes.io/docs/concepts/workloads/pods/)
- [Volumes](https://kubernetes.io/docs/concepts/storage/volumes/)
- [EmptyDir Volumes](https://kubernetes.io/docs/concepts/storage/volumes/#emptydir)
- [kubectl logs](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_logs/)

## Background

The Tech Lead decided it's time for more logging, to finally fight all these missing data incidents. There is an existing container named `cleaner-con` in Deployment `cleaner` in Namespace `mercury`. This container mounts a volume and writes logs to a file called `cleaner.log`.

The YAML for the existing Deployment is available at `/opt/course/16/cleaner.yaml`.

## Task

Do the following:

1. **Examine the existing Deployment** at `/opt/course/16/cleaner.yaml`
2. **Save your changes** to `/opt/course/16/cleaner-new.yaml`
3. **Add a restartable sidecar init container** named `logger-con` under `spec.template.spec.initContainers` with:
   - Image: `public.ecr.aws/docker/library/busybox:latest`
   - `restartPolicy: Always`
   - Mount the same volume as `cleaner-con`
   - Use `tail -F` command to stream `/var/log/cleaner.log` to stdout
4. **Apply the updated Deployment** to make it running
5. **Verify** the logs are accessible via `kubectl logs`
6. **Check the logs** to find information about the missing data incidents

**Note**: This sidecar must be implemented as a **restartable init container** (an init container with `restartPolicy: Always`). This is a Kubernetes 1.29+ feature where init containers can stay running alongside the main application containers. Do not add it as a regular container under `spec.containers`.

---


## Solution

<details>
<summary>📖 Solution</summary>

**Step 1: Examine the existing deployment**

```bash
cat /opt/course/16/cleaner.yaml
```

**Step 2: Copy and modify the deployment**

```bash
cp /opt/course/16/cleaner.yaml /opt/course/16/cleaner-new.yaml
```

Edit the file to add the sidecar as a restartable init container. The init container should have `restartPolicy: Always` so it stays running after the main container starts.

```bash
cat <<'EOF' > /opt/course/16/cleaner-new.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cleaner
  namespace: mercury
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cleaner
  template:
    metadata:
      labels:
        app: cleaner
    spec:
      volumes:
      - name: logs
        emptyDir: {}
      initContainers:
      - name: logger-con
        image: public.ecr.aws/docker/library/busybox:latest
        restartPolicy: Always
        volumeMounts:
        - name: logs
          mountPath: /var/log
        command: ["sh", "-c", "tail -F /var/log/cleaner.log"]
      containers:
      - name: cleaner-con
        image: public.ecr.aws/docker/library/busybox:latest
        volumeMounts:
        - name: logs
          mountPath: /var/log
        command: ["sh", "-c"]
        args:
        - |
          while true; do
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning data..." >> /var/log/cleaner.log
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Found 42 records" >> /var/log/cleaner.log
            echo "$(date '+%Y-%m-%d %H:%M:%S') - WARNING: 3 records missing!" >> /var/log/cleaner.log
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Data cleanup completed" >> /var/log/cleaner.log
            sleep 10
          done
EOF
```

**Step 3: Apply the updated deployment**

```bash
kubectl apply -f /opt/course/16/cleaner-new.yaml
```

**Step 4: Wait for the deployment to roll out**

```bash
kubectl rollout status deployment/cleaner -n mercury
```

**Step 5: Check the logs from the sidecar init container**

```bash
kubectl logs -n mercury deployment/cleaner -c logger-con
```

You should see log entries including warnings about missing data:

```
WARNING: 3 records missing!
```

**Key Points**:
- The `logger-con` container is defined as an `initContainer` with `restartPolicy: Always`
- This makes it a restartable sidecar that runs alongside the main container
- Both containers share the same `logs` volume
- The sidecar uses `tail -F` to continuously stream the log file to stdout
- The logs reveal "WARNING: 3 records missing!" - the missing data incidents

</details>
