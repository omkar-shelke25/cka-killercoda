# 🧠 **CKA: RBAC and ServiceAccount Token Management**

📚 **Official Kubernetes Documentation**: 
- [Using RBAC Authorization](https://kubernetes.io/docs/reference/access-authn-authz/rbac/)
- [Managing Service Accounts](https://kubernetes.io/docs/reference/access-authn-authz/service-accounts-admin/)
- [Kubernetes API Access](https://kubernetes.io/docs/tasks/administer-cluster/access-cluster-api/)

### 🏢 **Context**

You are working 🧑‍💻 on integrating GitLab CI/CD with your Kubernetes cluster. The CI/CD pipeline needs programmatic access to manage pods, deployments, and jobs across the cluster. A ServiceAccount named `gitlab-cicd-sa` has already been created in the `gitlab-cicd` namespace, and a test pod named `gitlab-cicd-nginx` is running to verify your configuration.

Your task is to set up proper RBAC permissions and generate a secure token for API authentication.

### ❓ **Question**

You need to configure RBAC and generate an API access token for the GitLab CI/CD integration. 

Create a ClusterRole named `gitlab-cicd-role` that grants the verbs `get`, `list`, `watch`, `create`, `patch`, `delete` on the resources `pods`, `deployments`, and `jobs`. 

Bind this role to the existing ServiceAccount `gitlab-cicd-sa` in the `gitlab-cicd` namespace using a ClusterRoleBinding named `gitlab-cicd-rb`.

Next, create a 2-hour valid token for the ServiceAccount. Using this token, perform an HTTPS API request to list the pods in the `gitlab-cicd` namespace and store the resulting output in the file `/gitlab-cicd/pod-details.yaml`.

The API request should be made using the following format:
```bash
curl --cacert ca.crt -H "Authorization: Bearer $TOKEN" https://172.16.0.2:6443/api/v1/namespaces/gitlab-cicd/pods/
```

Do not delete or modify any existing cluster resources other than what is required for the task.

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Create the ClusterRole**

```bash
kubectl create clusterrole gitlab-cicd-role \
  --verb=get,list,watch,create,patch,delete \
  --resource=pods,deployments,jobs
```

Verify the ClusterRole:
```bash
kubectl get clusterrole gitlab-cicd-role
kubectl describe clusterrole gitlab-cicd-role
```

**Step 2: Create the ClusterRoleBinding**

```bash
kubectl create clusterrolebinding gitlab-cicd-rb \
  --clusterrole=gitlab-cicd-role \
  --serviceaccount=gitlab-cicd:gitlab-cicd-sa
```

Verify the ClusterRoleBinding:
```bash
kubectl get clusterrolebinding gitlab-cicd-rb
kubectl describe clusterrolebinding gitlab-cicd-rb
```

**Step 3: Create a 2-hour valid token for the ServiceAccount**

```bash
kubectl create token gitlab-cicd-sa \
  --namespace=gitlab-cicd \
  --duration=2h > /tmp/token.txt
```

Store the token in a variable:
```bash
TOKEN=$(cat /tmp/token.txt)
echo $TOKEN
```

**Step 4: Extract the CA certificate**

```bash
kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}' | base64 -d > /tmp/ca.crt
```

Verify the certificate:
```bash
ls -lh /tmp/ca.crt
```

**Step 5: Get the API server address**

```bash
APISERVER=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.server}')
echo $APISERVER
```

Note: The API server should be at `https://172.16.0.2:6443` based on the question.

**Step 6: Make the API request and store the output**

```bash
curl --cacert /tmp/ca.crt \
  -H "Authorization: Bearer $TOKEN" \
  https://172.16.0.2:6443/api/v1/namespaces/gitlab-cicd/pods/ \
  -o /gitlab-cicd/pod-details.yaml
```

**Step 7: Verify the output**

```bash
cat /gitlab-cicd/pod-details.yaml
```

You should see JSON output containing the list of pods in the `gitlab-cicd` namespace, including the `gitlab-cicd-nginx` pod.

**Optional: Format the output for better readability**

```bash
cat /gitlab-cicd/pod-details.yaml | jq '.items[].metadata.name'
```

**Verification checklist:**
- ✅ ClusterRole `gitlab-cicd-role` created with correct verbs and resources
- ✅ ClusterRoleBinding `gitlab-cicd-rb` binds the role to `gitlab-cicd-sa`
- ✅ Token generated with 2-hour validity
- ✅ API request successful with token authentication
- ✅ Pod details stored in `/gitlab-cicd/pod-details.yaml`

</details>

