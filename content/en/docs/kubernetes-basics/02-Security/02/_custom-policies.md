---
title: "Custom Policies"
weight: 22
sectionnumber: 2.2
---

Until now we learned best practices on how to secure our workload in kubernetes, but as a cluster admin. How can we enforce certain regulations for resources in our cluster? Sometimes we need to be more specific than the 3 PSP this is where policy engines like [Open Policy Agent (OPA)](https://www.openpolicyagent.org/) or [Kyverno](https://kyverno.io/) come into play.

## Kyverno

Kyverno is an open-source policy engine designed specifically for Kubernetes. It allows you to manage and enforce security and compliance policies for your Kubernetes resources using custom resource definitions (CRDs). We use it to write our own Policies as Code.

Remember when we did patch the namespace <namespace> in a previous lab. Patching and allowing the users to change labels can have real security consequences because it allows users to change the behaviour of algorithms like network policies which use labels to filter out resources. This is why a Policy was set in place that you could only change certain labels of the <namespace> namespace.

Let us create our own policy for our namespace, we want to start soft and warn users if they did not add the requirement that a container must drop `ALL` capabilites.
Kyvernos has a so called Custom Resourced called policy for that, crate a file named `drop-policy.yaml` whith this content:

```yaml
apiVersion: kyverno.io/v1
kind: Policy
metadata:
  name: drop-all-capabilities
  namespace: <namespace>
  annotations:
    policies.kyverno.io/title: Drop All Capabilities
    policies.kyverno.io/category: Best Practices
    policies.kyverno.io/severity: medium
    policies.kyverno.io/minversion: 1.6.0
    policies.kyverno.io/subject: Pod
    policies.kyverno.io/description: >-
      Capabilities permit privileged actions without giving full root access. All
      capabilities should be dropped from a Pod, with only those required added back.
      This policy ensures that all containers explicitly specify the `drop: ["ALL"]`
      ability. Note that this policy also illustrates how to cover drop entries in any
      case although this may not strictly conform to the Pod Security Standards.
spec:
  validationFailureAction: Audit
  background: true
  rules:
    - name: require-drop-all
      match:
        any:
        - resources:
            kinds:
              - Pod
      preconditions:
        all:
        - key: "{{ request.operation || 'BACKGROUND' }}"
          operator: NotEquals
          value: DELETE
      validate:
        message: >-
          Containers must drop `ALL` capabilities.
        foreach:
          - list: request.object.spec.[ephemeralContainers, initContainers, containers][]
            deny:
              conditions:
                all:
                - key: ALL
                  operator: AnyNotIn
                  value: "{{ element.securityContext.capabilities.drop[].to_upper(@) || `[]` }}"
```

We see that the action is set to Audit (wich means no blocking) and the match criteria is set to all Pods. We apply it to every type of container withhin a pod.

Apply the policy now

```bash
kubectl apply -f drop-policy.yaml
```

Now let us run a new pod

```bash
kubectl run hello-world --image=hello-world --restart=Never
```

Because the Action is only set to `Audit` non compliant resources are only logged, check this here:

```bash
kubectl describe policies.kyverno.io drop-all-capabilities
```

Let us now enforce our policy, swich the `Audit` to `Enforce` in `drop-policy.yaml` and apply it again:

```bash
kubectl apply -f drop-policy.yaml
```

Now test the same pod again:

```bash
kubectl run hello-world --image=hello-world --restart=Never
```

We were successfull in implementing our policy for newly started pods.
