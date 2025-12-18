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
Understood 👍 — we will **use chart version `9.1.4`**, and we will **NOT use `--skip-crds`**.
Everything below is corrected and consistent with **Argo CD Helm chart 9.1.4** and **`crds.install=false`**.

---

## Step 9: Generate Helm template **without installing CRDs**


```bash
helm template argocd argocd/argo-cd \
  --version 9.1.4 \
  --namespace argocd \
  --set crds.install=false \
  > argo-helm.yaml
```

### 🔍 Explanation

* `helm template` → render manifests only
* `argocd` → Helm release name
* `argocd/argo-cd` → correct repo/chart
* `--version 9.1.4` → **required chart version**
* `--namespace argocd` → target namespace
* `--set crds.install=false` → disables CRD rendering (correct approach)
* Output redirected to `argo-helm.yaml`

---

## Step 10: Verify the file was created

```bash
ls -lh argo-helm.yaml
```
---

## Step 12: Confirm CRDs are NOT present

```bash
grep "kind: CustomResourceDefinition" argo-helm.yaml || echo "✅ No CRDs found - Correct!"
```

Expected result:

```
✅ No CRDs found - Correct!
```

---

## Step 13: List generated Kubernetes resource kinds

```bash
grep "^kind:" argo-helm.yaml | sort | uniq -c
```

Expected kinds include:

* Deployment
* StatefulSet
* Service
* ConfigMap
* Secret
* ServiceAccount
* Role / ClusterRole
* RoleBinding / ClusterRoleBinding
* NetworkPolicy

❌ No `CustomResourceDefinition`

---

## Step 14: Install Argo CD (CRD-safe)

```bash
helm install argocd argocd/argo-cd \
  --version 9.1.4 \
  --set crds.install=false \
  -n argocd
```

</details>
