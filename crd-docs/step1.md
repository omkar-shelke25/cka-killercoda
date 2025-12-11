# 🧠 **CKA: Explore and Document Custom Resource Definitions**

📚 **Official Kubernetes Documentation**: 
- [Custom Resources](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)
- [Custom Resource Definitions](https://kubernetes.io/docs/tasks/extend-kubernetes/custom-resources/custom-resource-definitions/)
- [kubectl explain](https://kubernetes.io/docs/reference/generated/kubectl/kubectl-commands#explain)

### 🎯 **Context**

You are working with a Kubernetes cluster that has cert-manager installed. Cert-manager is a popular operator that manages TLS certificates automatically. It extends Kubernetes by adding several Custom Resource Definitions (CRDs) that allow you to define certificates, issuers, and other certificate-related resources declaratively.

As a Kubernetes administrator, you need to understand what CRDs are available in the cluster and how to access their documentation to properly configure them.

### ❓ **Task**

**Task 1:** Create a list of all cert-manager CRDs and save it to `/root/resources.txt`
- List all CRDs in the cluster that contain the keyword `cert-manager`
- Save the complete YAML output of these CRDs to the file

**Task 2:** Extract documentation for the Certificate CRD's subject specification field
- Using `kubectl explain`, extract the documentation for the `spec.subject` field of the Certificate Custom Resource
- Save this documentation to `/root/subject.txt`

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Explore available CRDs**

First, let's see all CRDs in the cluster:
```bash
kubectl get crd
```

Filter for cert-manager CRDs:
```bash
kubectl get crd | grep cert-manager
```

You should see CRDs like:
- certificates.cert-manager.io
- certificaterequests.cert-manager.io
- issuers.cert-manager.io
- clusterissuers.cert-manager.io
- challenges.acme.cert-manager.io
- orders.acme.cert-manager.io

**Step 2: Get detailed information about a specific CRD**

```bash
kubectl get crd certificates.cert-manager.io
kubectl describe crd certificates.cert-manager.io
```

**Step 3: Complete Task 1 - Save all cert-manager CRDs to file**

**Method 1: Using grep filter**
```bash
kubectl get crd -o yaml | grep -A 10000 cert-manager > /root/resources.txt
```

**Method 2: Using custom-columns to get names, then fetch YAML (More precise)**
```bash
# Get list of cert-manager CRD names
kubectl get crd -o name | grep cert-manager > /tmp/crd-list.txt

# Create empty file
echo "---" > /root/resources.txt

# Loop through and append each CRD YAML
for crd in $(kubectl get crd -o name | grep cert-manager); do
  kubectl get $crd -o yaml >> /root/resources.txt
  echo "---" >> /root/resources.txt
done
```

**Method 3: Most efficient - using label selector (if available)**
```bash
kubectl get crd -l app.kubernetes.io/name=cert-manager -o yaml > /root/resources.txt
```

**Recommended Method: Direct approach**
```bash
kubectl get crd -o yaml | grep -B 5 -A 10000 cert-manager.io > /root/resources.txt
```

**Simplest and most reliable method:**
```bash
kubectl get crd -o name | grep cert-manager | xargs kubectl get -o yaml > /root/resources.txt
```

**Step 4: Verify the file was created**

```bash
cat /root/resources.txt | head -50
```

Check how many CRDs were saved:
```bash
grep "kind: CustomResourceDefinition" /root/resources.txt | wc -l
```

**Step 5: Explore the Certificate CRD structure**

```bash
kubectl explain certificate
```

View the spec section:
```bash
kubectl explain certificate.spec
```

View available fields in spec:
```bash
kubectl explain certificate.spec --recursive
```

**Step 6: Complete Task 2 - Extract documentation for spec.subject**

```bash
kubectl explain certificate.spec.subject > /root/subject.txt
```

**Step 7: Verify the subject documentation file**

```bash
cat /root/subject.txt
```

The output should contain documentation about the subject field, including:
- Description of what the subject field does
- Available subfields (commonName, organizations, etc.)
- Field types and requirements

**Step 8: Explore more fields (optional)**

```bash
# View all fields under spec
kubectl explain certificate.spec

# View specific nested fields
kubectl explain certificate.spec.dnsNames
kubectl explain certificate.spec.issuerRef
kubectl explain certificate.spec.secretName

# View with full details
kubectl explain certificate.spec.subject --recursive
```

**Verification checklist:**
- ✅ File `/root/resources.txt` exists
- ✅ Contains multiple CRD definitions with "cert-manager" in their names
- ✅ File is valid YAML format
- ✅ File `/root/subject.txt` exists
- ✅ Contains documentation for certificate.spec.subject field
- ✅ Includes field description and structure

**Understanding CRDs:**

**What is a Custom Resource Definition (CRD)?**
- Extends Kubernetes API with custom resource types
- Allows creating new kinds of objects beyond built-in types (Pods, Services, etc.)
- Used by operators and controllers to manage complex applications
- Defines schema, validation, and versioning for custom resources

**cert-manager CRDs:**
```yaml
# Certificate - Represents a TLS certificate
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
spec:
  secretName: example-cert-tls
  issuerRef:
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
  - example.com
  subject:
    organizations:
    - Example Org
```

**kubectl explain Command:**
- Shows documentation for Kubernetes resources
- Works with both built-in and custom resources
- Supports nested field paths (e.g., `spec.subject.commonName`)
- Use `--recursive` flag to see entire field tree

</details>
