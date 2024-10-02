---
title: "RBAC"
weight: 7
sectionnumber: 1.7
---


## Role Based Access Control

Until now we just assumed that we have the necessary right to do our tasks in kubernetes. But how are users [Authenticated](https://kubernetes.io/docs/reference/access-authn-authz/authentication/) an [Authorized](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) in Kubernetes/the Kubernetes API?

### Users in Kubernetes

All Kubernetes clusters have two categories of users: service accounts managed by Kubernetes, and normal users.

It is assumed that a cluster-independent service manages normal users in the following ways:

* an administrator distributing private keys
* a user store like Keystone or Google Accounts
* a file with a list of usernames and passwords

In this regard, Kubernetes does not have objects which represent normal user accounts. Normal users cannot be added to a cluster through an API call.

Even though a normal user cannot be added via an API call, any user that presents a valid certificate signed by the cluster's certificate authority (CA) is considered authenticated. In this configuration, Kubernetes determines the username from the common name field in the 'subject' of the cert (e.g., "/CN=bob").
In contrast, service accounts are users managed by the Kubernetes API. They are bound to specific namespaces, and created automatically by the API server or manually through API calls.

#### Authentication strategies

Kubernetes uses client certificates, bearer tokens, or an authenticating proxy to authenticate API requests through authentication plugins.
As HTTP requests are made to the API server, plugins attempt to associate the following attributes with the request:

* Username: a string which identifies the end user. Common values might be kube-admin or <jane@example.com>.
* UID: a string which identifies the end user and attempts to be more consistent and unique than username.
* Groups: a set of strings, each of which indicates the user's membership in a named logical collection of users. Common values might be system:masters or devops-team.
* Extra fields: a map of strings to list of strings which holds additional information authorizers may find useful.

The following authentication method are common:

* X509 client certificates
* bearer token
* Service account tokens
* OpenID Connect Tokens (Microsoft Entra ID, Salesforce,Google...)

### RBAC Authorisation

The RBAC API declares four kinds of Kubernetes object: Role, ClusterRole, RoleBinding and ClusterRoleBinding. You can describe or amend the RBAC objects using tools such as kubectl, just like any other Kubernetes object.

#### Role and ClusterRole

An RBAC Role or ClusterRole contains rules that represent a set of permissions. Permissions are purely additive (there are no "deny" rules).

A Role always sets permissions within a particular namespace; when you create a Role, you have to specify the namespace it belongs in.

ClusterRole, by contrast, is a non-namespaced resource. The resources have different names (Role and ClusterRole) because a Kubernetes object always has to be either namespaced or not namespaced; it can't be both.

#### RoleBinding and ClusterRoleBinding

A role binding grants the permissions defined in a role to a user or set of users. It holds a list of subjects (users, groups, or service accounts), and a reference to the role being granted. A RoleBinding grants permissions within a specific namespace whereas a ClusterRoleBinding grants that access cluster-wide.

A RoleBinding may reference any Role in the same namespace. Alternatively, a RoleBinding can reference a ClusterRole and bind that ClusterRole to the namespace of the RoleBinding. If you want to bind a ClusterRole to all the namespaces in your cluster, you use a ClusterRoleBinding.
