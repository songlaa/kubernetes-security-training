---
title: "Scenario 1"
weight: 4
sectionnumber: 1.4
---

First setup the Scenario:

```bash
# don't spoil and look at the files...
curl -LO https://kubernetes-security.songlaa.com/ctf/scen1.sh script1.sh
chmod +x script1.sh
```

You were given rights to execute containers on a CI/CD Pipeline. Of course you tried to create a reverse-shell and suceeded. Now on to more!

### {{% task %}} Find verifications that you are in a pod

There are some giveaways that you are inside a Kubernetes Pod. Find 3 of them.

### {{% task %}} Disclose information on other Pods

Find ways to break out of your pod, can you maybe find a flag wich starts with "songlaa" somewhere on another pod"?

### {{% task %}} Cleanup

execute this:

```bash
rm -f scen1.sh
kind delete cluster
docker kill my-ubuntu-container
docker stop my-ubuntu-container
```
