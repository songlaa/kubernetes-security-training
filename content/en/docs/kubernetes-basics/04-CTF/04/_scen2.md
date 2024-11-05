---
title: "Scenario 2"
weight: 4
sectionnumber: 4.2
---

First setup the Scenario:

```bash
# don't spoil and look at the files...
curl -LO https://kubernetes-security.songlaa.com/ctf/2/2setup.sh 2setup.sh
chmod +x 2setup.sh
./2setup.sh
# you might need to wait 1 minute if access to ssh fails
```

This is a tough CTF:
you were overhearing a conversation and heard the password "songlaa". When you did some [osint](https://testarmy.com/blog/osint-open-source-intelligence-how-can-publicly-available-information-influence-a-possible-cyber-attack#What_is_OSINT) you found the IP of server. Now you have access to a Kubernetes Cluster! Try to become cluster admin!

Just a few hints:

* This is a very small cluster, expect 256 services at max. Services are on their normal ports.
* at a later stage you might want to forward some connections. You can use tools like [frp](<https://github.com/fatedier/frp>]

### {{% task %}} Try look around and brake out of your Pod

This will not be the usual way we had before start being creative. Get as many flags as possible.

### {{% task %}} Cleanup

execute this:

```bash
kind delete cluster
```
