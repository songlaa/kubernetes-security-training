---
title: "PSA"
weight: 8
sectionnumber: 1.8
---


## Pod Security Admission (PSA)

Kubernetes **Pod Security Admission (PSA)** is a mechanism designed to enforce security policies on pods based on predefined security profiles (so called **Pod Security Standards (PSS)**). It provides a way to ensure that pods meet certain security standards before they are allowed to run in a Kubernetes cluster.

PSA works by evaluating pod security based on [three profiles](https://kubernetes.io/docs/concepts/security/pod-security-standards/):

1. **Privileged**: Offers the highest level of privileges, with minimal restrictions. Suitable for trusted workloads but generally discouraged for untrusted or multi-tenant environments.
  
2. **Baseline**: Represents a middle-ground profile, enforcing a basic level of security. It prevents dangerous configurations but allows for some flexibility. Suitable for most standard workloads.
  
3. **Restricted**: Enforces the strictest security policies, minimizing the attack surface by disallowing risky configurations. This profile is ideal for highly sensitive or multi-tenant environments.

Administrators can apply these profiles across the cluster or to specific namespaces, and PSA checks pod configurations before allowing them to be created or updated. It helps improve security by reducing the risk of privilege escalation and other potential vulnerabilities.

Pod security restrictions are applied at the namespace level when pods are created.

To ensure that your workloads adhere to the Restricted security profile, you can configure the PSA policy on the namespace where your workloads are deployed. The label you select defines what action the control plane takes if a potential violation is detected:

* **enforce** Policy violations will cause the pod to be rejected.
* **audit** Policy violations will trigger the addition of an audit annotation to the event recorded in the audit log, but are otherwise allowed.
* **warn** Policy violations will trigger a user-facing warning, but are otherwise allowed.

To enforce the Restricted profile set the appropriate labels on the namespace.

```bash
kubectl label namespace <namespace> \
    pod-security.kubernetes.io/enforce=restricted \
    pod-security.kubernetes.io/enforce-version=latest

```

This ensures future pods in this namespace will meet the criteria set in the Restricted profile. You can monitor metrics for this using exernal tools like prometheus or directly with

```bash
kubectl get --raw /metrics | grep pod_security_
```
