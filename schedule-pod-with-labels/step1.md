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

