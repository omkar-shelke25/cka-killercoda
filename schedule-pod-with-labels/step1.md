# 🧠 **CKA: Pod Scheduling with Multiple Node Labels**

### 🏢 **Context**

You are working 🧑‍💻 in your company’s **database infrastructure team**.
A new Redis Pod needs to run **only on nodes that meet specific storage and location requirements**.

### ❓ **Question**

Create a Pod named **`redis-database`** in the namespace **`database-storage`** using the image
`public.ecr.aws/docker/library/redis:alpine`.

Ensure that this Pod is scheduled **only on a node** that has **both** of the following labels:

```
disktype=ssd
region=east
```

> Do **not** use `nodeName` or `nodeAffinity`.

### Try it yourself first!

<details><summary>✅ Solution (expand to view)</summary>
  
```bash
kubectl run redis-database \
  -n database-storage \
  --image=public.ecr.aws/docker/library/redis:alpine \
  --dry-run=client -o yaml > redis.yaml
```

Now edit the file and add the `nodeSelector` section so it looks like this 👇

```yaml
spec:
  nodeSelector:
    disktype: ssd
    region: east
```

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: redis-database
  namespace: database-storage
  labels:
    app: redis-database
spec:
  nodeSelector:
    disktype: ssd
    region: east
  containers:
    - name: redis-database
      image: public.ecr.aws/docker/library/redis:alpine
```

Then apply it:

```bash
kubectl apply -f redis.yaml
```

</details>
