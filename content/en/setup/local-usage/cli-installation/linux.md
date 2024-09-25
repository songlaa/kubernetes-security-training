---
title: "Linux"
weight: 13
type: docs
---

## Installation for Linux

Follow the steps outlined in <https://kubernetes.io/docs/tasks/tools/install-kubectl/>.

In case the installation from the official package repositories didn't work (or a specific version is needed) the static binary can be downloaded and put into the following path:

```
~/bin
```

### File mode

The `kubectl` binary has to be executable:

```bash
cd ~/bin
chmod +x kubectl
```

### PATH variable

In Linux, the directory `~/bin` should already be part of the `PATH` variable.
In case `kubectl` is placed in a different directory, you can change the `PATH` variable with the following command:

```bash
export PATH=$PATH:[path to kubectl]
```

### Completion for Bash and Zsh (optional)

You can activate Bash completion:

```bash
source <(kubectl completion bash)
```

As well as for Zsh:

```bash
source <(kubectl completion zsh)
```

To make it permanent, you can put that command in your Bash configuration file:

```bash
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

On most Linux systems, you have to install the `bash-completion` package to make the completion work.

Debian/Ubuntu:

```bash
sudo apt install bash-completion
```

Fedora:

```bash
sudo dnf install bash-completion
```
