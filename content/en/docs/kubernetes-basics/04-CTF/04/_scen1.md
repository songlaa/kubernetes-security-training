---
title: "Scenario 1"
weight: 4
sectionnumber: 4.1
---

First setup the Scenario:

```bash
# don't spoil and look at the files...
curl -LO https://kubernetes-security.songlaa.com/ctf/1/1setup.sh
chmod +x 1setup.sh
./1setup.sh
```

You were given rights to execute containers on a CI/CD Pipeline. Of course you tried to create a reverse-shell and suceeded. Now on to more!

### {{% task %}} Find verifications that you are in a pod

There are some giveaways that you are inside a Kubernetes Pod. Find 3 of them. After you did that manually you can also google if there are tools available for that.

### {{% task %}} Disclose information from other Pods

Find ways to break out of your pod, can you maybe find a file with a flag which has a text with "songlaa" somewhere on another pod"?

### {{% task %}} Cleanup

Exit the container if you are still inside:

```bash
exit
```

Then remove the resources:

```bash
rm -f scen1.sh
kind delete cluster
docker kill my-ubuntu-container
docker stop my-ubuntu-container
```
