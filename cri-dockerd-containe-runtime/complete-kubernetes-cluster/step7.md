# Step 7: Verify and Test Cluster 🧪

## 📚 Documentation Reference
- [Validating your cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/#verifying-the-installation)
- [Troubleshooting kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/troubleshooting-kubeadm/)

## 🎯 Objective

Perform comprehensive verification of your Kubernetes cluster by checking all components, deploying a test application, and validating cluster functionality.

## 🧠 Why This Matters

Thorough testing ensures:
- All cluster components are healthy
- Pods can be scheduled and run
- Networking functions correctly
- DNS resolution works
- Storage and services operate as expected

---

## 📋 Tasks

### Task 7.1: Verify Cluster Information

Get comprehensive cluster details:

```bash
kubectl cluster-info
```

Expected output:
```
Kubernetes control plane is running at https://X.X.X.X:6443
CoreDNS is running at https://X.X.X.X:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
```

Get additional cluster info:

```bash
kubectl cluster-info dump > /root/cluster-setup/cluster-info.txt
```

💡 This creates a detailed cluster diagnostic file.

---

### Task 7.2: Check All Nodes

View nodes with detailed information:

```bash
kubectl get nodes -o wide
```

Check node details:

```bash
kubectl describe nodes
```

Look for:
- ✅ All nodes in `Ready` state
- ✅ Correct Kubernetes version
- ✅ Container runtime version
- ✅ No resource pressure conditions

---

### Task 7.3: Verify System Pods

Check all system pods across all namespaces:

```bash
kubectl get pods --all-namespaces
```

Verify critical pods are running:

```bash
kubectl get pods -n kube-system
```

Expected pods (all should be `Running`):
- `etcd-*`
- `kube-apiserver-*`
- `kube-controller-manager-*`
- `kube-scheduler-*`
- `kube-proxy-*`
- `coredns-*` (2 replicas)
- CNI pods (calico-node or kube-flannel)

---

### Task 7.4: Check Component Status

Verify control plane components:

```bash
kubectl get componentstatuses
```

⚠️ **Note**: This command is deprecated in newer versions but still useful for verification.

Alternative - check component health:

```bash
kubectl get --raw='/readyz?verbose'
```

Expected output: `[+]ping ok` and other health checks passing

---

### Task 7.5: Deploy a Test Application

Create a test deployment:

```bash
kubectl create deployment nginx-test --image=nginx:alpine
```

Verify deployment:

```bash
kubectl get deployments
```

```bash
kubectl get pods
```

Wait for pod to be running:

```bash
kubectl wait --for=condition=ready pod -l app=nginx-test --timeout=60s
```

---

### Task 7.6: Expose the Application

Create a service:

```bash
kubectl expose deployment nginx-test --port=80 --type=NodePort
```

Get service details:

```bash
kubectl get services
```

Note the NodePort (e.g., 30XXX).

---

### Task 7.7: Test Pod Networking

Get the pod IP:

```bash
POD_NAME=$(kubectl get pods -l app=nginx-test -o jsonpath='{.items[0].metadata.name}')
POD_IP=$(kubectl get pod $POD_NAME -o jsonpath='{.status.podIP}')
echo "Pod IP: $POD_IP"
```

Test connectivity from master node:

```bash
curl http://$POD_IP
```

Expected output: Nginx welcome page HTML.

---

### Task 7.8: Test DNS Resolution

Test CoreDNS functionality:

```bash
kubectl run dns-test --image=busybox:latest --rm -it --restart=Never -- nslookup kubernetes.default
```

Expected output:
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
```

---

### Task 7.9: Test Service Discovery

Test if service DNS works:

```bash
kubectl run service-test --image=busybox:latest --rm -it --restart=Never -- wget -O- http://nginx-test
```

Expected output: Nginx welcome page content.

---

### Task 7.10: Check Resource Usage

View node resource utilization:

```bash
kubectl top nodes
```

⚠️ **Note**: If metrics-server is not installed, this command won't work. That's OK for basic setup.

View resource allocation:

```bash
kubectl describe nodes | grep -A 5 "Allocated resources"
```

---

### Task 7.11: Verify Logs

Check pod logs:

```bash
kubectl logs deployment/nginx-test
```

Check system component logs:

```bash
kubectl logs -n kube-system -l component=kube-apiserver
```

```bash
kubectl logs -n kube-system -l k8s-app=kube-dns
```

---

### Task 7.12: Clean Up Test Resources

Remove test deployment and service:

```bash
kubectl delete deployment nginx-test
kubectl delete service nginx-test
```

Verify removal:

```bash
kubectl get all
```

---

## ✅ Final Verification Checklist

Confirm all checks pass:

- [ ] Cluster info shows control plane and CoreDNS running
- [ ] All nodes are in `Ready` state
- [ ] All system pods are `Running`
- [ ] Test deployment created and running
- [ ] Service created and accessible
- [ ] Pod networking functional (curl to pod IP)
- [ ] DNS resolution working (nslookup)
- [ ] Service discovery functional
- [ ] Logs accessible for all components
- [ ] Test resources cleaned up

---

## 🔍 Troubleshooting

**Problem**: Pods stuck in `Pending`
- **Solution**: Check node resources: `kubectl describe node`
- Verify CNI is running: `kubectl get pods -n calico-system`

**Problem**: DNS not resolving
- **Solution**: Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`
- View logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`

**Problem**: Cannot access pod IP
- **Solution**: Verify CNI networking is healthy
- Check firewall rules don't block pod network CIDR

**Problem**: Service not accessible
- **Solution**: Verify service endpoints: `kubectl get endpoints nginx-test`
- Check kube-proxy is running: `kubectl get pods -n kube-system -l k8s-app=kube-proxy`

---

## 📊 Cluster Health Summary

Create a comprehensive health report:

```bash
cat << 'EOF' > /root/cluster-setup/health-check.sh
#!/bin/bash
echo "=== Kubernetes Cluster Health Report ==="
echo ""
echo "Cluster Info:"
kubectl cluster-info
echo ""
echo "Node Status:"
kubectl get nodes -o wide
echo ""
echo "System Pods:"
kubectl get pods -n kube-system
echo ""
echo "Component Health:"
kubectl get --raw='/readyz?verbose'
echo ""
echo "Resource Usage:"
kubectl describe nodes | grep -A 5 "Allocated resources"
EOF

chmod +x /root/cluster-setup/health-check.sh
./root/cluster-setup/health-check.sh
```

---

## 📝 What You Learned

- Comprehensive cluster verification techniques
- System component health checks
- Pod lifecycle and deployment
- Service creation and networking
- DNS and service discovery testing
- Resource monitoring and management
- Log access and troubleshooting
- Clean-up procedures

---

## 🎓 Next Steps for Production

1. **Security Hardening:**
   - Enable RBAC policies
   - Configure Pod Security Standards
   - Implement Network Policies
   - Set up TLS for ingress

2. **Monitoring & Logging:**
   - Install metrics-server
   - Deploy Prometheus & Grafana
   - Set up centralized logging (EFK/ELK)

3. **Storage:**
   - Configure StorageClasses
   - Deploy persistent volume provisioner
   - Test volume mounting and persistence

4. **High Availability:**
   - Add multiple master nodes
   - Configure external etcd cluster
   - Set up load balancer for API server

5. **Backup & Disaster Recovery:**
   - Implement etcd backup strategy
   - Test cluster restore procedures
   - Document recovery runbooks

---

**Congratulations!** 🎉 

You've successfully built and verified a complete Kubernetes cluster from scratch!

Click **Continue** to see the finish page and summary! ➡️
