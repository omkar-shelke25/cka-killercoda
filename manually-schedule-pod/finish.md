# 🎉 Mission Accomplished!

You have configured a manually scheduled Pod and exposed it externally via a NodePort service. This exercise demonstrates how to bypass automatic scheduling policies by assigning a Pod to a specific node and how to expose Pod traffic to external clients using a NodePort.

## Conceptual summary

- Manually scheduling a Pod is done with `spec.nodeName`. 
- This forces the kubelet on that node to own and run the Pod without using the default scheduler. 


## Diagram

flowchart LR
    A[Client] --> B[Node (controlplane):30099]
    B --> C[Service: tokoyo (NodePort)]
    C --> D[Pod: tokoyo<br/>nodeName: controlplane<br/>containerPort: 80]


Good work — you're practicing real-world debugging and operational tasks that frequently appear in the CKA exam and live clusters.
