# 🧠 **CKA Question: Install Argo CD Using Helm Without CRDs**

📚 **Official Kubernetes Documentation**: 
- [Helm Documentation](https://helm.sh/docs/)
- [Helm Template Command](https://helm.sh/docs/helm/helm_template/)
- [Argo CD Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)

### 🎯 **Scenario**

The `argocd` namespace is already created in the Kubernetes cluster. Argo CD CRDs have been pre-installed by the platform team.

You need to install Argo CD in the cluster using Helm, ensuring that CRDs are not installed because they are already present.

### ❓ **Question**

Install Argo CD in the cluster using Helm, ensuring that CRDs are not installed because they are already pre-installed.

**Perform the following tasks:**

1. Add the official Argo CD Helm repository with the name `argocd`:
   ```
   https://argoproj.github.io/argo-helm
   ```

2. Generate a Helm template from the Argo CD chart **version 9.1.4** for the `argocd` namespace

3. Ensure that CRDs are **not installed** by configuring the chart accordingly

4. Save the generated YAML manifest to:
   ```
   /root/argo-helm.yaml
   ```

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Verify the argocd namespace exists**

```bash
kubectl get namespace argocd
```

You should see the namespace already created.

**Step 2: Verify that Argo CD CRDs are already installed**

```bash
kubectl get crd | grep argoproj
```

Expected output showing CRDs like:
- applications.argoproj.io
- applicationsets.argoproj.io
- appprojects.argoproj.io

```bash
kubectl get crd applications.argoproj.io
```

This confirms CRDs are pre-installed.

**Step 3: Verify Helm is installed**

```bash
helm version
```

You should see Helm 3.x installed.

**Step 4: Add the Argo CD Helm repository with name 'argocd'**

```bash
helm repo add argocd https://argoproj.github.io/argo-helm
```

Expected output:
```
"argocd" has been added to your repositories
```

**Step 5: Update Helm repositories**

```bash
helm repo update
```

This fetches the latest chart information.

**Step 6: Verify the repository was added correctly**

```bash
helm repo list
```

You should see:
```
NAME     URL
argocd   https://argoproj.github.io/argo-helm
```

**Step 7: Search for the argo-cd chart to verify availability**

```bash
helm search repo argocd/argo-cd
```

**Step 8: View available versions (optional)**

```bash
helm search repo argocd/argo-cd --versions | grep 9.1.4
```

Verify version 9.1.4 is available.

**Step 9: Generate Helm template without CRDs**

**SOLUTION COMMAND:**

```bash
helm template argocd argocd/argo-cd \
  --version 9.1.4 \
  --namespace argocd \
  --skip-crds \
  > /root/argo-helm.yaml
```

**Breaking down the command:**
- `helm template` - Generate manifests without installing
- `argocd` - Release name (first positional argument)
- `argocd/argo-cd` - Repository/Chart (repo-name/chart-name)
- `--version 9.1.4` - Specific chart version required
- `--namespace argocd` - Target namespace
- `--skip-crds` - **Skip CRD installation (critical requirement)**
- `> /root/argo-helm.yaml` - Save output to file

**Step 10: Verify the file was created**

```bash
ls -lh /root/argo-helm.yaml
```

Check file exists and has content (should be 50KB+ typically).

**Step 11: View the beginning of the file**

```bash
head -30 /root/argo-helm.yaml
```

You should see YAML manifests with Kubernetes resources.

**Step 12: Verify CRDs are NOT in the file**

```bash
grep -i "CustomResourceDefinition" /root/argo-helm.yaml
```

This should return nothing (no output = correct).

Alternative verification:
```bash
grep "kind: CustomResourceDefinition" /root/argo-helm.yaml || echo "✅ No CRDs found - Correct!"
```

**Step 13: Check what resource types were generated**

```bash
grep "^kind:" /root/argo-helm.yaml | sort | uniq -c
```

You should see resources like:
- ServiceAccount
- ConfigMap
- Secret
- Service
- Deployment
- NetworkPolicy
- Role/ClusterRole
- RoleBinding/ClusterRoleBinding

**Step 14: Count total YAML documents**

```bash
grep -c "^---" /root/argo-helm.yaml
```

Should show 30+ documents (manifests).

**Step 15: Verify namespace references**

```bash
grep "namespace: argocd" /root/argo-helm.yaml | head -5
```

Should show resources configured for argocd namespace.

**Step 16: Optional - Check for Argo CD components**

```bash
grep -E "argocd-server|argocd-repo-server|argocd-application-controller" /root/argo-helm.yaml | grep "name:" | head -10
```
</details>
