# 🧠 **CKA: Install Argo CD with Helm Without CRDs**

📚 **Official Documentation**: 
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Template Command](https://helm.sh/docs/helm/helm_template/)
- [Argo CD Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
- [Helm Repository Management](https://helm.sh/docs/helm/helm_repo/)

### 🎯 **Context**

You are tasked with installing Argo CD, a popular GitOps continuous delivery tool for Kubernetes, using Helm. However, your organization has a policy that requires CRDs to be installed and managed separately from application installations for better version control and auditing purposes.

You need to generate the Kubernetes manifests for Argo CD without including the CRDs, and save them to a file for review before deployment.

### ❓ **Question: Install Argo CD Without CRDs**

Install Argo CD in the Kubernetes cluster using Helm.

**Task:**

1. Add the official Argo CD Helm repository:
   ```
   https://argoproj.github.io/argo-helm
   ```

2. Generate the Kubernetes manifests for Argo CD using:
   * Chart: `argo-cd`
   * Version: `7.7.3`
   * Namespace: `argocd`

3. Ensure that CRDs are **not installed** during the installation.

4. Save the generated manifests to:
   ```
   /root/argo-helm.yaml
   ```

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify Helm is installed**

```bash
helm version
```

You should see Helm version 3.x installed.

**Step 2: Add the Argo CD Helm repository**

```bash
helm repo add argo https://argoproj.github.io/argo-helm
```

Expected output:
```
"argo" has been added to your repositories
```

**Step 3: Update Helm repositories**

```bash
helm repo update
```

This ensures you have the latest chart versions available.

**Step 4: Verify the repository was added**

```bash
helm repo list
```

You should see the `argo` repository in the list.

**Step 5: Search for the argo-cd chart**

```bash
helm search repo argo-cd
```

This shows available Argo CD charts and versions.

**Step 6: View available versions of argo-cd chart**

```bash
helm search repo argo-cd --versions | head -20
```

Verify that version 7.7.3 is available.

**Step 7: Generate manifests without CRDs**

Use `helm template` to generate manifests without installing them:

```bash
helm template argocd argo/argo-cd \
  --version 7.7.3 \
  --namespace argocd \
  --skip-crds \
  > /root/argo-helm.yaml
```

**Understanding the command:**
- `helm template` - Generates manifests without installing
- `argocd` - Release name
- `argo/argo-cd` - Chart repository/name
- `--version 7.7.3` - Specific chart version
- `--namespace argocd` - Target namespace
- `--skip-crds` - Exclude CRD installation
- `> /root/argo-helm.yaml` - Redirect output to file

**Alternative: Using helm install with --dry-run**

```bash
helm install argocd argo/argo-cd \
  --version 7.7.3 \
  --namespace argocd \
  --skip-crds \
  --dry-run \
  --client \
  > /root/argo-helm.yaml
```

Note: `helm template` is preferred for generating manifests.

**Step 8: Verify the generated file**

```bash
ls -lh /root/argo-helm.yaml
```

Check file size (should be substantial, typically 50KB+).

```bash
head -50 /root/argo-helm.yaml
```

View the first 50 lines to see the generated manifests.

**Step 9: Check what resources were generated**

```bash
grep "^kind:" /root/argo-helm.yaml | sort | uniq -c
```

This shows all resource types in the generated manifests.

**Step 10: Verify CRDs are not included**

```bash
grep -i "CustomResourceDefinition" /root/argo-helm.yaml
```

This should return nothing, confirming CRDs were skipped.

```bash
grep "kind: CustomResourceDefinition" /root/argo-helm.yaml || echo "No CRDs found - Correct!"
```

**Step 11: Count the number of resources**

```bash
grep -c "^---" /root/argo-helm.yaml
```

This shows how many YAML documents (resources) are in the file.

**Step 12: Optional - Review specific resources**

```bash
# List all ServiceAccount names
grep -A 1 "kind: ServiceAccount" /root/argo-helm.yaml | grep "name:"

# List all Deployment names
grep -A 1 "kind: Deployment" /root/argo-helm.yaml | grep "name:"

# List all Service names
grep -A 1 "kind: Service" /root/argo-helm.yaml | grep "name:"
```

If you wanted to actually install Argo CD:

```bash
kubectl apply -f /root/argo-helm.yaml
```



</details>
