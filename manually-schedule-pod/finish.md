# 🎉 Mission Accomplished!

You have configured a manually scheduled Pod and exposed it externally via a NodePort service. This exercise demonstrates how to bypass automatic scheduling policies by assigning a Pod to a specific node and how to expose Pod traffic to external clients using a NodePort.

## Conceptual summary

- Manually scheduling a Pod is done with `spec.nodeName`. 
- This forces the kubelet on that node to own and run the Pod without using the default scheduler. 


## Diagram

Client
   │
   ▼
Node (controlplane):30099
   │
   ▼
Service: tokoyo (type: NodePort)
   │
   ▼
Pod: tokoyo
   └── nodeName: controlplane
       containerPort: 80

### 🧠 Quick Explanation

| Component               | Description                                                                                                 |
| ----------------------- | ----------------------------------------------------------------------------------------------------------- |
| **Client**              | Sends the request from outside the cluster using Node’s IP and NodePort `30099`.                            |
| **Node (controlplane)** | The node that receives external traffic. NodePort `30099` is open here.                                     |
| **Service (tokoyo)**    | Type `NodePort` service that maps `30099 → 80`.                                                             |
| **Pod (tokoyo)**        | Runs the `nginx` container, listening on port `80`. It’s **manually scheduled** on the `controlplane` node. |

Would you like me to add a **Kubernetes resource flow diagram** (Pod → Service → NodePort → Client) version too, for visual overview?

Good work — you're practicing real-world debugging and operational tasks that frequently appear in the CKA exam and live clusters.
