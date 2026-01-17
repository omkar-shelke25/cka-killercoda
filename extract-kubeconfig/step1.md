# 📝 **CKA: Extract Information from Kubeconfig**

📚 **Official Kubernetes Documentation**: [Kubernetes Documentation - Organizing Cluster Access Using kubeconfig Files](https://kubernetes.io/docs/concepts/configuration/organize-cluster-access-kubeconfig/)

### 🏢 **Context**

As a Kubernetes administrator, you need to extract specific information from a kubeconfig file for documentation and troubleshooting purposes. This includes listing all available contexts, identifying the current context, and decoding certificate data.

---

### 🎯 **Your Task**

Extract the following information from the kubeconfig file `/opt/course/1/kubeconfig`:

**Task 1: Extract all context names**
- Write all kubeconfig context names into `/opt/course/1/contexts`
- One context name per line

**Task 2: Extract current context**
- Write the name of the current context into `/opt/course/1/current-context`

**Task 3: Extract and decode client certificate**
- Extract the client-certificate of user `account-0027`
- Decode it from base64
- Write the decoded certificate into `/opt/course/1/cert`

---

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>

**Step 1: Examine the kubeconfig file**

First, let's look at the structure of the kubeconfig file:

```bash
cat /opt/course/1/kubeconfig
```

Or view it in a more readable format:
```bash
kubectl config view --kubeconfig=/opt/course/1/kubeconfig
```

**Step 2: Extract all context names**

List all contexts and extract only the names:

```bash
kubectl config get-contexts --kubeconfig=/opt/course/1/kubeconfig -o name > /opt/course/1/contexts
```

Alternative method using grep:
```bash
kubectl config get-contexts --kubeconfig=/opt/course/1/kubeconfig --no-headers | awk '{print $2}' > /opt/course/1/contexts
```

Or using the raw YAML:
```bash
grep -A 1 "^  - context:" /opt/course/1/kubeconfig | grep "name:" | awk '{print $3}' > /opt/course/1/contexts
```

Verify the output:
```bash
cat /opt/course/1/contexts
```

**Step 3: Extract current context**

Get the current context:

```bash
kubectl config current-context --kubeconfig=/opt/course/1/kubeconfig > /opt/course/1/current-context
```

Alternative method:
```bash
grep "^current-context:" /opt/course/1/kubeconfig | awk '{print $2}' > /opt/course/1/current-context
```

Verify the output:
```bash
cat /opt/course/1/current-context
```

**Step 4: Extract and decode client certificate for account-0027**

Find and decode the client-certificate-data for user account-0027:

Method 1 -  Using kubectl,jq and array index

```bash
kubectl --raw --kubeconfig=/opt/course/1/kubeconfig config view \
  -o jsonpath='{.users[1].user.client-certificate-data}' \
  | base64 --decode > /opt/course/1/cert
```

Method 2 - Using kubectl and jq:
```bash
kubectl config view --kubeconfig=/opt/course/1/kubeconfig --raw -o json | \
  jq -r '.users[] | select(.name == "account-0027") | .user."client-certificate-data"' | \
  base64 -d > /opt/course/1/cert
```

Method 3 - Using grep and awk:
```bash
# Extract the base64 encoded certificate
grep -A 10 "name: account-0027" /opt/course/1/kubeconfig | \
  grep "client-certificate-data:" | \
  awk '{print $2}' | \
  base64 -d > /opt/course/1/cert
```

Method 4 - Direct YAML parsing with yq (if available):
```bash
yq eval '.users[] | select(.name == "account-0027") | .user.client-certificate-data' /opt/course/1/kubeconfig | \
  base64 -d > /opt/course/1/cert
```

Verify the decoded certificate:
```bash
# Check it's a valid certificate
openssl x509 -in /opt/course/1/cert -text -noout | head -20
```

Or simply check the file starts with certificate header:
```bash
head -5 /opt/course/1/cert
```

Expected output should show:
```
-----BEGIN CERTIFICATE-----
...
```

**Step 5: Verify all outputs**

```bash
echo "=== Contexts ==="
cat /opt/course/1/contexts

echo ""
echo "=== Current Context ==="
cat /opt/course/1/current-context

echo ""
echo "=== Certificate (first few lines) ==="
head -5 /opt/course/1/cert
```

**Summary of Commands:**

```bash
# Task 1: Extract all context names
kubectl config get-contexts --kubeconfig=/opt/course/1/kubeconfig -o name > /opt/course/1/contexts

# Task 2: Extract current context
kubectl config current-context --kubeconfig=/opt/course/1/kubeconfig > /opt/course/1/current-context

# Task 3: Extract and decode certificate for account-0027
kubectl config view --kubeconfig=/opt/course/1/kubeconfig --raw -o json | \
  jq -r '.users[] | select(.name == "account-0027") | .user."client-certificate-data"' | \
  base64 -d > /opt/course/1/cert
```

**Alternative without jq:**

```bash
# Task 3 alternative
grep -A 10 "name: account-0027" /opt/course/1/kubeconfig | \
  grep "client-certificate-data:" | \
  awk '{print $2}' | \
  base64 -d > /opt/course/1/cert
```

</details>

---
