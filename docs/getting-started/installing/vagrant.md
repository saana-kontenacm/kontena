---
title: Vagrant
---

# Running Kontena on Vagrant

- [Prerequisities](vagrant#prerequisities)
- [Installing Vagrant Plugin](vagrant#installing-kontena-vagrant-plugin)
- [Installing Kontena Master](vagrant#installing-kontena-master)
- [Installing Kontena Nodes](vagrant#installing-kontena-nodes)
- [Vagrant Plugin Command Reference](vagrant#vagrant-plugin-command-reference)

## Prerequisities

- Kontena Account
- Vagrant 1.6 or later. Visit [https://www.vagrantup.com/](https://www.vagrantup.com/) to get started

## Installing Kontena Vagrant Plugin

```
$ kontena plugin install vagrant
```

## Installing Kontena Master

Kontena Master is an orchestrator component that manages Kontena Grids/Nodes. Installing Kontena Master to Vagrant can be done by just issuing following command:

```
$ kontena vagrant master create
```

After Kontena Master has provisioned you can connect to it by issuing login command. First user to login will be given master admin rights.

```
$ kontena login --name vagrant-master http://<master_ip>:8080/
```

## Installing Kontena Nodes

Before you can start provision nodes you must first switch cli scope to a grid. Grid can be thought as a cluster of nodes that can have members from multiple clouds and/or regions.

Switch to existing grid using following command:

```
$ kontena grid use <grid_name>
```

Or create a new grid using command:

```
$ kontena grid create --initial-size=<initial_size> test-grid
```

Now you can start provision nodes to DigitalOcean. Issue following command (with right options) as many times as desired:

```
$ kontena vagrant node create
```

After creating nodes, you can verify that they have joined Grid:

```
$ kontena node list
```

## Vagrant Plugin Command Reference

#### Create Master

```
Usage:
    kontena vagrant master create [OPTIONS]

Options:
    --memory MEMORY               How much memory node has (default: "512")
    --version VERSION             Define installed Kontena version (default: "latest")
    --auth-provider-url AUTH_PROVIDER_URL Define authentication provider url
    --vault-secret VAULT_SECRET   Secret key for Vault
    --vault-iv VAULT_IV           Initialization vector for Vault
```

#### SSH to Master

```
Usage:
    kontena vagrant master ssh [OPTIONS]
```

#### Start Master

```
Usage:
    kontena vagrant master start [OPTIONS]
```

#### Stop Master

```
Usage:
    kontena vagrant master stop [OPTIONS]
```

#### Restart Master

```
Usage:
    kontena vagrant master restart [OPTIONS]
```

#### Terminate Master

```
Usage:
    kontena vagrant master terminate [OPTIONS]
```

#### Create Node

```
Usage:
    kontena vagrant node create [OPTIONS] [NAME]

Parameters:
    [NAME]                        Node name

Options:
    --grid GRID                   Specify grid to use
    --instances AMOUNT            How many nodes will be created (default: "1")
    --memory MEMORY               How much memory node has (default: "1024")
    --version VERSION             Define installed Kontena version (default: "latest")
```

#### SSH to Node

```
Usage:
    kontena vagrant node ssh [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
```

#### Start Node

```
Usage:
    kontena vagrant node start [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
```

#### Stop Node

```
Usage:
    kontena vagrant node stop [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
```

#### Restart Node

```
Usage:
    kontena vagrant node restart [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
```

#### Terminate Node

```
Usage:
    kontena vagrant node terminate [OPTIONS] NAME

Parameters:
    NAME                          Node name

Options:
    --grid GRID                   Specify grid to use
    --force                       Force remove (default: false)
```
