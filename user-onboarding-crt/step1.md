# 🎮 **CKA: Complete User Onboarding with Certificates and RBAC**

📚 **Official Kubernetes Documentation**: 
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Authenticating with Bootstrap Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## 🎯 **Scenario Context**

**GameForge Studios** is onboarding a new developer named **Siddhi Shelke** to work on the "Mecha Pulse" game project. 

You are the Kubernetes administrator responsible for provisioning secure access to the development cluster `mecha-pulse-game-dev`.

The developer needs read-only access to Pods and Deployments in the `game-dev` namespace to monitor application deployments but should not be able to modify any resources.

---

## 📋 **Your Mission**

Complete the following comprehensive user onboarding workflow:

### **Task 1: Generate Private Key**
Generate a 4096-bit RSA private key for the user `siddhi.shelke01` and save it to:
- `/root/gameforge-onboarding/siddhi.shelke01.key`

### **Task 2: Create Certificate Signing Request (CSR)**
Create a CSR using the private key with the following subject:
- **Common Name (CN)**: `siddhi.shelke01`
- **Organization (O)**: `gameforge-studios`
- Save the CSR to: `/root/gameforge-onboarding/siddhi.shelke01.csr`

### **Task 3: Sign the Certificate**
Sign the CSR using the Kubernetes CA located at:
- CA Certificate: `/etc/kubernetes/pki/ca.crt`
- CA Key: `/etc/kubernetes/pki/ca.key`
- Validity: 365 days (1 year)
- Save the signed certificate to: `/root/gameforge-onboarding/siddhi.shelke01.crt`

### **Task 4: Configure Kubeconfig User Entry**
Add a new user entry named `siddhi.shelke01` to your kubeconfig using:
- Client certificate: `/root/gameforge-onboarding/siddhi.shelke01.crt`
- Client key: `/root/gameforge-onboarding/siddhi.shelke01.key`

### **Task 5: Create Context**
Create a new context named `siddhi-mecha-dev` configured with:
- **Cluster**: `mecha-pulse-game-dev`
- **User**: `siddhi.shelke01`
- **Namespace**: `game-dev`

### **Task 6: Verify No Initial Access**
Switch to the `siddhi-mecha-dev` context and attempt to list pods. This should fail due to missing RBAC permissions (expected behavior).

### **Task 7: Create Role**
Create a Role named `dev-access-role` in the `game-dev` namespace with read-only permissions:
- **Verbs**: `get`, `list`, `watch`
- **Resources**: `pods`, `deployments`

### **Task 8: Create RoleBinding**
Create a RoleBinding named `siddhi-dev-binding` in the `game-dev` namespace that binds:
- **User**: `siddhi.shelke01`
- **Role**: `dev-access-role`

### **Task 9: Verify Permissions**
Switch back to the `siddhi-mecha-dev` context and verify:
- ✅ Can list pods in `game-dev` namespace
- ✅ Can list deployments in `game-dev` namespace
- ❌ Cannot create pods (should fail)
- ❌ Cannot delete deployments (should fail)

### **Task 10: Export Minimal Kubeconfig**
Export a minimal kubeconfig file for the user `siddhi.shelke01` that includes only:
- The user credentials for `siddhi.shelke01`
- The `siddhi-mecha-dev` context
- The cluster entry for `mecha-pulse-game-dev`
- Save to: `/root/gameforge-onboarding/siddhi-kubeconfig.yaml`

---

## 🔍 **Important Notes**

- Work in the directory: `/root/gameforge-onboarding/`
- The Kubernetes CA files are located at: `/etc/kubernetes/pki/`
- The `game-dev` namespace already exists with sample deployments
- Do not modify existing cluster resources except as required
- Use the current cluster context name: `mecha-pulse-game-dev`

---

### 💡 Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

## **Complete Solution**

### **Step 1: Generate Private Key**

```bash
cd /root/gameforge-onboarding/

openssl genrsa -out siddhi.shelke01.key 4096
```

Verify the key:
```bash
ls -lh siddhi.shelke01.key
```

---

### **Step 2: Create Certificate Signing Request**

```bash
openssl req -new \
  -key siddhi.shelke01.key \
  -out siddhi.shelke01.csr \
  -subj "/CN=siddhi.shelke01/O=gameforge-studios"
```

Verify the CSR:
```bash
openssl req -in siddhi.shelke01.csr -noout -text | grep -A 2 Subject
```

Expected output should show:
```
Subject: CN=siddhi.shelke01, O=gameforge-studios
```

---

### **Step 3: Sign the Certificate**

```bash
openssl x509 -req \
  -in siddhi.shelke01.csr \
  -CA /etc/kubernetes/pki/ca.crt \
  -CAkey /etc/kubernetes/pki/ca.key \
  -CAcreateserial \
  -out siddhi.shelke01.crt \
  -days 365
```

Verify the certificate:
```bash
openssl x509 -in siddhi.shelke01.crt -noout -text | grep -A 2 Subject
openssl x509 -in siddhi.shelke01.crt -noout -dates
```

---

### **Step 4: Add User to Kubeconfig**

```bash
kubectl config set-credentials siddhi.shelke01 \
  --client-certificate=/root/gameforge-onboarding/siddhi.shelke01.crt \
  --client-key=/root/gameforge-onboarding/siddhi.shelke01.key
```

Verify the user was added:
```bash
kubectl config get-users
```

---

### **Step 5: Create Context**

```bash
kubectl config set-context siddhi-mecha-dev \
  --cluster=mecha-pulse-game-dev \
  --namespace=game-dev \
  --user=siddhi.shelke01
```

Verify the context:
```bash
kubectl config get-contexts siddhi-mecha-dev
```

---

### **Step 6: Verify No Initial Access (Expected to Fail)**

```bash
kubectl config use-context siddhi-mecha-dev
kubectl get pods
```

Expected error:
```
Error from server (Forbidden): pods is forbidden: User "siddhi.shelke01" cannot list resource "pods" in API group "" in the namespace "game-dev"
```

This is expected! The user has valid authentication but no authorization yet.

Switch back to admin context:
```bash
kubectl config use-context mecha-pulse-game-dev
```

---

### **Step 7: Create Role**

```bash
kubectl create role dev-access-role \
  --verb=get,list,watch \
  --resource=pods,deployments \
  -n game-dev
```

Verify the role:
```bash
kubectl describe role dev-access-role -n game-dev
```

---

### **Step 8: Create RoleBinding**

```bash
kubectl create rolebinding siddhi-dev-binding \
  --role=dev-access-role \
  --user=siddhi.shelke01 \
  -n game-dev
```

Verify the binding:
```bash
kubectl describe rolebinding siddhi-dev-binding -n game-dev
```

---

### **Step 9: Verify Permissions**

Switch to the user context:
```bash
kubectl config use-context siddhi-mecha-dev
```

✅ **Test read operations (should succeed):**
```bash
kubectl get pods
kubectl get deployments
kubectl get pods -n game-dev
kubectl get deployment mecha-pulse-api -n game-dev
```

❌ **Test write operations (should fail):**
```bash
kubectl run test-pod --image=nginx -n game-dev
# Expected: Error from server (Forbidden)

kubectl delete deployment mecha-pulse-api -n game-dev
# Expected: Error from server (Forbidden)
```

Use `kubectl auth can-i` to verify permissions:
```bash
kubectl auth can-i list pods -n game-dev
# yes

kubectl auth can-i create pods -n game-dev
# no

kubectl auth can-i delete deployments -n game-dev
# no
```

Switch back to admin:
```bash
kubectl config use-context mecha-pulse-game-dev
```

---

### **Step 10: Export Minimal Kubeconfig**

Export only the necessary components:
```bash
kubectl config view --minify \
  --flatten \
  --context=siddhi-mecha-dev > /root/gameforge-onboarding/siddhi-kubeconfig.yaml
```

Verify the exported kubeconfig:
```bash
cat /root/gameforge-onboarding/siddhi-kubeconfig.yaml
```

Test the exported kubeconfig:
```bash
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml get pods
```

**Alternative manual method** (if you need more control):
```bash
# Create a new kubeconfig from scratch
kubectl config view --raw > /tmp/full-config.yaml

# Extract specific elements
kubectl --kubeconfig=/tmp/full-config.yaml config view \
  --flatten \
  --minify \
  --context=siddhi-mecha-dev > /root/gameforge-onboarding/siddhi-kubeconfig.yaml

# Clean up temp file
rm /tmp/full-config.yaml
```

---

## **📊 Verification Checklist**

Run these commands to verify everything is configured correctly:

```bash
# 1. Check files exist
ls -lh /root/gameforge-onboarding/siddhi.shelke01.{key,csr,crt}
ls -lh /root/gameforge-onboarding/siddhi-kubeconfig.yaml

# 2. Verify user in kubeconfig
kubectl config get-users | grep siddhi.shelke01

# 3. Verify context
kubectl config get-contexts | grep siddhi-mecha-dev

# 4. Verify Role
kubectl get role dev-access-role -n game-dev

# 5. Verify RoleBinding
kubectl get rolebinding siddhi-dev-binding -n game-dev

# 6. Test permissions with kubectl auth can-i
kubectl auth can-i list pods -n game-dev --as=siddhi.shelke01
kubectl auth can-i create pods -n game-dev --as=siddhi.shelke01
kubectl auth can-i delete deployments -n game-dev --as=siddhi.shelke01

# 7. Test with exported kubeconfig
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml get pods
```

---

## **🔐 Security Best Practices Demonstrated**

✅ **Strong encryption**: 4096-bit RSA keys
✅ **Certificate validity**: Time-limited (1 year)
✅ **Least privilege**: Read-only access only
✅ **Namespace isolation**: Permissions scoped to `game-dev` only
✅ **Audit trail**: User identity embedded in certificate (CN and O fields)
✅ **Clean credential management**: Minimal kubeconfig export

</details>

---

## 🎓 **Key Concepts Covered**

- **X.509 Client Certificates**: Industry-standard authentication method
- **PKI**: Public Key Infrastructure and Certificate Authorities
- **Kubeconfig Structure**: users, clusters, contexts
- **RBAC**: Role-Based Access Control with Roles and RoleBindings
- **Principle of Least Privilege**: Granting minimal necessary permissions
- **Namespace Scoping**: Isolating permissions to specific namespaces

This comprehensive scenario mirrors real-world enterprise user onboarding workflows and is representative of complex CKA exam questions! 🚀
