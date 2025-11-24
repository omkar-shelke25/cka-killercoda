# 🎮 **CKA: Complete User Onboarding with Kubernetes CSR API and RBAC**

📚 **Official Kubernetes Documentation**: 
- [Certificate Signing Requests](https://kubernetes.io/docs/reference/access-authn-authz/certificate-signing-requests/)
- [Authenticating with Bootstrap Tokens](https://kubernetes.io/docs/reference/access-authn-authz/authentication/)
- [Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)

---

## 🎯 **Scenario Context**

**GameForge Studios** is onboarding a new developer named **Siddhi Shelke** to work on the "Mecha Pulse" game project. You are the Kubernetes administrator responsible for provisioning secure access to the development cluster.

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

### **Task 3: Submit and Approve CSR using Kubernetes API**
1. Create a Kubernetes CertificateSigningRequest resource named `siddhi` with:
   - The base64-encoded CSR content
   - `signerName: kubernetes.io/kube-apiserver-client`
   - `usages: ["client auth"]`
2. Approve the CSR using `kubectl certificate approve`
3. Extract the signed certificate and save to: `/root/gameforge-onboarding/siddhi.shelke01.crt`

### **Task 4: Configure Kubeconfig User Entry**
Add a new user entry named `siddhi.shelke01` to your kubeconfig using:
- Client certificate: `/root/gameforge-onboarding/siddhi.shelke01.crt`
- Client key: `/root/gameforge-onboarding/siddhi.shelke01.key`
- **Important**: Use `--embed-certs=true` to embed certificates in kubeconfig

### **Task 5: Create Context**
Create a new context named `siddhi-mecha-dev` configured with:
- **Cluster**: `kubernetes` (the actual cluster name)
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
- The cluster entry for `kubernetes`
- Save to: `/root/gameforge-onboarding/siddhi-kubeconfig.yaml`

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

### **Step 3: Submit and Approve CSR using Kubernetes API**

**3.1: Encode the CSR in base64**
```bash
cat /root/gameforge-onboarding/siddhi.shelke01.csr | base64 | tr -d "\n"
```

Copy the output (base64-encoded CSR).

**3.2: Create CertificateSigningRequest YAML**
```bash
cat > /root/gameforge-onboarding/siddhi-csr.yaml <<EOF
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: siddhi
spec:
  request: $(cat /root/gameforge-onboarding/siddhi.shelke01.csr | base64 | tr -d "\n")
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 31536000  # 1 year (365 days)
  usages:
  - client auth
EOF
```

**3.3: Apply the CSR**
```bash
kubectl apply -f /root/gameforge-onboarding/siddhi-csr.yaml
```

Verify CSR was created:
```bash
kubectl get csr
```

You should see the CSR in "Pending" state.

**3.4: Approve the CSR**
```bash
kubectl certificate approve siddhi
```

Verify it's approved:
```bash
kubectl get csr siddhi
```

Output should show:
```
NAME     AGE   SIGNERNAME                            REQUESTOR          REQUESTEDDURATION   CONDITION
siddhi   10s   kubernetes.io/kube-apiserver-client   kubernetes-admin   365d                Approved,Issued
```

**3.5: Extract the signed certificate**
```bash
kubectl get csr siddhi -o jsonpath='{.status.certificate}' | base64 -d > /root/gameforge-onboarding/siddhi.shelke01.crt
```

Verify the certificate:
```bash
openssl x509 -in /root/gameforge-onboarding/siddhi.shelke01.crt -text -noout
```

Check subject and validity:
```bash
openssl x509 -in /root/gameforge-onboarding/siddhi.shelke01.crt -noout -subject -dates
```

---

### **Step 4: Add User to Kubeconfig with Embedded Certificates**

```bash
kubectl config set-credentials siddhi.shelke01 \
  --client-certificate=/root/gameforge-onboarding/siddhi.shelke01.crt \
  --client-key=/root/gameforge-onboarding/siddhi.shelke01.key \
  --embed-certs=true
```

**Important**: The `--embed-certs=true` flag embeds the certificate data directly in the kubeconfig file (base64-encoded), making it portable.

Verify the user was added:
```bash
kubectl config get-users
```

Check that certificates are embedded:
```bash
kubectl config view --raw | grep -A 5 "name: siddhi.shelke01"
```

You should see `client-certificate-data` and `client-key-data` instead of file paths.

---

### **Step 5: Create Context**

```bash
kubectl config set-context siddhi-mecha-dev \
  --cluster=kubernetes \
  --namespace=game-dev \
  --user=siddhi.shelke01
```

**Important**: The cluster name is `kubernetes`, not `mecha-pulse-game-dev` (which is the context name).

Verify the context:
```bash
kubectl config get-contexts siddhi-mecha-dev
```

View full context details:
```bash
kubectl config view | grep -A 4 "name: siddhi-mecha-dev"
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

Expected output:
```
Name:         dev-access-role
Namespace:    game-dev
PolicyRule:
  Resources   Non-Resource URLs  Resource Names  Verbs
  ---------   -----------------  --------------  -----
  deployments []                 []              [get list watch]
  pods        []                 []              [get list watch]
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

Expected output:
```
Name:         siddhi-dev-binding
Namespace:    game-dev
Role:
  Kind:  Role
  Name:  dev-access-role
Subjects:
  Kind  Name              Namespace
  ----  ----              ---------
  User  siddhi.shelke01
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
kubectl get deployment mecha-pulse-api -n game-dev -o wide
```

Expected output: You should see the list of pods and deployments.

❌ **Test write operations (should fail):**
```bash
kubectl run test-pod --image=nginx -n game-dev
```
Expected error: `Error from server (Forbidden): pods is forbidden: User "siddhi.shelke01" cannot create resource "pods"`

```bash
kubectl delete deployment mecha-pulse-api -n game-dev
```
Expected error: `Error from server (Forbidden): deployments.apps "mecha-pulse-api" is forbidden: User "siddhi.shelke01" cannot delete resource "deployments"`

Use `kubectl auth can-i` to verify permissions:
```bash
kubectl auth can-i list pods -n game-dev
# yes

kubectl auth can-i get deployments -n game-dev
# yes

kubectl auth can-i create pods -n game-dev
# no

kubectl auth can-i delete deployments -n game-dev
# no

kubectl auth can-i update pods -n game-dev
# no
```

Switch back to admin:
```bash
kubectl config use-context mecha-pulse-game-dev
```

---

### **Step 10: Export Minimal Kubeconfig**

Export only the necessary components for the user:
```bash
kubectl config view --minify \
  --flatten \
  --context=siddhi-mecha-dev > /root/gameforge-onboarding/siddhi-kubeconfig.yaml
```

**Note**: The `--minify` flag includes only the current context and its dependencies.

Verify the exported kubeconfig:
```bash
cat /root/gameforge-onboarding/siddhi-kubeconfig.yaml
```

You should see:
- One cluster: `kubernetes`
- One user: `siddhi.shelke01` (with embedded certificate data)
- One context: `siddhi-mecha-dev`
- Current context set to: `siddhi-mecha-dev`

Test the exported kubeconfig:
```bash
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml get pods
```

Expected output: List of pods in the `game-dev` namespace.

Verify it cannot create pods:
```bash
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml run test --image=nginx
```
Expected: Forbidden error.

---

## **📊 Verification Checklist**

Run these commands to verify everything is configured correctly:

```bash
# 1. Check files exist
ls -lh /root/gameforge-onboarding/siddhi.shelke01.{key,csr,crt}
ls -lh /root/gameforge-onboarding/siddhi-csr.yaml
ls -lh /root/gameforge-onboarding/siddhi-kubeconfig.yaml

# 2. Verify CSR was approved
kubectl get csr siddhi

# 3. Verify user in kubeconfig (with embedded certs)
kubectl config view --raw | grep -A 3 "name: siddhi.shelke01"

# 4. Verify context references correct cluster
kubectl config view | grep -A 3 "name: siddhi-mecha-dev"

# 5. Verify Role
kubectl get role dev-access-role -n game-dev
kubectl describe role dev-access-role -n game-dev

# 6. Verify RoleBinding
kubectl get rolebinding siddhi-dev-binding -n game-dev
kubectl describe rolebinding siddhi-dev-binding -n game-dev

# 7. Test permissions with kubectl auth can-i (as admin)
kubectl auth can-i list pods -n game-dev --as=siddhi.shelke01
kubectl auth can-i create pods -n game-dev --as=siddhi.shelke01
kubectl auth can-i delete deployments -n game-dev --as=siddhi.shelke01

# 8. Test with user context
kubectl config use-context siddhi-mecha-dev
kubectl get pods
kubectl get deployments
kubectl auth can-i create pods
kubectl config use-context mecha-pulse-game-dev

# 9. Test exported kubeconfig
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml get pods
kubectl --kubeconfig=/root/gameforge-onboarding/siddhi-kubeconfig.yaml auth can-i create pods
```


</details>


