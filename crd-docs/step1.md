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
kubectl get crd | grep -i cert-manager >  resources.txt
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


**Step 3: Explore the Certificate CRD structure**

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

**Step 4: Complete Task 2 - Extract documentation for spec.subject**

```bash
kubectl explain certificate.spec.subject > /root/subject.txt
```

**Step 5: Verify the subject documentation file**

```bash
cat /root/subject.txt
```


</details>
